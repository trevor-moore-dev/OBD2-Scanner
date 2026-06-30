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
    private let dashboardViewModel: DashboardViewModel
    
    init() {
        transport = MockTransport()
        obdService = OBDService(
            transport: transport
        )
        
        dashboardViewModel = DashboardViewModel(
            obdService: obdService
        )
    }
    
    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: dashboardViewModel)
        }
    }
}
