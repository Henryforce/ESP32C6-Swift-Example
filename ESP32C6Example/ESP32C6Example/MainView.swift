//
//  MainView.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 27/7/24.
//

import SwiftUI

struct MainView: View {
  var viewModel: ViewModelCombine
  
  var body: some View {
    VStack {
      Color.clear
      contentView
      Color.clear
    }
  }
  
  @ViewBuilder
  private var contentView: some View {
    switch viewModel.state {
    case .loading:
      ProgressView()
    case .dataUpdated(let data):
      VStack {
        Text("Ambient Light: \(data.ambientLight)")
        Text("UV Index: \(data.uvIndex)")
        Text("Temperature: \(data.temperature)")
        Text("Humidity: \(data.humidity)")
      }
    }
  }
}
