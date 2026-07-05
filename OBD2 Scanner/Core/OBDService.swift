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
    
    func connect() async throws {
        try await transport.connect()
    }
    
    func disconnect() {
        transport.disconnect()
    }
    
    func read<T>(_ pid: OBDParameter<T>) async -> T {
        let response = await transport.send(pid)
        return pid.decode(response)
    }
    
    func readSnapshot() async -> Snapshot {
        async let rpm = read(PID.engineRpm)
        async let speed = read(PID.vehicleSpeed)
        async let coolantTemp = read(PID.coolantTemperature)
        async let throttlePosition = read(PID.throttlePosition)
        
        return await Snapshot(
            rpm: rpm,
            speed: speed,
            coolantTemp: coolantTemp,
            throttlePosition: throttlePosition
        )
    }
    
    func snapshotStream() -> AsyncStream<Snapshot> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let snapshot = await readSnapshot()
                    continuation.yield(snapshot)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
