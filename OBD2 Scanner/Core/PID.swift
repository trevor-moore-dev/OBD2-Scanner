//
//  PID.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation

enum Mode: UInt8 {
    case showData = 0x01
    case showDTCs = 0x03
    case vehicleInfo = 0x09
    
    static func command(_ mode: Mode, _ pid: UInt8?) -> String {
        let service = String(format: "%02X", mode.rawValue)
        if let parameter = pid {
            return "\(service) \(String(format: "%02X", parameter))"
        }
        
        return service
    }
}

enum Unit: String {
    case mph = "MPH"
    case fahrenheit = "°F"
    case kpa = "kPa"
    case volts = "V"
    case gramsPerSecond = "g/s"
    case seconds = "s"
    case percent = "%"
}

enum PIDError: Error {
    case insufficientFrames(expected: Int, actual: Int, pid: UInt8?)
    case insufficientBytes(expected: Int, actual: Int, pid: UInt8?)
    case decodingError(String)
}

struct OBDParameter<T> {
    let mode: Mode
    let pid: UInt8?
    let decode: ([[UInt8]]) async throws -> Snapshot<T>
}

extension OBDParameter where T == Double {
    static let defaultFormatter: (Double) -> String = {
        String(format: "%.2f", $0)
    }
}

extension Array where Element == [UInt8] {
    func require(_ count: Int, _ pid: UInt8?) throws {
        guard self.count >= count else {
            throw PIDError.insufficientFrames(
                expected: count,
                actual: self.count,
                pid: pid
            )
        }
    }
}

extension Array where Element == UInt8 {
    func require(_ count: Int, _ pid: UInt8?) throws {
        guard self.count >= count else {
            throw PIDError.insufficientBytes(
                expected: count,
                actual: self.count,
                pid: pid
            )
        }
    }
}

enum PID {    
    static let engineRpm = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x0C,
        decode: { frames in
            try frames.require(1, 0x0C)
            try frames[0].require(4, 0x0C)
            
            let A = Int(frames[0][2])
            let B = Int(frames[0][3])
            
            let value = Double((A << 8) | B) / 4.0
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x0C),
                title: nil,
                name: "RPM",
                value: value,
                formatValue: OBDParameter.defaultFormatter,
                unit: nil
            )
        }
    )
    
    static let vehicleSpeed = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x0D,
        decode: { frames in
            try frames.require(1, 0x0D)
            try frames[0].require(3, 0x0D)
            
            let A = Double(frames[0][2])
            
            let value = A * 0.621371
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x0D),
                title: nil,
                name: "Speed",
                value: value,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.mph.rawValue
            )
        }
    )
    
    static let coolantTemperature = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x05,
        decode: { frames in
            try frames.require(1, 0x05)
            try frames[0].require(3, 0x05)
            
            let A = Double(frames[0][2])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x05),
                title: nil,
                name: "Coolant Temp",
                value: F,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.fahrenheit.rawValue
            )
        }
    )
    
    static let throttlePosition = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x11,
        decode: { frames in
            try frames.require(1, 0x11)
            try frames[0].require(3, 0x11)
            
            let A = Double(frames[0][2])
            
            let value = (A * 100) / 255
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x11),
                title: nil,
                name: "Throttle Position",
                value: value,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.percent.rawValue
            )
        }
    )
    
    static let engineLoad = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x04,
        decode: { frames in
            try frames.require(1, 0x04)
            try frames[0].require(3, 0x04)

            let A = Double(frames[0][2])

            let value = (A * 100) / 255
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x04),
                title: nil,
                name: "Engine Load",
                value: value,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.percent.rawValue
            )
        }
    )

    static let mafAirFlowRate = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x10,
        decode: { frames in
            try frames.require(1, 0x10)
            try frames[0].require(4, 0x10)
            
            let A = Int(frames[0][2])
            let B = Int(frames[0][3])
            
            let value = Double((A << 8) | B) / 100
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x10),
                title: nil,
                name: "MAF Air Flow Rate",
                value: value,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.gramsPerSecond.rawValue
            )
        }
    )
    
    static let intakeAirTemperature = OBDParameter<Double>(
        mode: Mode.showData,
        pid: 0x0F,
        decode: { frames in
            try frames.require(1, 0x0F)
            try frames[0].require(3, 0x0F)
            
            let A = Double(frames[0][2])
            let C = A - 40
            let F = (C * 1.8) + 32
            
            return Snapshot<Double>(
                id: Mode.command(.showData, 0x0F),
                title: nil,
                name: "Intake Air Temperature",
                value: F,
                formatValue: OBDParameter.defaultFormatter,
                unit: Unit.fahrenheit.rawValue
            )
        }
    )
    
    static let diagnosticTroubleCodes = OBDParameter<[String]>(
        mode: Mode.showDTCs,
        pid: nil,
        decode: { frames in
            try frames.require(1, nil)
            try frames[0].require(2, nil)
            
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
            
            return Snapshot<[String]>(
                id: Mode.command(.showDTCs, nil),
                title: nil,
                name: "Diagnostic Trouble Codes",
                value: codes,
                formatValue: { codes in
                    codes.joined(separator: ", ")
                },
                unit: nil
            )
        }
    )
    
    static let vin = OBDParameter<String>(
        mode: Mode.vehicleInfo,
        pid: 0x02,
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
            try asciiBytes.require(17, 0x02)
            if asciiBytes.count > 17 {
                asciiBytes = Array(
                    asciiBytes.dropFirst(
                        asciiBytes.count - 17
                    )
                )
            }
            
            if let vin = String(bytes: asciiBytes, encoding: .ascii), vin.count == 17 {
                let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVin/\(vin)?format=json")
                let (data, response) = try await URLSession.shared.data(from: url!)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw PIDError.decodingError("NHTSA Server Error.")
                }
                
                let json = try JSONDecoder().decode(VIN.self, from: data)
                
                var vehicleTitle = "UNKNOWN VEHICLE", year = "", make = "", model = ""
                for result in json.Results {
                    if year != "" && make != "" && model != "" {
                        vehicleTitle = "\(year) \(make) \(model)"
                        break
                    }
                    
                    if let value = result.Value {
                        switch result.Variable {
                            case "Model Year": year = value
                            case "Make": make = value
                            case "Model": model = value
                            default: break
                        }
                    }
                }
                
                return Snapshot<String>(
                    id: Mode.command(.vehicleInfo, 0x02),
                    title: vehicleTitle,
                    name: "VIN",
                    value: vin,
                    formatValue: { value in
                        value
                    },
                    unit: nil
                )
            }
            
            throw PIDError.decodingError("Failed to decode VIN.")
        }
    )
}
