//
//  OBD2_ScannerApp.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

@main
struct OBD2_ScannerApp: App {

    @ObservedObject private var obdService: OBDService
    
    init() {
        _obdService = ObservedObject(wrappedValue: OBDService(
            transport: BluetoothTransport()
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if obdService.connection != .ready {
                    SplashScreenView()
                } else {
                    LayoutView(obdService: obdService)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: obdService.connection)
            .task {
                await obdService.connect()
            }
        }
    }
}
