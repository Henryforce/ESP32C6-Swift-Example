//
//  ViewController.swift
//  ESP32C6Example
//
//  Created by Henry Javier Serrano Echeverria on 7/7/24.
//

import UIKit
import SwiftUI
import BLECombineKit
import CoreBluetooth
import Combine

@MainActor
final class ViewController: UIViewController {
    
//  private var viewModel = ViewModelCombine()
  private var viewModel = ViewModelCombine()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
      self.viewModel.startSetup()
    }
    let mainView: UIView = UIHostingConfiguration {
      MainView(viewModel: viewModel)
    }.makeContentView()
    mainView.translatesAutoresizingMaskIntoConstraints = false
    
    view.addSubview(mainView)
    NSLayoutConstraint.activate([
      mainView.topAnchor.constraint(equalTo: view.topAnchor),
      mainView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      mainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }
  
//  private func setupButton() {
//    let action = UIAction(title:"Read data", handler: { [weak self] _ in
////      self?.readData()
////      self?.startScanning()
//    })
//    let button = UIButton(primaryAction: action)
//    button.translatesAutoresizingMaskIntoConstraints = false
//    view.addSubview(button)
//    
//    NSLayoutConstraint.activate([
//      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//      button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//    ])
//  }
  
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
