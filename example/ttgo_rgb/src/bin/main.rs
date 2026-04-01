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

// TTGO T-Display has an onboard LED on GPIO 2
// We'll simulate RGB colors by blinking with different patterns
const LED_PIN: u8 = 2;

// Color patterns (blink count, blink duration in ms)
// Simulating different "colors" through blink patterns
const COLOR_PATTERNS: [(u32, u32); 7] = [
    (1, 1000), // Red - 1 long blink
    (2, 500),  // Green - 2 medium blinks
    (3, 333),  // Blue - 3 short blinks
    (4, 250),  // White - 4 very short blinks
    (5, 200),  // Yellow - 5 rapid blinks
    (6, 166),  // Cyan - 6 faster blinks
    (7, 142),  // Magenta - 7 very rapid blinks
];

#[allow(clippy::large_stack_frames)]
#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    println!("TTGO RGB Simulation Example Starting...");
    println!(
        "Using GPIO {} LED to simulate RGB colors with blink patterns",
        LED_PIN
    );

    // Create output driver for GPIO 2
    let config = OutputConfig::default();
    let mut led = Output::new(peripherals.GPIO2, Level::Low, config);

    let mut color_index = 0;
    const COLOR_NAMES: [&str; 7] = ["Red", "Green", "Blue", "White", "Yellow", "Cyan", "Magenta"];

    loop {
        let (blink_count, blink_duration_ms) = COLOR_PATTERNS[color_index];
        let color_name = COLOR_NAMES[color_index];

        println!(
            "Color: {} ({} blinks, {}ms each)",
            color_name, blink_count, blink_duration_ms
        );

        // Perform blink pattern
        for _ in 0..blink_count {
            led.set_high();
            let delay_start = Instant::now();
            while delay_start.elapsed() < Duration::from_millis((blink_duration_ms / 2) as u64) {}

            led.set_low();
            let delay_start = Instant::now();
            while delay_start.elapsed() < Duration::from_millis((blink_duration_ms / 2) as u64) {}
        }

        // Pause between colors
        let delay_start = Instant::now();
        while delay_start.elapsed() < Duration::from_millis(1000) {}

        color_index = (color_index + 1) % COLOR_PATTERNS.len();
    }
}
