//
//  OBD2_ScannerApp.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

@main
struct OBD2_ScannerApp: App {

    @State private var loading: Bool = true
    
    private var obdService: OBDService
    private var dtcRepository: DTCRepository
    
    init() {
        self.obdService = OBDService(transport: BluetoothTransport())
        self.dtcRepository = DTCRepository()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if loading {
                    SplashScreenView()
                } else {
                    LayoutView(
                        obdService: obdService,
                        dtcRepository: dtcRepository
                    )
                }
            }
            .animation(.easeInOut(duration: 0.6), value: loading)
            .task {
                try? await Task.sleep(for: .seconds(3))
                loading = false
            }
        }
    }
}
