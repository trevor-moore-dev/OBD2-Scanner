//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

struct PID {
    let command: String
    let decode: ([UInt8]) -> Double
}

extension PID {
    static let engineRpm = PID(
        command: "010C",
        decode: { bytes in
            guard bytes.count >= 2 else {
                return 0
            }
            
            let a = Int(bytes[0])
            let b = Int(bytes[1])
            return Double((a << 8) | b) / 4.0
        }
    )
    
    static let vehicleSpeed = PID(
        command: "010D",
        decode: { bytes in
            guard bytes.count >= 1 else {
                return 0
            }
            
            return Double(bytes[0])
        }
    )
    
    static let coolantTemperature = PID(
        command: "0105",
        decode: { bytes in
            guard bytes.count >= 1 else {
                return 0
            }
            
            return Double(bytes[0]) - 40
        }
    )
    
    static let throttlePosition = PID(
        command: "0111",
        decode: { bytes in
            guard bytes.count >= 1 else {
                return 0
            }
            
            return (Double(bytes[0]) * 100) / 255
        }
    )
}
