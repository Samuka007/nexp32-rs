#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]
#![deny(clippy::large_stack_frames)]

use core::cell::RefCell;
use critical_section::Mutex;
use esp_hal::clock::CpuClock;
use esp_hal::gpio::{Input, InputConfig, Level, Output, OutputConfig, Pull};
use esp_hal::main;
use esp_hal::time::{Duration, Instant};
use esp_println::println;

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

esp_bootloader_esp_idf::esp_app_desc!();

// TTGO T-Display pins (documented for reference)
// const BUTTON1_PIN: u8 = 0; // BOOT button - used as GPIO0
// const BUTTON2_PIN: u8 = 35; // User button - used as GPIO35
// const LED_PIN: u8 = 2; // Onboard LED - used as GPIO2

// Blink speed state - shared between button detection and main loop
static BLINK_SPEED: Mutex<RefCell<u32>> = Mutex::new(RefCell::new(500));

#[allow(clippy::large_stack_frames)]
#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    println!("TTGO Button Example Starting...");
    println!("Press BOOT button (GPIO 0) to speed up blinking");
    println!("Press User button (GPIO 35) to slow down blinking");

    // Configure buttons as inputs with pull-up
    let button1_config = InputConfig::default().with_pull(Pull::Up);
    let button2_config = InputConfig::default().with_pull(Pull::Up);
    let button1 = Input::new(peripherals.GPIO0, button1_config);
    let button2 = Input::new(peripherals.GPIO35, button2_config);

    // Configure LED as output
    let led_config = OutputConfig::default();
    let mut led = Output::new(peripherals.GPIO2, Level::Low, led_config);

    let mut last_button1_state = true; // Pulled up, so true when not pressed
    let mut last_button2_state = true;
    let mut led_on = false;

    loop {
        // Read button states (active low - false when pressed)
        let button1_pressed = button1.is_low();
        let button2_pressed = button2.is_low();

        // Detect button 1 press (BOOT button) - speed up
        if button1_pressed && last_button1_state {
            println!("BOOT button pressed! Speeding up...");
            critical_section::with(|cs| {
                let mut speed = BLINK_SPEED.borrow_ref_mut(cs);
                if *speed > 50 {
                    *speed -= 50;
                }
                println!("Blink speed: {}ms", *speed);
            });

            // Debounce delay
            let delay_start = Instant::now();
            while delay_start.elapsed() < Duration::from_millis(200) {}
        }

        // Detect button 2 press (User button) - slow down
        if button2_pressed && last_button2_state {
            println!("User button pressed! Slowing down...");
            critical_section::with(|cs| {
                let mut speed = BLINK_SPEED.borrow_ref_mut(cs);
                if *speed < 2000 {
                    *speed += 50;
                }
                println!("Blink speed: {}ms", *speed);
            });

            // Debounce delay
            let delay_start = Instant::now();
            while delay_start.elapsed() < Duration::from_millis(200) {}
        }

        last_button1_state = !button1_pressed;
        last_button2_state = !button2_pressed;

        // Toggle LED
        if led_on {
            led.set_low();
        } else {
            led.set_high();
        }
        led_on = !led_on;

        // Delay based on current blink speed
        let blink_speed = critical_section::with(|cs| *BLINK_SPEED.borrow_ref(cs));
        let delay_start = Instant::now();
        while delay_start.elapsed() < Duration::from_millis(blink_speed as u64) {}
    }
}
