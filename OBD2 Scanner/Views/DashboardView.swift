//
//  DashboardView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

struct DashboardView: View {
    
    @ObservedObject private var obdService: OBDService
    
    init(obdService: OBDService) {
        _obdService = ObservedObject(wrappedValue: obdService)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("OBD-II Scanner")
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("RPM: \(obdService.snapshot?.rpm ?? 0)")
                Text("Coolant Temp: \(obdService.snapshot?.coolantTemp ?? 0) \(PID.coolantTemperature.unit)")
                Text("Speed: \(obdService.snapshot?.speed ?? 0) \(PID.vehicleSpeed.unit)")
                Text("Throttle Position: \(obdService.snapshot?.throttlePosition ?? 0) \(PID.throttlePosition.unit)")
                Text("Timestamp: \((obdService.snapshot?.timestamp ?? Date()).formatted(date: .numeric, time: .standard))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: {
                obdService.isStreaming ? obdService.stopStream() : obdService.startStream()
            }) {
                Text(obdService.isStreaming ? "Stop Scan" : "Start Scan")
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .disabled(obdService.connection != .ready)
        }
        .padding()
    }
}

#Preview {
    let transport = BluetoothTransport()
    let service = OBDService(
        transport: transport
    )

    DashboardView(obdService: service)
}
