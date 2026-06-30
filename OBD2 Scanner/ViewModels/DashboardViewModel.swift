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
    @Published private(set) var isScanning: Bool = false
    
    private var streamTask: Task<Void, Never>?
    private let obdService: OBDService
    
    init(obdService: OBDService) {
        self.obdService = obdService
    }
    
    func start() {
        guard !isScanning else {
            return
        }
        
        isScanning = true
        streamTask = Task {
            for await snapshot in obdService.snapshotStream() {
                self.snapshot = snapshot
            }
            
            isScanning = false
        }
    }
    
    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isScanning = false
    }
}
