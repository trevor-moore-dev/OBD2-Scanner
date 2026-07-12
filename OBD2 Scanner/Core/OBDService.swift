//
//  OBDService.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation
internal import Combine

enum OBDConnection {
    case unknown
    case connecting
    case ready
    case failed
}

@MainActor
final class OBDService: ObservableObject {
    
    @Published private(set) var connection: OBDConnection = .unknown
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var snapshots: [any AnySnapshot] = []
    
    private var streamTask: Task<Void, Never>?
    private let transport: OBDTransport
    
    init(transport: OBDTransport) {
        self.transport = transport
    }
    
    func connect() async {
        guard connection == .unknown || connection == .failed else {
            return
        }
        
        connection = .connecting
        
        do {
            try await connectWithRetry(maxAttempts: 3)
            try await initialize()
            
            connection = .ready
        } catch {
            print(error)
            transport.disconnect()
            connection = .failed
        }
    }
    
    func disconnect() {
        defer {
            snapshots = []
            connection = .unknown
        }
        
        stopStream()
        transport.disconnect()
    }
    
    func startStream() {
        guard
            !isStreaming &&
            connection == .ready &&
            streamTask == nil
        else {
            return
        }
        
        isStreaming = true
        streamTask = Task {
            defer {
                streamTask = nil
                isStreaming = false
            }
            
            for await snapshots in self.snapshotsStream() {
                self.snapshots = snapshots
            }
        }
    }
    
    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
    
    func query<T>(_ pid: OBDParameter<T>, fallback: T) async -> T {
        guard connection == .ready else {
            return fallback
        }
        
        do {
            return try await transport.query(pid)
        } catch {
            print(error)
        }
        
        return fallback
    }
    
    func sendRaw(_ command: String) async -> String {
        guard connection == .ready else {
            return "Connection is \(connection)..."
        }
        
        do {
            let bytes = try await transport.sendRaw(command)
            return String(bytes: bytes, encoding: .ascii)!
        } catch {
            print(error)
            return error.localizedDescription
        }
    }
    
    private func connectWithRetry(maxAttempts: Int) async throws {
        var remaining = maxAttempts
        
        while remaining > 0 {
            do {
                try await transport.connect()
                return
            } catch {
                remaining -= 1
                
                if remaining == 0 {
                    throw error
                }
                
                try await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func initialize() async throws {
        // find elm327 spec here:
        // https://www.elmelectronics.com/wp-content/uploads/2017/01/ELM327DS.pdf
        
        _ = try await transport.sendRaw("ATZ") // reset all
        try await Task.sleep(for: .seconds(2))
        
        _ = try await transport.sendRaw("ATE0") // echo off (0 off 1 on)
        try await Task.sleep(for: .milliseconds(100))
        
        _ = try await transport.sendRaw("ATL0") // linefeeds off (0 off 1 on)
        try await Task.sleep(for: .milliseconds(100))
    }
    
    private func snapshotsStream() -> AsyncStream<[any AnySnapshot]> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    
                    let snapshots = await self.readSnapshots()
                    continuation.yield(snapshots)
                    
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        break
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private func readSnapshots() async -> [any AnySnapshot] {
        let rpm = await query(PID.engineRpm, fallback: 0)
        let speed = await query(PID.vehicleSpeed, fallback: 0)
        let coolantTemp = await query(PID.coolantTemperature, fallback: 0)
        let throttlePosition = await query(PID.throttlePosition, fallback: 0)
        
        return [
            Snapshot<Double>(
                id: PID.engineRpm.command,
                name: PID.engineRpm.label,
                value: rpm,
                formatValue: PID.engineRpm.format,
                unit: nil
            ),
            Snapshot<Double>(
                id: PID.vehicleSpeed.command,
                name: PID.vehicleSpeed.label,
                value: speed,
                formatValue: PID.vehicleSpeed.format,
                unit: PID.vehicleSpeed.unit
            ),
            Snapshot<Double>(
                id: PID.coolantTemperature.command,
                name: PID.coolantTemperature.label,
                value: coolantTemp,
                formatValue: PID.coolantTemperature.format,
                unit: PID.coolantTemperature.unit
            ),
            Snapshot<Double>(
                id: PID.throttlePosition.command,
                name: PID.throttlePosition.label,
                value: throttlePosition,
                formatValue: PID.throttlePosition.format,
                unit: PID.throttlePosition.unit
            ),
        ]
    }
}
