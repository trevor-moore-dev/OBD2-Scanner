//
//  OBDService.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import Foundation
import CoreBluetooth
internal import Combine

enum OBDConnection {
    case unknown
    case scanning
    case connecting
    case ready
    case failed
}

enum OBDError: Error {
    case queryError(String)
}

@MainActor
final class OBDService: ObservableObject {
    
    @Published private(set) var connection: OBDConnection = .unknown
    @Published private(set) var devices: [CBPeripheral] = []
    @Published private(set) var connectedDevice: CBPeripheral?
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var snapshots: [any AnySnapshot] = []
    
    private var streamTask: Task<Void, Never>?
    private var transport: OBDTransport
    
    init(transport: OBDTransport) {
        self.transport = transport
        self.transport.onPeripheralsUpdated = { [weak self] peripherals in
            self?.devices = peripherals
        }
    }
    
    func startScan() async {
        guard connection == .unknown || connection == .failed else {
            return
        }
        
        connection = .scanning
        
        do {
            try await transport.startScan()
        } catch {
            print(error)
            transport.stopScan()
            connection = .unknown
        }
    }
    
    func stopScan() {
        transport.stopScan()
        connection = .unknown
    }
    
    func connect(_ peripheral: CBPeripheral) async {
        guard connection == .scanning else {
            return
        }
        
        connection = .connecting
        
        do {
            try await connectWithRetry(peripheral, maxAttempts: 3)
            try await initialize()
            
            connectedDevice = peripheral
            connection = .ready
        } catch {
            print(error)
            transport.disconnect()
            connectedDevice = nil
            connection = .failed
        }
    }
    
    func disconnect() {
        defer {
            snapshots = []
            connectedDevice = nil
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
    
    func query<T>(_ pid: OBDParameter<T>) async throws -> Snapshot<T> {
        guard connection == .ready else {
            throw OBDError.queryError("Connection is \(connection)...")
        }
        
        do {
            return try await transport.query(pid)
        } catch {
            print(error)
        }
        
        throw OBDError.queryError("Failed to query \(Mode.command(pid.mode, pid.pid))")
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
    
    private func connectWithRetry(_ peripheral: CBPeripheral, maxAttempts: Int) async throws {
        var remaining = maxAttempts
        
        while remaining > 0 {
            do {
                try await transport.connect(peripheral)
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
        _ = try await transport.sendRaw("ATE0") // echo off (0 off 1 on)
        _ = try await transport.sendRaw("ATL0") // linefeeds off (0 off 1 on)
        _ = try await transport.sendRaw("ATS0") // spaces off (0 off 1 on)
        _ = try await transport.sendRaw("ATH0") // headers off (0 off 1 on)
        _ = try await transport.sendRaw("ATSP0") // auto detect protocol
        _ = try await transport.sendRaw("0100") // fire and forget first PID
    }
    
    private func snapshotsStream() -> AsyncStream<[any AnySnapshot]> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else { return }
                let staticSnapshots = await self.staticSnapshots()
                
                while !Task.isCancelled {
                    let dynamicSnapshots = await self.dynamicSnapshots()
                    continuation.yield(staticSnapshots + dynamicSnapshots)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private func staticSnapshots() async -> [any AnySnapshot] {
        do {
            return [try await transport.query(PID.vin)]
        } catch {
            print(error)
        }
        
        return []
    }
    
    private func dynamicSnapshots() async -> [any AnySnapshot] {
        var snapshots: [any AnySnapshot] = []
        let parameters = [
            PID.engineRpm,
            PID.vehicleSpeed,
            PID.coolantTemperature,
            PID.throttlePosition,
            PID.engineLoad,
            PID.mafAirFlowRate,
            PID.intakeAirTemperature,
        ]
        
        for parameter in parameters {
            do {
                snapshots.append(
                    try await transport.query(parameter)
                )
            } catch {
                print(error)
            }
        }
        
        return snapshots
    }
}
