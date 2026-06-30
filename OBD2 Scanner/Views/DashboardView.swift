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
                if let snapshot = viewModel.snapshot {
                    Text("RPM: \(snapshot.rpm)")
                    Text("Coolant Temp: \(snapshot.coolantTemp) \(PID.coolantTemperature.unit)")
                    Text("Speed: \(snapshot.speed) \(PID.vehicleSpeed.unit)")
                    Text("Throttle Position: \(snapshot.throttlePosition) \(PID.throttlePosition.unit)")
                    Text("Timestamp: \(snapshot.timestamp.formatted(date: .numeric, time: .standard))")
                }
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
    let transport = MockTransport()
    let service = OBDService(
        transport: transport
    )
    
    let viewModel = DashboardViewModel(
        obdService: service
    )

    DashboardView(viewModel: viewModel)
}
