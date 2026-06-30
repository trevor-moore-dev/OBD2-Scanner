//
//  Snapshot.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation

struct Snapshot {
    let rpm: Double
    let speed: Double
    let coolantTemp: Double
    let throttlePosition: Double
    let timestamp: Date = Date()
}
