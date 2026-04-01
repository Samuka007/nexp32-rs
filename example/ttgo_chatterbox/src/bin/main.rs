#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types"
)]
#![deny(clippy::large_stack_frames)]

extern crate alloc;

use core::str::FromStr;

use core::cell::RefCell;
use core::net::SocketAddrV4;

use critical_section::Mutex;
use esp_hal::clock::CpuClock;
use esp_hal::main;
use esp_hal::time::{Duration, Instant};
use esp_hal::timer::timg::TimerGroup;
use esp_println::println;
use esp_radio::wifi::{AccessPointConfig, ModeConfig};
use heapless::{String, Vec};
use smoltcp::iface::{Config as InterfaceConfig, Interface, SocketSet, SocketStorage};
use smoltcp::time::Instant as SmoltcpInstant;
use smoltcp::wire::{HardwareAddress, IpAddress, IpCidr, Ipv4Address};

const SSID: &str = "ChatBox-00110577";
const AP_IP: Ipv4Address = Ipv4Address::new(192, 168, 1, 1);
const AP_NETMASK: u8 = 24;
const MAX_MESSAGES: usize = 50;
const MAX_MESSAGE_LEN: usize = 256;
const HTTP_PORT: u16 = 80;

// Message storage
static MESSAGES: Mutex<RefCell<Vec<String<MAX_MESSAGE_LEN>, MAX_MESSAGES>>> =
    Mutex::new(RefCell::new(Vec::new()));

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    println!("Panic: {:?}", info);
    loop {}
}

esp_bootloader_esp_idf::esp_app_desc!();

#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    esp_alloc::heap_allocator!(#[esp_hal::ram(reclaimed)] size: 98768);

    println!("TTGO Chatterbox Starting...");

    let timg0 = TimerGroup::new(peripherals.TIMG0);
    esp_rtos::start(timg0.timer0);

    let radio_init = esp_radio::init().expect("Failed to initialize Wi-Fi");
    let (mut wifi_controller, interfaces) =
        esp_radio::wifi::new(&radio_init, peripherals.WIFI, Default::default())
            .expect("Failed to initialize Wi-Fi controller");

    // Configure AP
    let ap_config = AccessPointConfig::default().with_ssid(alloc::string::String::from(SSID));

    wifi_controller
        .set_config(&ModeConfig::AccessPoint(ap_config))
        .expect("Failed to set AP config");

    wifi_controller.start().expect("Failed to start AP");

    println!("WiFi AP started!");
    println!("SSID: {}", SSID);
    println!("IP: 192.168.1.1");

    // Get AP interface
    let mut device = interfaces.ap;

    // Create network interface
    let iface_config = InterfaceConfig::new(HardwareAddress::Ethernet(
        smoltcp::wire::EthernetAddress(device.mac_address()),
    ));
    let timestamp =
        SmoltcpInstant::from_millis(Instant::now().duration_since_epoch().as_millis() as i64);
    let mut iface = Interface::new(iface_config, &mut device, timestamp);

    // Set IP address
    iface.update_ip_addrs(|ip_addrs| {
        ip_addrs
            .push(IpCidr::new(IpAddress::Ipv4(AP_IP), AP_NETMASK))
            .unwrap();
    });

    // Create TCP socket
    static mut TCP_RX_BUFFER: [u8; 1024] = [0u8; 1024];
    static mut TCP_TX_BUFFER: [u8; 4096] = [0u8; 4096];
    let tcp_socket = smoltcp::socket::tcp::Socket::new(
        smoltcp::socket::tcp::SocketBuffer::new(unsafe { &mut TCP_RX_BUFFER[..] }),
        smoltcp::socket::tcp::SocketBuffer::new(unsafe { &mut TCP_TX_BUFFER[..] }),
    );

    // Create socket set
    let mut socket_storage: [SocketStorage; 4] = Default::default();
    let mut sockets = SocketSet::new(&mut socket_storage[..]);
    let tcp_handle = sockets.add(tcp_socket);

    // Bind to port 80
    let endpoint = SocketAddrV4::new(core::net::Ipv4Addr::new(192, 168, 1, 1), HTTP_PORT);
    sockets
        .get_mut::<smoltcp::socket::tcp::Socket>(tcp_handle)
        .listen(endpoint)
        .unwrap();

    println!("HTTP server started on port {}", HTTP_PORT);

    // Main server loop
    loop {
        let timestamp =
            SmoltcpInstant::from_millis(Instant::now().duration_since_epoch().as_millis() as i64);

        iface.poll(timestamp, &mut device, &mut sockets);
        process_http(&mut sockets, tcp_handle);

        // Small delay
        let delay_start = Instant::now();
        while delay_start.elapsed() < Duration::from_millis(10) {}
    }
}

