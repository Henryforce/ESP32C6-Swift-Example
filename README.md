# WORK IN PROGRESS

This example works as expected (granted that you have an LTR390 sensor connected to a ESP32C6) but it is ongoing constant updates and refactoring to improve the code's readability.

# Embedded Swift Example: BLE + I2C in the ESP32C6

> [!IMPORTANT]
> Please follow (Apple's tutorial)[https://apple.github.io/swift-matter-examples/tutorials/swiftmatterexamples/setup-macos] on how to setup the required toolchain

This project contains a project written with Embedded Swift that can be built using the ESP IDF, and uploaded to an ESP32C6 development board.

Breakdown of the files included:

- **CMakeLists.txt** — Top-level CMake configuration file for the example, similar to the ["light" example from the ESP Matter SDK](https://github.com/espressif/esp-matter/tree/main/examples/light), with the minimum CMake version increased to 3.29 as required by Swift.
- **partitions.csv** — Partition table for the firmware. Same as the ["light" example from the ESP Matter SDK](https://github.com/espressif/esp-matter/tree/main/examples/light).
- **README.md** — This documentation file.
- **sdkconfig.defaults** — Compile-time settings for the ESP IDF. Similar with some changes as the ["light" example from the ESP Matter SDK](https://github.com/espressif/esp-matter/tree/main/examples/light).
- **main/** — Subdirectory with actual source files to build.
  - **main/BridgingHeader.h** — A bridging header that imports C and C++ declarations from ESP IDF and ESP Matter SDKs into Swift.
  - **main/CmakeLists.txt** — CMake configuration describing what files to build and how. This includes a lot of Embedded Swift specific logic (e.g. Swift compiler flags).
  - **main/idf_component.yml** — Dependency list for the IDF Component Manager. Same as the ["light" example from the ESP Matter SDK](https://github.com/espressif/esp-matter/tree/main/examples/light).
  - **main/Main.swift** — Main file with Embedded Swift source code.

## Building and running the example

For full steps how to build the example code, follow the [Setup Your Environment](https://apple.github.io/swift-embedded/swift-matter-examples/tutorials/tutorial-table-of-contents#setup-your-environment) tutorials and the "Build and Run" section of the [Explore the LED Blink example](https://apple.github.io/swift-matter-examples/tutorials/swiftmatterexamples/run-example-led-blink) tutorial. In summary:

- Ensure your system has all the required software installed and your shell has access to the tools listed in the top-level README file.
- Plug in the ESP32C6 development board via a USB cable.

1. Clone the repository 

2. Configure the build system for your microcontroller.
  ```shell
  $ idf.py set-target esp32c6
  ```

3. Build and deploy the application to your device. 
  ```shell
  $ idf.py build flash monitor
  ```
Note that some changes might require a clean. 
  ```shell
  $ idf.py clean
  ```

## Helpful information

This project is connected to a development board that has a LTR390 light sensor. See (datasheet)[https://optoelectronics.liteon.com/upload/download/DS86-2015-0004/LTR-390UV_Final_%20DS_V1%201.pdf].

This project makes use of the (I2C library)[https://docs.espressif.com/projects/esp-idf/en/v5.2.2/esp32/api-reference/peripherals/i2c.html] from Espressif. Note that the attached link is versioned and might not be up to date with the latest release.

This project also leverages the Bluetooth LE libraries provided by ESP-IDF to advertise a service for reading the sensor data.
