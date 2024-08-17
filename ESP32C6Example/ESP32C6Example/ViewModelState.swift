//
//  MainViewModel.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 27/7/24.
//

import Foundation

struct DataUpdated {
  let ambientLight: Int
  let uvIndex: Int
  let temperature: Int
  let humidity: Int
}

enum ViewModelState {
  case loading
  case dataUpdated(DataUpdated)
}
