//
//  OBD2_ScannerApp.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

@main
struct OBD2_ScannerApp: App {
    
    private let transport: OBDTransport
    private let obdService: OBDService
    
    init() {
        transport = BluetoothTransport()
        obdService = OBDService(
            transport: transport
        )
    }
    
    var body: some Scene {
        WindowGroup {
            DashboardView(obdService: obdService)
                .task {
                    await obdService.connect()
                }
        }
    }
}
