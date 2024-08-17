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

@Observable
final class ViewModelCombine {
  @ObservationIgnored
  private var centralManager = BLECombineKit.buildCentralManager()
  
  @ObservationIgnored
  private var cancellables = Set<AnyCancellable>()
  
  var state = ViewModelState.loading
  
  func startSetup() {
    let serviceUUID = CBUUID(string: "0x00FF")
    let mainStream = centralManager.scanForPeripherals(
      withServices: [serviceUUID],
      options: nil
    )
    
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
    
    let ambientLightObservable = observeCharacteristic(for: characteristicsStream, uuidString: "0xFF01", name: "Ambient Light")
    let uvIndexObservable = observeCharacteristic(for: characteristicsStream, uuidString: "0xFF02", name: "UV Index")
    let temperatureObservable = observeCharacteristic(for: characteristicsStream, uuidString: "0xFF03", name: "Temperature")
    let humidityObservable = observeCharacteristic(for: characteristicsStream, uuidString: "0xFF04", name: "Humidity")
    
    Publishers.Zip4(ambientLightObservable, uvIndexObservable, temperatureObservable, humidityObservable)
      .receive(on: DispatchQueue.main)
      .sink { completion in
        print(completion)
      } receiveValue: { [weak self] (ambientLight, uvIndex, temperature, humidity) in
        guard let self else { return }
        let data = DataUpdated(ambientLight: ambientLight, uvIndex: uvIndex, temperature: temperature, humidity: humidity)
        print(data)
        self.state = .dataUpdated(data)
      }.store(in: &cancellables)
  }
  
  private func observeCharacteristic(
    for stream: AnyPublisher<BLECharacteristic, BLEError>,
    uuidString: String,
    name: String
  ) -> AnyPublisher<Int, BLEError> {
    // Create an AsyncThrowingPublisher from a Publisher stream which can then
    // be awaited in a Task. Add a delay at the end of the stream to avoid generating many
    // requests, as each request will internally trigger a new read event.
    return stream
      .filter { $0.value.uuid == CBUUID(string: uuidString) }
      .flatMap { $0.observeValueUpdateAndSetNotification() }
      .map { Int($0.uintValue?.correctBytes ?? 0) }
      .eraseToAnyPublisher()
  }
}
