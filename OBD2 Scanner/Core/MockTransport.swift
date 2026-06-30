//
//  MockTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

final class MockTransport: OBDTransport {
    func disconnect() {
        
    }
    
    func connect() async throws {
        
    }
    
    func send<T>(_ pid: OBDParameter<T>) async -> [UInt8] {
        switch pid.command {
            case PID.engineRpm.command:
                return extractPayload("41 0C 1A F8")
            case PID.vehicleSpeed.command:
                return extractPayload("41 0D 3C")
            case PID.coolantTemperature.command:
                return extractPayload("41 05 5A")
            case PID.throttlePosition.command:
                return extractPayload("41 11 3C")
            default:
                return []
        }
    }
    
    private func extractPayload(_ value: String) -> [UInt8] {
        let bytes = value
            .split(separator: " ")
            .compactMap { UInt8($0, radix: 16) }
        
        guard bytes.count > 2 else {
            return []
        }
        
        return Array(bytes.dropFirst(2))
    }
}
