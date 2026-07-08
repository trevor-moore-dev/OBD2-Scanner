//
//  DashboardView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

struct DashboardView: View {
    
    @StateObject private var viewModel: DashboardViewModel
    
    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("OBD-II Scanner")
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("RPM: \(viewModel.snapshot?.rpm ?? 0)")
                Text("Coolant Temp: \(viewModel.snapshot?.coolantTemp ?? 0) \(PID.coolantTemperature.unit)")
                Text("Speed: \(viewModel.snapshot?.speed ?? 0) \(PID.vehicleSpeed.unit)")
                Text("Throttle Position: \(viewModel.snapshot?.throttlePosition ?? 0) \(PID.throttlePosition.unit)")
                Text("Timestamp: \((viewModel.snapshot?.timestamp ?? Date()).formatted(date: .numeric, time: .standard))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: {
                viewModel.isScanning ? viewModel.stop() : viewModel.start()
            }) {
                Text(viewModel.isScanning ? "Stop Scan" : "Start Scan")
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding()
    }
}

#Preview {
    let transport = BluetoothTransport()
    let service = OBDService(
        transport: transport
    )
    
    let viewModel = DashboardViewModel(
        obdService: service
    )

    DashboardView(viewModel: viewModel)
}
