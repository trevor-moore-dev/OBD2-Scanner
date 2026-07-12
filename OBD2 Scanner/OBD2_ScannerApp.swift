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
    @ObservedObject private var dtcService: DTCService
    
    init() {
        let transport = BluetoothTransport()
        let repository = DTCRepository()
        
        _obdService = ObservedObject(wrappedValue: OBDService(
            transport: transport
        ))
        
        _dtcService = ObservedObject(wrappedValue: DTCService(
            transport: transport,
            repository: repository
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if obdService.connection != .ready {
                    SplashScreenView()
                } else {
                    LayoutView(obdService: obdService, dtcService: dtcService)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: obdService.connection)
            .task {
                await obdService.connect()
            }
        }
    }
}
