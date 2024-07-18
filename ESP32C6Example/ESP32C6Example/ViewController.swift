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
    
    // TODO: enable in future commits, but make sure to connect and disconnect.
    // setupButton()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
      self.readData()
    }
  }
  
  private func setupButton() {
    let action = UIAction(title:"Read data", handler: { [weak self] _ in
      self?.readData()
    })
    let button = UIButton(primaryAction: action)
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
    
    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }
  
  // TODO: disconnect after reading all data.
  private func readData() {
    guard let centralManager else { return }
    
    let serviceUUID = CBUUID(string: "0x00FF")
    let mainStream = centralManager.scanForPeripherals(
      withServices: [serviceUUID],
      options: nil
    )
    
    let characteristicsStream = mainStream
      .first()
      .handleEvents(receiveOutput: { _ in
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
  }
  
  private func observeCharacteristic(
    for stream: AnyPublisher<BLECharacteristic, BLEError>,
    uuidString: String,
    name: String
  ) {
    // Create an AsyncThrowingPublisher from a Publisher stream which can then
    // be awaited in a Task. Add a delay at the end of the stream to avoid generating many
    // requests, as each request will internally trigger a new read event.
    let asyncStream = stream
        .filter { $0.value.uuid == CBUUID(string: uuidString) }
        .flatMap { $0.observeValue() }
        .delay(for: .seconds(1), scheduler: RunLoop.main)
        .values
    
    Task {
      for try await data in asyncStream {
        print("\(name): \(data.uintValue?.correctBytes ?? 0)")
      }
      print("Finished reading \(name)")
    }
  }
  
}

extension UInt32 {
  // TODO: modify the firmware side to send this data properly.
  var correctBytes: UInt32 {
    var value: UInt32 = 0
    value |= (self & 0xFF000000) >> 24
    value |= (self & 0xFF0000) >> 8
    value |= (self & 0xFF00) << 8
    value |= (self & 0xFF) << 24
    return value
  }
}
