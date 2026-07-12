//
//  Untitled.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI

struct DiagnosticsView: View {
    
    @ObservedObject private var dtcService: DTCService
    
    @State private var errorCodes: [DTC] = []
    @State private var isScanning: Bool = false
    
    init(dtcService: DTCService) {
        _dtcService = ObservedObject(wrappedValue: dtcService)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isScanning {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for diagnostic trouble codes...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if errorCodes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("No diagnostic trouble codes found.")
                            .font(.headline)
                        Text("Vehicle system status is currently clear.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                
                Button(action: {
                    Task {
                        await runDiagnosticsScan()
                    }
                }) {
                    Text(isScanning ? "Scanning..." : "Scan")
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isScanning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .disabled(isScanning)
            }
            .navigationTitle("Diagnostics")
        }
    }
    
    private func runDiagnosticsScan() async {
        isScanning = true
        errorCodes = await dtcService.readDiagnosticTroubleCodes()
        isScanning = false
    }
}