fn process_http(sockets: &mut SocketSet, handle: smoltcp::iface::SocketHandle) {
    let socket = sockets.get_mut::<smoltcp::socket::tcp::Socket>(handle);

    if !socket.is_open() {
        return;
    }

    if socket.can_recv() {
        let mut buffer = [0u8; 2048];
        match socket.recv_slice(&mut buffer) {
            Ok(0) => return,
            Ok(len) => {
                let request = core::str::from_utf8(&buffer[..len]).unwrap_or("");
                handle_http_request(socket, request);
            }
            Err(_) => return,
        }
    }
}

fn handle_http_request(socket: &mut smoltcp::socket::tcp::Socket, request: &str) {
    let lines: Vec<&str, 32> = request.lines().collect();
    if lines.is_empty() {
        return;
    }

    let request_line = lines[0];
    let parts: Vec<&str, 4> = request_line.split_whitespace().collect();

    if parts.len() < 2 {
        return;
    }

    let method = parts[0];
    let path = parts[1];

    println!("{} {}", method, path);

    match (method, path) {
        ("GET", "/" | "/index.html") => {
            send_html_page(socket);
        }
        ("GET", "/messages") => {
            send_messages(socket);
        }
        ("POST", "/message") => {
            receive_message(socket, request);
        }
        _ => {
            send_404(socket);
        }
    }
}

