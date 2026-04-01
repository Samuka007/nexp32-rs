#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]
#![deny(clippy::large_stack_frames)]
#![allow(async_fn_in_trait)]

use esp_hal::clock::CpuClock;
use esp_hal::i2c::master::{Config as I2cConfig, I2c};
use esp_hal::main;
use esp_hal::time::{Duration, Instant};
use esp_hal::uart::{Config as UartConfig, Uart};
use esp_println::println;

// Type alias for I2c driver
use esp_hal::Blocking;
type I2cDriver<'a> = I2c<'a, Blocking>;

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    println!("Panic: {:?}", info);
    loop {}
}

esp_bootloader_esp_idf::esp_app_desc!();

// GPS UART configuration
const GPS_BAUD_RATE: u32 = 9600;

// I2C configuration for AXP192 (using GPIO21 for SDA, GPIO22 for SCL)

// AXP192 register addresses
const AXP192_SLAVE_ADDR: u8 = 0x34;
const AXP192_LDO2_CTRL: u8 = 0x28;
const AXP192_LDO3_CTRL: u8 = 0x29;
const AXP192_DCDC2_CTRL: u8 = 0x23;
const AXP192_EXTEN_CTRL: u8 = 0x10;
const AXP192_DCDC1_CTRL: u8 = 0x26;

#[allow(clippy::large_stack_frames)]
#[main]
fn main() -> ! {
    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let peripherals = esp_hal::init(config);

    println!("TTGO GPS Example Starting...");

    // Initialize I2C for AXP192 power management
    let i2c = I2c::new(peripherals.I2C0, I2cConfig::default()).expect("Failed to create I2C");

    let mut i2c = i2c
        .with_sda(peripherals.GPIO21)
        .with_scl(peripherals.GPIO22);

    // Initialize AXP192 and power up GPS
    println!("Initializing AXP192 power management...");
    if let Err(e) = init_axp192(&mut i2c) {
        println!("AXP192 initialization error: {:?}", e);
    } else {
        println!("AXP192 initialized successfully");
    }

    // Wait for power to stabilize
    let delay_start = Instant::now();
    while delay_start.elapsed() < Duration::from_millis(100) {}

    // Initialize UART for GPS
    println!("Initializing GPS UART...");
    let uart_config = UartConfig::default().with_baudrate(GPS_BAUD_RATE);

    let mut uart = Uart::new(peripherals.UART1, uart_config)
        .expect("Failed to create UART")
        .with_rx(peripherals.GPIO34)
        .with_tx(peripherals.GPIO12);

    println!("GPS initialized. Reading data...");
    println!("Format: Latitude, Longitude, Satellites, Altitude(m), Time, Speed(kmph)");
    println!("================================================================");

    // GPS data buffer
    let mut buffer = [0u8; 256];
    let mut buf_pos = 0;

    loop {
        // Read data from GPS
        match uart.read(&mut buffer[buf_pos..buf_pos + 1]) {
            Ok(1) => {
                let byte = buffer[buf_pos];
                if byte == b'\n' || byte == b'\r' {
                    if buf_pos > 0 {
                        // Process the line
                        let line = core::str::from_utf8(&buffer[..buf_pos]).unwrap_or("");
                        process_nmea_line(line);
                        buf_pos = 0;
                    }
                } else if buf_pos < buffer.len() - 1 {
                    buf_pos += 1;
                }
            }
            Ok(_) => {}
            Err(e) => {
                println!("UART read error: {:?}", e);
            }
        }
    }
}

/// Initialize AXP192 and power up all required rails
fn init_axp192(i2c: &mut I2cDriver<'_>) -> Result<(), esp_hal::i2c::master::Error> {
    // Enable LDO2 (GPS power)
    let mut ldo2 = read_register(i2c, AXP192_LDO2_CTRL)?;
    ldo2 |= 0x04; // Enable LDO2
    write_register(i2c, AXP192_LDO2_CTRL, ldo2)?;

    // Enable LDO3
    let mut ldo3 = read_register(i2c, AXP192_LDO3_CTRL)?;
    ldo3 |= 0x04;
    write_register(i2c, AXP192_LDO3_CTRL, ldo3)?;

    // Enable DCDC2
    let mut dcdc2 = read_register(i2c, AXP192_DCDC2_CTRL)?;
    dcdc2 |= 0x04;
    write_register(i2c, AXP192_DCDC2_CTRL, dcdc2)?;

    // Enable EXTEN
    let mut exten = read_register(i2c, AXP192_EXTEN_CTRL)?;
    exten |= 0x04;
    write_register(i2c, AXP192_EXTEN_CTRL, exten)?;

    // Enable DCDC1
    let mut dcdc1 = read_register(i2c, AXP192_DCDC1_CTRL)?;
    dcdc1 |= 0x04;
    write_register(i2c, AXP192_DCDC1_CTRL, dcdc1)?;

    Ok(())
}

