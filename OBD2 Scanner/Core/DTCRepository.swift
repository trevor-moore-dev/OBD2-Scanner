//
//  Untitled.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import Foundation

struct DTC: Codable {
    let code: String
    let description: String
}

actor DTCRepository {
    
    private var codeMappings: [String: String] = [:]
    
    init() {
        self.codeMappings = Self.loadMappings()
    }
    
    func lookup(_ code: String) -> String {
        return codeMappings[code.uppercased()] ?? "Unknown Diagnostic Trouble Code"
    }
    
    private static func loadMappings() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "dtcs", withExtension: "json") else {
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let dictionary = try decoder.decode([String: String].self, from: data)
            
            return Dictionary(
                uniqueKeysWithValues: dictionary.map {
                    ($0.key.uppercased(), $0.value)
                }
            )
        } catch {
            print(error.localizedDescription)
            return [:]
        }
    }
}
