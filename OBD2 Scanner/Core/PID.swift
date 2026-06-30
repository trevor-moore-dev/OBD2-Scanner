//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

struct OBDParameter<T> {
    let command: String
    let unit: String
    let decode: ([UInt8]) -> T
}

enum PID {
    static let engineRpm = OBDParameter<Double>(
        command: "010C",
        unit: "RPM",
        decode: { bytes in
            guard bytes.count >= 2 else {
                return 0
            }
            
            let a = Int(bytes[0])
            let b = Int(bytes[1])
            return Double((a << 8) | b) / 4.0
        }
    )
    
    static let vehicleSpeed = OBDParameter<Double>(
        command: "010D",
        unit: "MPH",
        decode: { bytes in
            bytes.isEmpty ? 0 : Double(bytes[0])
        }
    )
    
    static let coolantTemperature = OBDParameter<Double>(
        command: "0105",
        unit: "C",
        decode: { bytes in
            bytes.isEmpty ? 0 : Double(bytes[0]) - 40
        }
    )
    
    static let throttlePosition = OBDParameter<Double>(
        command: "0111",
        unit: "%",
        decode: { bytes in
            bytes.isEmpty ? 0 : (Double(bytes[0]) * 100) / 255
        }
    )
}