fn read_register(i2c: &mut I2cDriver<'_>, reg: u8) -> Result<u8, esp_hal::i2c::master::Error> {
    let mut buf = [0u8; 1];
    i2c.write_read(AXP192_SLAVE_ADDR, &[reg], &mut buf)?;
    Ok(buf[0])
}

fn write_register(
    i2c: &mut I2cDriver<'_>,
    reg: u8,
    value: u8,
) -> Result<(), esp_hal::i2c::master::Error> {
    i2c.write(AXP192_SLAVE_ADDR, &[reg, value])
}

/// Parse and display NMEA sentences
fn process_nmea_line(line: &str) {
    if line.starts_with("$GNGGA") || line.starts_with("$GPGGA") {
        // GGA - Global Positioning System Fix Data
        if let Some(data) = parse_gga(line) {
            println!("Latitude  : {:.5}", data.latitude);
            println!("Longitude : {:.4}", data.longitude);
            println!("Satellites: {}", data.satellites);
            println!("Altitude  : {:.1} M", data.altitude);
            println!(
                "Time      : {:02}:{:02}:{:02}",
                data.hour, data.minute, data.second
            );
            println!("**********************");
        }
    } else if line.starts_with("$GNVTG") || line.starts_with("$GPVTG") {
        // VTG - Track made good and Ground speed
        if let Some(speed) = parse_vtg(line) {
            println!("Speed     : {:.1} kmph", speed);
        }
    }
}

#[derive(Debug)]
struct GgaData {
    latitude: f64,
    longitude: f64,
    satellites: u32,
    altitude: f64,
    hour: u32,
    minute: u32,
    second: u32,
}

fn parse_gga(line: &str) -> Option<GgaData> {
    let parts: heapless::Vec<&str, 16> = line.split(',').collect();

    if parts.len() < 10 {
        return None;
    }

    // Parse time (HHMMSS.SS)
    let time_str = parts.get(1)?;
    let hour = time_str.get(0..2)?.parse().unwrap_or(0);
    let minute = time_str.get(2..4)?.parse().unwrap_or(0);
    let second = time_str.get(4..6)?.parse().unwrap_or(0);

    // Parse latitude
    let lat_str = parts.get(2)?;
    let lat_dir = parts.get(3)?;
    let latitude = parse_coordinate(lat_str, lat_dir, true)?;

    // Parse longitude
    let lon_str = parts.get(4)?;
    let lon_dir = parts.get(5)?;
    let longitude = parse_coordinate(lon_str, lon_dir, false)?;

    // Parse satellites
    let satellites = parts.get(7)?.parse().unwrap_or(0);

    // Parse altitude
    let altitude = parts.get(9)?.parse().unwrap_or(0.0);

    Some(GgaData {
        latitude,
        longitude,
        satellites,
        altitude,
        hour,
        minute,
        second,
    })
}

fn parse_vtg(line: &str) -> Option<f64> {
    let parts: heapless::Vec<&str, 12> = line.split(',').collect();

    if parts.len() < 8 {
        return None;
    }

    // Ground speed in km/h is in field 7 (index 7)
    parts.get(7)?.parse().ok()
}

fn parse_coordinate(coord: &str, dir: &str, is_latitude: bool) -> Option<f64> {
    if coord.is_empty() {
        return None;
    }

    let (degrees, minutes): (f64, f64) = if is_latitude {
        // Latitude format: DDMM.MMMM
        let deg: f64 = coord.get(0..2)?.parse().ok()?;
        let min: f64 = coord.get(2..)?.parse().ok()?;
        (deg, min)
    } else {
        // Longitude format: DDDMM.MMMM
        let deg: f64 = coord.get(0..3)?.parse().ok()?;
        let min: f64 = coord.get(3..)?.parse().ok()?;
        (deg, min)
    };

    let value = degrees + (minutes / 60.0);

    if dir == "S" || dir == "W" {
        Some(-value)
    } else {
        Some(value)
    }
}
