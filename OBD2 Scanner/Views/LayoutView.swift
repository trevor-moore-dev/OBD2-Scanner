//
//  LayoutView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI
import CoreBluetooth

enum Tab {
    case home
    case diagnostics
    case terminal
}

struct LayoutView: View {
    
    @ObservedObject private var obdService: OBDService
    
    @State private var tab: Tab = .home
    @State private var renderDeviceMenu: Bool = false
    
    private var dtcRepository: DTCRepository
    
    init(obdService: OBDService, dtcRepository: DTCRepository) {
        _obdService = ObservedObject(wrappedValue: obdService)
        self.dtcRepository = dtcRepository
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                HomeView(obdService: obdService)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(Tab.home)
                
                DiagnosticsView(
                    obdService: obdService,
                    dtcRepository: dtcRepository
                )
                .tabItem {
                    Label("Diagnostics", systemImage: "engine.combustion")
                }
                .tag(Tab.diagnostics)
                
                TerminalView(obdService: obdService)
                    .tabItem {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .tag(Tab.terminal)
            }
            .task {
                await handleTabTap(for: tab)
            }
            .onChange(of: tab) { old, new in
                guard old != new else { return }
                Task {
                    await handleTabTap(for: new)
                }
            }
            
            HStack {
                Circle()
                    .fill(obdService.connection == .ready
                          ? Color.blue
                          : ([OBDConnection.scanning, OBDConnection.connecting].contains(obdService.connection) ? Color.orange : Color.red)
                    )
                    .frame(width: 10, height: 10)
                
                Text(obdService.connection == .ready
                     ? "Connected: \(obdService.connectedDevice?.name ?? "ELM327")"
                     : (obdService.connection == .scanning
                        ? "Scanning..."
                        : (obdService.connection == .connecting
                           ? "Connecting..."
                           : "Disconnected"))
                )
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if obdService.connection == .ready {
                    Button(action: {
                        obdService.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(6)
                    }
                } else {
                    Button(action: {
                        renderDeviceMenu = true
                        Task {
                            await obdService.startScan()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if [OBDConnection.scanning, OBDConnection.connecting].contains(obdService.connection) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                                    .frame(width: 15, height: 15)
                            }
                            Text(obdService.connection == .scanning
                                 ? "Scanning"
                                 : (obdService.connection == .connecting
                                    ? "Connecting"
                                    : "Connect"))
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background([OBDConnection.scanning, OBDConnection.connecting].contains(obdService.connection) ? Color.orange : Color.blue)
                        .cornerRadius(6)
                    }
                    .disabled([OBDConnection.scanning, OBDConnection.connecting].contains(obdService.connection))
                    .sheet(isPresented: $renderDeviceMenu, onDismiss: {
                        if obdService.connection == .scanning {
                            obdService.stopScan()
                        }
                    }) {
                        NavigationStack {
                            List {
                                Section {
                                    Text("Make sure your vehicle ignition is set to ON or ACC.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if obdService.devices.isEmpty {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                        Text("Searching for adapters...")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                } else {
                                    ForEach(obdService.devices, id: \.identifier) { peripheral in
                                        Button(action: {
                                            renderDeviceMenu = false
                                            Task {
                                                await obdService.connect(peripheral)
                                            }
                                        }) {
                                            HStack {
                                                Label(peripheral.name ?? "Unknown", systemImage: "cable.connector")
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Select Device")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        renderDeviceMenu = false
                                        obdService.stopScan()
                                    }
                                }
                            }
                        }
                        // Gives it a native bottom-drawer look on iOS
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            .border(Color(.separator), width: 0.5)
        }
    }
    
    private func handleTabTap(for tab: Tab) async {
        guard !Task.isCancelled else { return }
        switch tab {
            case .terminal: _ = await obdService.sendRaw("ATS1")
            default: _ = await obdService.sendRaw("ATS0")
        }
    }
}
