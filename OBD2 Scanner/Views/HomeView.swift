//
//  HomeView.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import SwiftUI

struct HomeView: View {
    
    @ObservedObject private var obdService: OBDService
    
    init(obdService: OBDService) {
        _obdService = ObservedObject(wrappedValue: obdService)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if !obdService.snapshots.isEmpty {
                    List(obdService.snapshots, id: \.id) { snapshot in
                        VStack(alignment: .leading, spacing: 4) {
                            if let title = snapshot.title {
                                Text(title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text(snapshot.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.top, 2)
                                
                                Text(snapshot.getValue())
                                    .font(.system(.body, design: .monospaced))
                                    .bold()
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Spacer()
                            }
                            
                            Text(snapshot.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                } else if obdService.isStreaming {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Waiting for scan responses...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("Connected to Bluetooth OBD-II Adapter!")
                            .font(.headline)
                        Text("Begin scanning when ready.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
                
                Button(action: {
                    obdService.isStreaming ? obdService.stopStream() : obdService.startStream()
                }) {
                    Text(obdService.isStreaming ? "Stop" : "Scan")
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(obdService.isStreaming ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .disabled(obdService.connection != .ready)
            }
            .navigationTitle("Home")
        }
    }
}
