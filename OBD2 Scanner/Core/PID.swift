//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation

enum Unit: String {
    case mph = "MPH"
    case fahrenheit = "°F"
    case kpa = "kPa"
    case percent = "%"
}

enum PIDError: Error {
    case insufficientFrames(expected: Int, actual: Int)
    case insufficientBytes(expected: Int, actual: Int)
    case decodingError(String)
}

struct OBDParameter<T> {
    let mode: UInt8
    let pid: UInt8?
    
    let unit: Unit?
    let label: String
    
    let decode: ([[UInt8]]) throws -> T
    let format: (T) -> String
    
    func command() -> String {
        let service = String(format: "%02X", mode)
        if let parameter = pid {
            return "\(service) \(String(format: "%02X", parameter))"
        }
        
        return service
    }
}

extension OBDParameter where T == Double {
    static let defaultFormatter: (Double) -> String = {
        String(format: "%.2f", $0)
    }
}

extension Array where Element == [UInt8] {
    func require(_ count: Int) throws {
        guard self.count >= count else {
            throw PIDError.insufficientFrames(
                expected: count,
                actual: self.count
            )
        }
    }
}

extension Array where Element == UInt8 {
    func require(_ count: Int) throws {
        guard self.count >= count else {
            throw PIDError.insufficientBytes(
                expected: count,
                actual: self.count
            )
        }
    }
}

enum PID {
    static let engineRpm = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0C,
        unit: nil,
        label: "RPM",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(4)
            
            let A = Int(frames[0][2])
            let B = Int(frames[0][3])
            
            let value = (A << 8) | B
            
            return Double(value) / 4.0
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let vehicleSpeed = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0D,
        unit: Unit.mph,
        label: "Speed",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            
            return A * 0.621371
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let coolantTemperature = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x05,
        unit: Unit.fahrenheit,
        label: "Coolant Temp",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return F
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let throttlePosition = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x11,
        unit: Unit.percent,
        label: "Throttle Position",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            
            return (A * 100) / 255
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let fuelPressure = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0A,
        unit: Unit.kpa,
        label: "Fuel Pressure",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            
            return 3 * A
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let intakeManifoldPressure = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0B,
        unit: Unit.kpa,
        label: "Intake Manifold Pressure",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            
            return A
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let intakeAirTemperature = OBDParameter<Double>(
        mode: 0x01,
        pid: 0x0F,
        unit: Unit.fahrenheit,
        label: "Intake Air Temperature",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(3)
            
            let A = Double(frames[0][2])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return F
        },
        format: OBDParameter.defaultFormatter
    )
    
    static let diagnosticTroubleCodes = OBDParameter<[String]>(
        mode: 0x03,
        pid: nil,
        unit: nil,
        label: "Diagnostic Trouble Codes",
        decode: { frames in
            try frames.require(1)
            try frames[0].require(2)
            
            var codes: [String] = []
            
            for i in stride(from: 1, to: frames[0].count - 1, by: 2) {
                let firstByte = frames[0][i]
                let secondByte = frames[0][i + 1]
                
                guard firstByte != 0x00 || secondByte != 0x00 else {
                    continue
                }
                
                let firstDigit = Int(firstByte >> 4) // extract high nibble
                let secondDigit = Int(firstByte & 0x0F) // extract low nibble
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
        decode: { frames in
            
            // 49 02 01 35 54 44
            // 4B 4B 33 44 43 36 46
            // 53 35 34 35 33 31 33

            // 49 02 01 00 00 00 31
            // 49 02 02 44 34 47 50
            // 49 02 03 30 30 52 35
            // 49 02 04 35 42 31 32
            // 49 02 05 33 34 35 36
            
            var asciiBytes: [UInt8] = []
            
            for i in frames.indices {
                // skip the header bytes
                // multi-frame CAN VIN responses include a 1-based frame index
                var start = 0
                if
                    frames[i].count >= 3 &&
                    frames[i][0] == 0x49 &&
                    frames[i][1] == 0x02 &&
                    frames[i][2] == i + 1
                {
                    start = 3
                }
                
                for j in start..<frames[i].count {
                    asciiBytes.append(frames[i][j])
                }
            }
            
            // discard leading CAN padding bytes (00 00 00 ...), and keep the last 17 VIN chars
            try asciiBytes.require(17)
            if asciiBytes.count > 17 {
                asciiBytes = Array(
                    asciiBytes.dropFirst(
                        asciiBytes.count - 17
                    )
                )
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
