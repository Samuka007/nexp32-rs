#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]
#![deny(clippy::large_stack_frames)]

use esp_hal::clock::CpuClock;
use esp_hal::gpio::{Level, Output, OutputConfig};
use esp_hal::main;
use esp_hal::time::{Duration, Instant};
use esp_println::println;

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

esp_bootloader_esp_idf::esp_app_desc!();

// TTGO T-Display built-in LED is on GPIO 2
const LED_PIN: u8 = 2;

#[allow(clippy::large_stack_frames)]
#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    println!("TTGO Blink Example Starting...");
    println!("Blinking LED on GPIO {}", LED_PIN);

    // Create output driver for GPIO 2
    let config = OutputConfig::default();
    let mut led = Output::new(peripherals.GPIO2, Level::Low, config);

    let mut led_on = false;

    loop {
        // Toggle LED
        if led_on {
            led.set_low();
            println!("LED OFF");
        } else {
            led.set_high();
            println!("LED ON");
        }
        led_on = !led_on;

        // Delay 500ms
        let delay_start = Instant::now();
        while delay_start.elapsed() < Duration::from_millis(500) {}
    }
}
