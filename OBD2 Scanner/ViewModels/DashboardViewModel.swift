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
    
    @Published var rpm: Double = 0
    
    private let obdService: OBDService
    
    init(obdService: OBDService) {
        self.obdService = obdService
    }
    
    func refresh() async {
        rpm = await obdService.read(.engineRpm)
    }
}
