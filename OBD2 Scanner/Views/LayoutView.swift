//
//  LayoutView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI

enum Tab {
    case home
    case diagnostics
    case terminal
}

struct LayoutView: View {
    
    @ObservedObject private var obdService: OBDService
    
    @State private var tab: Tab = .home
    
    private var dtcRepository: DTCRepository
    
    init(obdService: OBDService, dtcRepository: DTCRepository) {
        _obdService = ObservedObject(wrappedValue: obdService)
        self.dtcRepository = dtcRepository
    }
    
    var body: some View {
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
    }
    
    private func handleTabTap(for tab: Tab) async {
        guard !Task.isCancelled else { return }
        switch tab {
            case .terminal: _ = await obdService.sendRaw("ATS1")
            default: _ = await obdService.sendRaw("ATS0")
        }
    }
}
