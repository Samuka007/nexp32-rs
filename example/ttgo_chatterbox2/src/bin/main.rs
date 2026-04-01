#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types"
)]
#![deny(clippy::large_stack_frames)]
#![feature(impl_trait_in_assoc_type)]

extern crate alloc;

use alloc::boxed::Box;
use alloc::string::String;
use core::cell::RefCell;
use core::net::Ipv4Addr;
use core::str::FromStr;
use critical_section::Mutex;
use embassy_executor::Spawner;
use embassy_net::{Config, Ipv4Cidr, StaticConfigV4};
use esp_hal::clock::CpuClock;
use esp_hal::timer::timg::TimerGroup;
use esp_println::println;
use esp_radio::wifi::{AccessPointConfig, ModeConfig, WifiDevice};
use heapless::Vec as HeaplessVec;
use heapless::String as HeaplessString;

use picoserve::{AppBuilder, AppRouter, make_static, routing::{get, post}};
use picoserve::response::IntoResponse;
use picoserve::extract::Form;

const SSID: &str = "ChatBox-00110577";
const AP_IP: Ipv4Addr = Ipv4Addr::new(192, 168, 1, 1);
const MAX_MESSAGES: usize = 50;
const MAX_MESSAGE_LEN: usize = 256;
const HTTP_PORT: u16 = 80;

// Message storage - thread-safe with critical_section
static MESSAGES: Mutex<RefCell<HeaplessVec<HeaplessString<MAX_MESSAGE_LEN>, MAX_MESSAGES>>> =
    Mutex::new(RefCell::new(HeaplessVec::new()));

// HTML template for the chat interface (loaded from external file)
const CHAT_HTML: &str = include_str!("chat.html");

// Routes handlers
async fn index_handler() -> impl IntoResponse {
    CHAT_HTML
}

async fn get_messages_handler() -> impl IntoResponse {
    let messages = critical_section::with(|cs| {
        let msgs = MESSAGES.borrow_ref(cs);
        let mut result = HeaplessString::<4096>::new();
        for (i, msg) in msgs.iter().enumerate() {
            if i > 0 {
                result.push('\x1E').unwrap();
            }
            result.push_str(msg.as_str()).unwrap();
        }
        result
    });

    messages
}

#[derive(serde::Deserialize, Debug)]
struct MessageForm {
    message: String,
}

async fn post_message_handler(Form(form): Form<MessageForm>) -> impl IntoResponse {
    let message = form.message.trim();

    if !message.is_empty() {
        // Sanitize - remove record separator and limit length
        let clean_msg = message.replace('\x1E', "");
        let truncated = if clean_msg.len() > MAX_MESSAGE_LEN - 1 {
            &clean_msg[..MAX_MESSAGE_LEN - 1]
        } else {
            &clean_msg
        };

        critical_section::with(|cs| {
            let mut msgs = MESSAGES.borrow_ref_mut(cs);
            if msgs.len() >= MAX_MESSAGES {
                msgs.remove(0);
            }
            let _ = msgs.push(HeaplessString::from_str(truncated).unwrap());
        });

        println!("New message: {}", truncated);
    }

    "OK"
}

struct AppProps;

impl AppBuilder for AppProps {
    type PathRouter = impl picoserve::routing::PathRouter;

    fn build_app(self) -> picoserve::Router<Self::PathRouter> {
        picoserve::Router::new()
            .route("/", get(index_handler))
            .route("/messages", get(get_messages_handler))
            .route("/message", post(post_message_handler))
    }
}

static CONFIG: picoserve::Config = picoserve::Config::const_default().keep_connection_alive();

const WEB_TASK_POOL_SIZE: usize = 8;

#[embassy_executor::task(pool_size = WEB_TASK_POOL_SIZE)]
async fn web_task(
    task_id: usize,
    stack: embassy_net::Stack<'static>,
    app: &'static AppRouter<AppProps>,
) -> ! {
    let port = 80;
    let mut tcp_rx_buffer = [0; 1024];
    let mut tcp_tx_buffer = [0; 1024];
    let mut http_buffer = [0; 2048];

    picoserve::Server::new(app, &CONFIG, &mut http_buffer)
        .listen_and_serve(task_id, stack, port, &mut tcp_rx_buffer, &mut tcp_tx_buffer)
        .await
        .into_never()
}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    println!("Panic: {:?}", info);
    loop {}
}

esp_bootloader_esp_idf::esp_app_desc!();

#[esp_rtos::main]
async fn main(spawner: Spawner) {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    esp_alloc::heap_allocator!(#[esp_hal::ram(reclaimed)] size: 98768);

    println!("TTGO Chatterbox Starting...");

    let timg0 = TimerGroup::new(peripherals.TIMG0);
    esp_rtos::start(timg0.timer0);

    // Initialize WiFi - leak radio_init to get 'static lifetime
    let radio_init: &'static _ = Box::leak(Box::new(
        esp_radio::init().expect("Failed to initialize Wi-Fi"),
    ));
    let (mut wifi_controller, interfaces) =
        esp_radio::wifi::new(radio_init, peripherals.WIFI, Default::default())
            .expect("Failed to initialize Wi-Fi controller");

    // Configure AP
    let ap_config = AccessPointConfig::default().with_ssid(alloc::string::String::from(SSID));

    wifi_controller
        .set_config(&ModeConfig::AccessPoint(ap_config))
        .expect("Failed to set AP config");

    wifi_controller.start().expect("Failed to start AP");

    println!("WiFi AP started! SSID: {}", SSID);

    // Create embassy-net stack
    let seed = 1234u64;

    let net_config = Config::ipv4_static(StaticConfigV4 {
        address: Ipv4Cidr::new(AP_IP, 24),
        gateway: Some(AP_IP),
        dns_servers: Default::default(),
    });

    // Create network stack
    let stack_resources: &mut embassy_net::StackResources<3> =
        Box::leak(Box::new(embassy_net::StackResources::new()));
    let (stack, runner) = embassy_net::new(interfaces.ap, net_config, stack_resources, seed);

    // Spawn network stack task
    spawner.must_spawn(net_task(runner));

    // Wait for network to be up
    stack.wait_config_up().await;
    println!("Network is up! IP: {}", AP_IP);

    println!("HTTP server started on port {}", HTTP_PORT);
    println!("Connect to WiFi '{}' and open http://{}", SSID, AP_IP);

    let app = make_static!(AppRouter<AppProps>, AppProps.build_app());

    for task_id in 0..WEB_TASK_POOL_SIZE {
        spawner.must_spawn(web_task(task_id, stack, app));
    }
}

#[embassy_executor::task]
async fn net_task(mut runner: embassy_net::Runner<'static, WifiDevice<'static>>) {
    runner.run().await
}
