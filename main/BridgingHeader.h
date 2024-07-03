//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// C standard library
// ==================

#include <stdio.h>
#include <math.h>
// #include <string.h>
// #include <stdlib.h>
#include <inttypes.h>

// ESP IDF
// =======

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
// #include <led_strip.h>
#include <sdkconfig.h>
#include <nvs_flash.h>
// #include <led_driver.h>
// #include <device.h>
#include <driver/i2c.h>
#include <esp_bt.h>

#include <esp_gap_ble_api.h>
#include <esp_gatts_api.h>
#include <esp_bt_defs.h>
#include <esp_bt_main.h>
#include <esp_gatt_common_api.h>

// Main Interface
// ======================

#include "MainInterface.h"

// BLE Controller interface
// ======================

#include "../ble/ESP32BLEControllerInterface.h"

