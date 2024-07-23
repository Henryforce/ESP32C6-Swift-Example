//
//  ViewModelAsync.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 21/7/24.
//

import Foundation
import Combine
import CoreBluetooth
import BLECombineKit

final class ViewModelAsync {
  private var centralManager = BLECombineKit.buildCentralManager()
  private var cancellables = Set<AnyCancellable>()
  
  func startSetup() {
    Task {
      let serviceUUID = CBUUID(string: "0x00FF")
      let scanStream = centralManager.scanForPeripheralsStream(
        withServices: [serviceUUID],
        options: nil
      )
      
      for try await peripheral in scanStream {
        try await connectAndRead(peripheral)
        break
      }
    }
    Task {
      try await Task.sleep(for: .seconds(3))
      centralManager.stopScan()
    }
  }
  
  private func connectAndRead(_ peripheral: BLEPeripheral) async throws {
    let serviceUUID = CBUUID(string: "0x00FF")
    
    try await peripheral.connectAsync(with: nil)
    
    let services = try await peripheral.discoverServicesAsync(serviceUUIDs: [serviceUUID])
    
    guard let service = services.first(where: { service in
      service.value.uuid == serviceUUID
    }) else { return }
    let characteristics = try await service.discoverCharacteristicsAsync(characteristicUUIDs: nil)
    
    for characteristic in characteristics {
      if characteristic.value.uuid == CBUUID(string: "0xFF01") {
        observeCharacteristicStream(characteristic, title: "Ambient Light")
      } else if characteristic.value.uuid == CBUUID(string: "0xFF02") {
        observeCharacteristicStream(characteristic, title: "UV Index")
      } else if characteristic.value.uuid == CBUUID(string: "0xFF03") {
        observeCharacteristicStream(characteristic, title: "Temperature")
      } else if characteristic.value.uuid == CBUUID(string: "0xFF04") {
        observeCharacteristicStream(characteristic, title: "Humidity")
      }
    }
  }
  
  private func observeCharacteristicStream(
    _ characteristic: BLECharacteristic,
    title: String
  ) {
    Task {
      let stream = characteristic.observeValueUpdateAndSetNotificationStream()
      for try await data in stream {
        try Task.checkCancellation()
        let value = data.uintValue?.correctBytes ?? 0
        print("\(title): \(value)")
      }
    }
  }
}
