//
//  Snapshot.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation

protocol AnySnapshot {
    var id: String { get }
    var title: String? { get }
    var name: String { get }
    var unit: String? { get }
    var timestamp: Date { get }
    func getValue() -> String
}

struct Snapshot<T>: AnySnapshot {
    let id: String
    let title: String?
    let name: String
    let value: T
    let formatValue: (T) -> String
    let unit: String?
    let timestamp: Date = Date()
    
    func getValue() -> String {
        let formattedValue = formatValue(value)
        if let safeUnit = unit {
            return "\(formattedValue) \(safeUnit)"
        }
        
        return "\(formattedValue)"
    }
}
