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

enum OBDError: Error {
    case queryError(String)
    case networkError(String)
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
        
        _ = try await transport.sendRaw("ATS0") // spaces off (0 off 1 on)
        try await Task.sleep(for: .milliseconds(100))
        
        _ = try await transport.sendRaw("ATH0") // headers off (0 off 1 on)
        try await Task.sleep(for: .milliseconds(100))
        
        _ = try await transport.sendRaw("ATSP0") // auto detect protocol
        try await Task.sleep(for: .milliseconds(100))
    }
    
    private func snapshotsStream() -> AsyncStream<[any AnySnapshot]> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else { return }
                let staticSnapshots = await self.staticSnapshots()
                
                while !Task.isCancelled {
                    let dynamicSnapshots = await self.dynamicSnapshots()
                    continuation.yield(staticSnapshots + dynamicSnapshots)
                    
                    do {
                        try await Task.sleep(for: .milliseconds(1500))
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
    
    private func staticSnapshots() async -> [any AnySnapshot] {
        do {
            let vin = await query(PID.vin, fallback: "")
            guard vin.count == 17 else {
                throw OBDError.queryError("Failed to determine VIN.")
            }
            
            let url = URL(string: "https://vpic.nhtsa.dot.gov/api//vehicles/DecodeVin/\(vin)?format=json")
            let (data, response) = try await URLSession.shared.data(from: url!)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw OBDError.networkError("NHTSA Server Error.")
            }
            
            let json = try JSONDecoder().decode(VIN.self, from: data)
            
            var vehicleTitle = "", year = "", make = "", model = ""
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
            
            if vehicleTitle != "" {
                return [
                    Snapshot<String>(
                        id: PID.vin.command(),
                        title: vehicleTitle,
                        name: PID.vin.label,
                        value: vin,
                        formatValue: PID.vin.format,
                        unit: PID.vin.unit
                    )
                ]
            }
        } catch {
            print(error)
        }
        
        return []
    }
    
    private func dynamicSnapshots() async -> [any AnySnapshot] {
        let rpm = await query(PID.engineRpm, fallback: 0)
        let speed = await query(PID.vehicleSpeed, fallback: 0)
        let coolantTemp = await query(PID.coolantTemperature, fallback: 0)
        let throttlePosition = await query(PID.throttlePosition, fallback: 0)
        let fuelPressure = await query(PID.fuelPressure, fallback: 0)
        let intakeManifoldPressure = await query(PID.intakeManifoldPressure, fallback: 0)
        let intakeAirPressure = await query(PID.intakeAirPressure, fallback: 0)
        
        return [
            Snapshot<Double>(
                id: PID.engineRpm.command(),
                title: nil,
                name: PID.engineRpm.label,
                value: rpm,
                formatValue: PID.engineRpm.format,
                unit: PID.engineRpm.unit
            ),
            Snapshot<Double>(
                id: PID.vehicleSpeed.command(),
                title: nil,
                name: PID.vehicleSpeed.label,
                value: speed,
                formatValue: PID.vehicleSpeed.format,
                unit: PID.vehicleSpeed.unit
            ),
            Snapshot<Double>(
                id: PID.coolantTemperature.command(),
                title: nil,
                name: PID.coolantTemperature.label,
                value: coolantTemp,
                formatValue: PID.coolantTemperature.format,
                unit: PID.coolantTemperature.unit
            ),
            Snapshot<Double>(
                id: PID.throttlePosition.command(),
                title: nil,
                name: PID.throttlePosition.label,
                value: throttlePosition,
                formatValue: PID.throttlePosition.format,
                unit: PID.throttlePosition.unit
            ),
            Snapshot<Double>(
                id: PID.fuelPressure.command(),
                title: nil,
                name: PID.fuelPressure.label,
                value: fuelPressure,
                formatValue: PID.fuelPressure.format,
                unit: PID.fuelPressure.unit
            ),
            Snapshot<Double>(
                id: PID.intakeManifoldPressure.command(),
                title: nil,
                name: PID.intakeManifoldPressure.label,
                value: intakeManifoldPressure,
                formatValue: PID.intakeManifoldPressure.format,
                unit: PID.intakeManifoldPressure.unit
            ),
            Snapshot<Double>(
                id: PID.intakeAirPressure.command(),
                title: nil,
                name: PID.intakeAirPressure.label,
                value: intakeAirPressure,
                formatValue: PID.intakeAirPressure.format,
                unit: PID.intakeAirPressure.unit
            ),
        ]
    }
}
