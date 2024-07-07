//
//  ViewController.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 7/7/24.
//

import UIKit
import BLECombineKit
import CoreBluetooth
import Combine

@MainActor
final class ViewController: UIViewController {
  
  var centralManager: BLECentralManager?
  var disposables = Set<AnyCancellable>()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    centralManager = BLECombineKit.buildCentralManager(with: CBCentralManager())
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
      self.checkDevices()
    }
  }
  
  private func checkDevices() {
    guard let centralManager else { return }
    let serviceUUID = CBUUID(string: "0x00FF")
    let mainStream = centralManager.scanForPeripherals(
      withServices: [serviceUUID],
      options: nil
    )
    
    let characteristicsStream = mainStream
      .first()
      .flatMap { $0.peripheral.connect(with: nil) }
      .flatMap { $0.discoverServices(serviceUUIDs: [serviceUUID]) }
      .flatMap { $0.discoverCharacteristics(characteristicUUIDs: nil) }
      .share()
    
    characteristicsStream
      .filter { $0.value.uuid == CBUUID(string: "0xFF01") }
      .flatMap { $0.observeValue() }
      .sink(receiveCompletion: { completion in
        print(completion)
      }, receiveValue: { data in
        print("Ambient light: \(data.uintValue?.correctBytes ?? 0)")
      })
      .store(in: &disposables)
    
    characteristicsStream
      .filter { $0.value.uuid == CBUUID(string: "0xFF02") }
      .flatMap { $0.observeValue() }
      .sink(receiveCompletion: { completion in
        print(completion)
      }, receiveValue: { data in
        print("UV Index: \(data.uintValue?.correctBytes ?? 0)")
      })
      .store(in: &disposables)
    
    characteristicsStream
      .filter { $0.value.uuid == CBUUID(string: "0xFF03") }
      .flatMap { $0.observeValue() }
      .sink(receiveCompletion: { completion in
        print(completion)
      }, receiveValue: { data in
        print("Temperature: \(data.uintValue?.correctBytes ?? 0)")
      })
      .store(in: &disposables)
    
    characteristicsStream
      .filter { $0.value.uuid == CBUUID(string: "0xFF04") }
      .flatMap { $0.observeValue() }
      .sink(receiveCompletion: { completion in
        print(completion)
      }, receiveValue: { data in
        print("Humidity: \(data.uintValue?.correctBytes ?? 0)")
      })
      .store(in: &disposables)
  }
  
}

extension UInt32 {
  var correctBytes: UInt32 {
    var value: UInt32 = 0
    value |= (self & 0xFF000000) >> 24
    value |= (self & 0xFF0000) >> 8
    value |= (self & 0xFF00) << 8
    value |= (self & 0xFF) << 24
    return value
  }
}
