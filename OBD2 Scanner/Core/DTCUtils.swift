//
//  Untitled.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

struct DTCUtils {
    private static let dtcPrefixes: [Int: String] = [
        0: "P0",
        1: "P1",
        2: "P2",
        3: "P3",
        4: "C0",
        5: "C1",
        6: "C2",
        7: "C3",
        8: "B0",
        9: "B1",
        10: "B2",
        11: "B3",
        12: "U0",
        13: "U1",
        14: "U2",
        15: "U3"
    ]
    
    static func getPrefix(for value: Int) -> String {
        return dtcPrefixes[value] ?? "P0"
    }
}