fn send_html_page(socket: &mut smoltcp::socket::tcp::Socket) {
    let html = r#"HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 2200
Connection: close

<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chatterbox</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background: #f0f0f0; }
        h1 { color: #333; text-align: center; }
        #messages { background: white; border-radius: 8px; padding: 20px; min-height: 200px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .message { border-bottom: 1px solid #eee; padding: 10px 0; word-wrap: break-word; }
        textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; resize: vertical; min-height: 80px; box-sizing: border-box; }
        button { background: #007bff; color: white; border: none; padding: 12px 24px; border-radius: 4px; cursor: pointer; font-size: 16px; margin-top: 10px; }
        button:hover { background: #0056b3; }
        .empty { color: #999; text-align: center; font-style: italic; }
    </style>
</head>
<body>
    <h1>Chatterbox</h1>
    <div id="messages"></div>
    <textarea id="messageInput" placeholder="Type your message here..."></textarea>
    <button onclick="sendMessage()">Send</button>
    
    <script>
        async function loadMessages() {
            try {
                const response = await fetch('/messages');
                const text = await response.text();
                const messages = text.split('\x1E').filter(m => m.trim());
                const container = document.getElementById('messages');
                container.innerHTML = messages.length === 0 
                    ? '<div class="empty">No messages yet. Be the first!</div>'
                    : messages.map(m => `<div class="message">${escapeHtml(m)}</div>`).join('');
            } catch (e) {
                console.error('Error:', e);
            }
        }
        
        async function sendMessage() {
            const input = document.getElementById('messageInput');
            const message = input.value.trim();
            if (!message) return alert('Please enter a message');
            
            try {
                await fetch('/message', {
                    method: 'POST',
                    headers: { 'Content-Type': 'text/plain' },
                    body: message
                });
                input.value = '';
                loadMessages();
            } catch (e) {
                alert('Failed to send');
            }
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        loadMessages();
        setInterval(loadMessages, 3000);
    </script>
</body>
</html>"#;

    let _ = socket.send_slice(html.as_bytes());
}

fn send_messages(socket: &mut smoltcp::socket::tcp::Socket) {
    let messages = critical_section::with(|cs| {
        let msgs = MESSAGES.borrow_ref(cs);
        let mut result = String::<4096>::new();
        for (i, msg) in msgs.iter().enumerate() {
            if i > 0 {
                result.push('\x1E').unwrap();
            }
            result.push_str(msg.as_str()).unwrap();
        }
        result
    });

    let response = format_http_response(200, "OK", "text/plain", &messages);
    let _ = socket.send_slice(response.as_bytes());
}

fn receive_message(socket: &mut smoltcp::socket::tcp::Socket, request: &str) {
    if let Some(body_start) = request.find("\r\n\r\n") {
        let body = &request[body_start + 4..];
        let clean_body = body.replace('\x1E', "");

        if !clean_body.is_empty() {
            let truncated = if clean_body.len() > MAX_MESSAGE_LEN - 1 {
                &clean_body[..MAX_MESSAGE_LEN - 1]
            } else {
                &clean_body
            };

            critical_section::with(|cs| {
                let mut msgs = MESSAGES.borrow_ref_mut(cs);
                if msgs.len() >= MAX_MESSAGES {
                    msgs.remove(0);
                }
                let _ = msgs.push(String::from_str(truncated).unwrap());
            });

            println!("New message: {}", truncated);
        }
    }

    let response = format_http_response(200, "OK", "text/plain", "OK");
    let _ = socket.send_slice(response.as_bytes());
}

fn send_404(socket: &mut smoltcp::socket::tcp::Socket) {
    let response = format_http_response(404, "Not Found", "text/plain", "Not found");
    let _ = socket.send_slice(response.as_bytes());
}

fn format_http_response(
    status_code: u16,
    status_text: &str,
    content_type: &str,
    body: &str,
) -> String<8192> {
    let mut response = String::<8192>::new();

    response.push_str("HTTP/1.1 ").unwrap();
    response.push_str(&u16_to_str(status_code)).unwrap();
    response.push(' ').unwrap();
    response.push_str(status_text).unwrap();
    response.push_str("\r\n").unwrap();

    response.push_str("Content-Type: ").unwrap();
    response.push_str(content_type).unwrap();
    response.push_str("\r\n").unwrap();

    response.push_str("Content-Length: ").unwrap();
    response.push_str(&usize_to_str(body.len())).unwrap();
    response.push_str("\r\n").unwrap();

    response.push_str("Connection: close\r\n").unwrap();
    response.push_str("\r\n").unwrap();
    response.push_str(body).unwrap();

    response
}

fn u16_to_str(n: u16) -> String<6> {
    let mut result = String::<6>::new();
    if n == 0 {
        result.push('0').unwrap();
        return result;
    }

    let mut n = n;
    let mut buf = [0u8; 6];
    let mut i = 0;

    while n > 0 {
        buf[i] = (n % 10) as u8 + b'0';
        n /= 10;
        i += 1;
    }

    for j in (0..i).rev() {
        result.push(buf[j] as char).unwrap();
    }

    result
}

fn usize_to_str(n: usize) -> String<10> {
    let mut result = String::<10>::new();
    if n == 0 {
        result.push('0').unwrap();
        return result;
    }

    let mut n = n;
    let mut buf = [0u8; 10];
    let mut i = 0;

    while n > 0 {
        buf[i] = (n % 10) as u8 + b'0';
        n /= 10;
        i += 1;
    }

    for j in (0..i).rev() {
        result.push(buf[j] as char).unwrap();
    }

    result
}
