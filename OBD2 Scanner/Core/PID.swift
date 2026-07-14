//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation

enum PIDError: Error {
    case insufficientBytes(mode: UInt8, pid: UInt8?, expected: Int, actual: Int)
    case decodingError(String)
}

struct OBDParameter<T> {
    let mode: UInt8
    let pid: UInt8?
    
    let unit: String?
    let label: String
    
    let decode: ([UInt8]) throws -> T
    let format: (T) -> String
    
    func command() -> String {
        let service = String(format: "%02X", mode)
        if let parameter = pid {
            return "\(service) \(String(format: "%02X", parameter))"
        }
        
        return service
    }
}

enum PID {
    static let engineRpm = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0C,
        unit: nil,
        label: "RPM",
        decode: { bytes in
            guard bytes.count >= 2 else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x0C,
                    expected: 2,
                    actual: bytes.count
                )
            }
            
            let A = Int(bytes[0])
            let B = Int(bytes[1])
            
            let value = (A << 8) | B
            
            return Double(value) / 4.0
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let vehicleSpeed = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0D,
        unit: "MPH",
        label: "Speed",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x0D,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            
            return A * 0.621371
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let coolantTemperature = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x05,
        unit: "F",
        label: "Coolant Temp",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x05,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return F
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let throttlePosition = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x11,
        unit: "%",
        label: "Throttle Position",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x11,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            
            return (A * 100) / 255
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let fuelPressure = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0A,
        unit: "kPa",
        label: "Fuel Pressure",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x0A,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            
            return 3 * A
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let intakeManifoldPressure = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0B,
        unit: "kPa",
        label: "Intake Manifold Pressure",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x0B,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            
            return A
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let intakeAirPressure = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0F,
        unit: "F",
        label: "Intake Air Pressure",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x01,
                    pid: 0x0F,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            let A = Double(bytes[0])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return F
        },
        format: { value in
            return String(format: "%.2f", value)
        }
    )
    
    static let diagnosticTroubleCodes = OBDParameter<[String]>(
        mode: 0x03,
        pid: nil,
        unit: nil,
        label: "Diagnostic Trouble Codes",
        decode: { bytes in
            guard !bytes.isEmpty else {
                throw PIDError.insufficientBytes(
                    mode: 0x03,
                    pid: nil,
                    expected: 1,
                    actual: bytes.count
                )
            }
            
            var codes: [String] = []
            
            for i in stride(from: 0, to: bytes.count - 1, by: 2) {
                let firstByte = bytes[i]
                let secondByte = bytes[i + 1]
                
                guard firstByte != 0x00 || secondByte != 0x00 else {
                    continue
                }
                
                let firstDigit = Int(firstByte >> 4) // shift left 4 bits to keep the original left nibble
                let secondDigit = Int(firstByte & 0x0F) // bitwise AND to keep the original right nibble
                let prefix = DTCUtils.getPrefix(for: firstDigit)
                let suffix = String(format: "%02X", secondByte)
                
                codes.append("\(prefix)\(secondDigit)\(suffix)")
            }
            
            return codes
        },
        format: { codes in
            return codes.joined(separator: ", ")
        }
    )
    
    static let vin = OBDParameter<String>(
        mode: 0x09,
        pid: 0x02,
        unit: nil,
        label: "VIN",
        decode: { bytes in
            
            // 01 00 00 00 31
            // 02 44 34 47 50
            // 03 30 30 52 35
            // 04 35 42 31 32
            // 05 33 34 35 36
            
            guard bytes.count == 25 else {
                throw PIDError.insufficientBytes(
                    mode: 0x09,
                    pid: 0x02,
                    expected: 25,
                    actual: bytes.count
                )
            }
            
            var asciiBytes: [UInt8] = []
            
            for i in stride(from: 4, to: bytes.count, by: 1) {
                guard i % 5 != 0 else {
                    continue
                }
                
                asciiBytes.append(bytes[i])
            }
            
            if let vin = String(bytes: asciiBytes, encoding: .ascii) {
                return vin
            }
            
            throw PIDError.decodingError("Failed to decode VIN.")
        },
        format: { value in
            return value
        }
    )
}
