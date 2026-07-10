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
    @Published private(set) var snapshot: Snapshot?
    
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
            snapshot = nil
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
            
            for await snapshot in self.snapshotStream() {
                self.snapshot = snapshot
            }
        }
    }
    
    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
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
        
        _ = try await transport.sendRaw("ATS0") // spaces off (0 off 1 on)
        try await Task.sleep(for: .milliseconds(100))
    }
    
    private func snapshotStream() -> AsyncStream<Snapshot> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    
                    let snapshot = await self.readSnapshot()
                    continuation.yield(snapshot)
                    
                    do {
                        try await Task.sleep(for: .milliseconds(500))
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
    
    private func readSnapshot() async -> Snapshot {
        let rpm = await read(PID.engineRpm, fallback: 0)
        let speed = await read(PID.vehicleSpeed, fallback: 0)
        let coolantTemp = await read(PID.coolantTemperature, fallback: 0)
        let throttlePosition = await read(PID.throttlePosition, fallback: 0)
        
        return Snapshot(
            rpm: rpm,
            speed: speed,
            coolantTemp: coolantTemp,
            throttlePosition: throttlePosition
        )
    }
    
    func read<T>(_ pid: OBDParameter<T>, fallback: T) async -> T {
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
}
