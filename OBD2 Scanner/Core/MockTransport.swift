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
    
    func send(_ pid: PID) async -> [UInt8] {
        switch pid.command {
            case PID.engineRpm.command:
                return stringToBytes("41 0C 1A F8")
            case PID.vehicleSpeed.command:
                return stringToBytes("41 0D 3C")
            default:
                return []
        }
    }
    
    func stringToBytes(_ value: String) -> [UInt8] {
        value
            .split(separator: " ")
            .compactMap { UInt8($0, radix: 16) }
    }
}
