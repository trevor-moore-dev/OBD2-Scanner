//
//  Untitled.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI

enum ViewState {
    case screenLoad
    case scanning
    case clearing
    case results
}

@MainActor
struct DiagnosticsView: View {
    
    @ObservedObject private var obdService: OBDService
    
    @State private var errorCodes: [DTC] = []
    @State private var viewState: ViewState = .screenLoad
    @State private var showAlert: Bool = false
    
    private let dtcRepository: DTCRepository
    
    init(obdService: OBDService, dtcRepository: DTCRepository) {
        _obdService = ObservedObject(wrappedValue: obdService)
        self.dtcRepository = dtcRepository
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                switch viewState {
                case .screenLoad:
                    VStack(spacing: 12) {
                        Image(systemName: "engine.combustion")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("Scan diagnostic trouble codes from your vehicle's ECUs.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        Text("Connect to your bluetooth ELM327 device to begin scanning.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: .infinity)
                case .scanning, .clearing:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(viewState == .clearing ? "Clearing ECU Memory..." : "Scanning Systems...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: .infinity)
                case .results:
                    if errorCodes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            Text("No diagnostic trouble codes found.")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                            Text("Vehicle system status is currently clear.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List(errorCodes, id: \.code) { dtc in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dtc.code)
                                        .font(.system(.body, design: .monospaced))
                                        .bold()
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                }
                                
                                Text(dtc.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if errorCodes.isEmpty {
                        Task { await scanVehiclesForFaults() }
                    } else {
                        showAlert = true
                    }
                }) {
                    Text(errorCodes.isEmpty ? "Scan" : "Clear")
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isBusy ? Color.gray : (errorCodes.isEmpty ? Color.blue : Color.red))
                        .foregroundColor(.white)
                        .cornerRadius(18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .disabled(obdService.connection != .ready || isBusy)
                .alert("Clear Trouble Codes?", isPresented: $showAlert) {
                    Button("Clear", role: .destructive) {
                        Task { await clearVehicleFaults() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This clears emissions adaptations and turns off the Check Engine light. Stored fault codes will be wiped permanently.")
                }
            }
            .navigationTitle("Diagnostics")
        }
    }
    
    private var isBusy: Bool {
        viewState == .scanning || viewState == .clearing
    }
    
    private func scanVehiclesForFaults() async {
        viewState = .scanning
        self.errorCodes = await fetchVehicleFaults()
        viewState = .results
    }
    
    private func clearVehicleFaults() async {
        viewState = .clearing
        _ = await obdService.sendRaw("04")
        try? await Task.sleep(for: .seconds(1.5))
        self.errorCodes = await fetchVehicleFaults()
        viewState = .results
    }
    
    private func fetchVehicleFaults() async -> [DTC] {
        let codes = await obdService.query(
            PID.diagnosticTroubleCodes,
            fallback: []
        )
        
        var tempCodes: [DTC] = []
        for code in codes {
            let description = await dtcRepository.lookup(code)
            tempCodes.append(DTC(code: code, description: description))
        }
        
        return tempCodes
    }
}
