//
//  OBDService.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

final class OBDService {
    private let transport: OBDTransport
    
    init(transport: OBDTransport) {
        self.transport = transport
    }
    
    func read(_ pid: PID) async -> Double {
        let raw = await transport.send(pid)
        let payload = extractPayload(raw)
        return pid.decode(payload)
    }
    
    func extractPayload(_ bytes: [UInt8]) -> [UInt8] {
        guard bytes.count > 2 else {
            return []
        }
        
        return Array(bytes.dropFirst(2))
    }
}
