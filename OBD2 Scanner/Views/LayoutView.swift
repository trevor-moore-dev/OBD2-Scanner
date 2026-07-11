//
//  LayoutView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import SwiftUI

enum Tab {
    case home, terminal
}

struct LayoutView: View {
    
    @State private var tab: Tab = .home
    @ObservedObject private var obdService: OBDService
    
    init(obdService: OBDService) {
        _obdService = ObservedObject(wrappedValue: obdService)
    }
    
    var body: some View {
        TabView(selection: $tab) {
            HomeView(obdService: obdService)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            
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
            case .home: _ = await obdService.sendRaw("ATS0")
            case .terminal: _ = await obdService.sendRaw("ATS1")
        }
    }
}
