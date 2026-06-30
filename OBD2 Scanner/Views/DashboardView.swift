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
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, Mr. Moore")
            
            Text("RPM: \(viewModel.rpm)")
            
            Button("Refresh") {
                Task {
                    await viewModel.refresh()
                }
            }
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
