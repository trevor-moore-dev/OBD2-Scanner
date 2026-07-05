//
//  DashboardViewModel.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation
internal import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    
    @Published var snapshot: Snapshot?
    
    private var streamTask: Task<Void, Never>?
    private let obdService: OBDService
    
    init(obdService: OBDService) {
        self.obdService = obdService
    }
    
    func connect() async throws {
        try await obdService.connect()
    }
    
    func disconnect() {
        obdService.disconnect()
    }
    
    func start() {
        streamTask = Task {
            for await snapshot in obdService.snapshotStream() {
                self.snapshot = snapshot
            }
        }
    }
    
    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }
}
