//
//  ViewModelCombine.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 21/7/24.
//

import Foundation
import Combine
import CoreBluetooth
import BLECombineKit

final class ViewModelCombine {
  private var centralManager = BLECombineKit.buildCentralManager()
  private var cancellables = Set<AnyCancellable>()
  
  func startSetup() {
    let serviceUUID = CBUUID(string: "0x00FF")
//    let serviceUUID = CBUUID(string: "0x1818")
    let mainStream = centralManager.scanForPeripherals(
      withServices: [serviceUUID],
      options: nil
    )
//    let mainStream = centralManager.scanForPeripherals(
//      withServices: [],
//      options: nil
//    ).filter { output in
//      guard let name = output.peripheral.associatedPeripheral.name else {
//        return false
//      }
//      let hasPrefix = name.hasPrefix("Henry Javier")
//      if !hasPrefix {
//        print("Filtered \(name)")
//      } else {
//        print("Found prefix device")
//      }
//      return hasPrefix
//    }
    
    let characteristicsStream = mainStream
      .first()
      .handleEvents(receiveOutput: { [centralManager] _ in
        print("Output: something happened")
        centralManager.stopScan()
      })
      .flatMap { $0.peripheral.connect(with: nil) }
      .flatMap { $0.discoverServices(serviceUUIDs: [serviceUUID]) }
      .flatMap { $0.discoverCharacteristics(characteristicUUIDs: nil) }
      .share()
      .eraseToAnyPublisher()
    
    observeCharacteristic(for: characteristicsStream, uuidString: "0xFF01", name: "Ambient Light")
    observeCharacteristic(for: characteristicsStream, uuidString: "0xFF02", name: "UV Index")
    observeCharacteristic(for: characteristicsStream, uuidString: "0xFF03", name: "Temperature")
    observeCharacteristic(for: characteristicsStream, uuidString: "0xFF04", name: "Humidity")
//    observeCharacteristic(for: characteristicsStream, uuidString: "0x2A64", name: "Cycling power")
  }
  
  private func observeCharacteristic(
    for stream: AnyPublisher<BLECharacteristic, BLEError>,
    uuidString: String,
    name: String
  ) {
    // Create an AsyncThrowingPublisher from a Publisher stream which can then
    // be awaited in a Task. Add a delay at the end of the stream to avoid generating many
    // requests, as each request will internally trigger a new read event.
    stream
      .filter { $0.value.uuid == CBUUID(string: uuidString) }
      .flatMap { $0.observeValueUpdateAndSetNotification() }
      .sink { completion in
        print("\(name) completed!")
      } receiveValue: { data in
        print("\(name): \(data.uintValue?.correctBytes ?? 0)")
      }.store(in: &cancellables)
  }
}
