//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

enum PIDError: Error {
    case insufficientBytes(pid: String, expected: Int, actual: Int)
    case decodingError(String)
}

struct OBDParameter<T> {
    let command: String
    let unit: String
    let decode: ([UInt8]) throws -> T
}

enum PID {
    static let engineRpm = OBDParameter<Double>(
        command: "010C",
        unit: "RPM",
        decode: { bytes in
            guard bytes.count >= 4 else {
                throw PIDError.insufficientBytes(
                    pid: "010C",
                    expected: 2,
                    actual: bytes.count
                )
            }
            
            let A = Int(bytes[2])
            let B = Int(bytes[3])
            
            let value = (A << 8) | B
            
            return Double(value) / 4.0
        }
    )
    
    static let vehicleSpeed = OBDParameter<Double>(
        command: "010D",
        unit: "MPH",
        decode: { bytes in
            guard bytes.count >= 3 else {
                throw PIDError.insufficientBytes(
                    pid: "010D",
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[2])
            
            return A * 0.621371
        }
    )
    
    static let coolantTemperature = OBDParameter<Double>(
        command: "0105",
        unit: "C",
        decode: { bytes in
            guard bytes.count >= 3 else {
                throw PIDError.insufficientBytes(
                    pid: "0105",
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[2])
            
            return A - 40
        }
    )
    
    static let throttlePosition = OBDParameter<Double>(
        command: "0111",
        unit: "%",
        decode: { bytes in
            guard bytes.count >= 3 else {
                throw PIDError.insufficientBytes(
                    pid: "0111",
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[2])
            
            return (A * 100) / 255
        }
    )
}
