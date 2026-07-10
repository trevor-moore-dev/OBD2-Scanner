//
//  BluetoothTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/4/26.
//

import Synchronization
import CoreBluetooth

enum BluetoothError: Error {
    case connectionFailed
    case connectionTimeout
    case bluetoothUnavailable
    case sessionTimeout
    case sessionError(String)
}

enum ConnectionState {
    case idle
    case scanning
    case connecting
    case discovering
    case ready
}

final class BluetoothTransport:
    NSObject,
    CBCentralManagerDelegate,
    CBPeripheralDelegate,
    OBDTransport
{
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var connectTask: Task<Void, Error>?
    
    private var session: BluetoothSession?
    private let sessionLock = Mutex<Void>(())
    
    private(set) var state: ConnectionState = .idle
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOn, .resetting, .unknown, .unsupported, .unauthorized:
                print("Bluetooth \(central.state.rawValue)")
            case .poweredOff:
                print("Bluetooth off")
            
                finishConnect(.failure(BluetoothError.connectionFailed))
                
                self.peripheral = nil
                writeCharacteristic = nil
                notifyCharacteristic = nil
            
                setState(.idle)
            
                centralManager.stopScan()
            default:
                break
        }
    }
    
    func connect() async throws {
        if let task = connectTask {
            return try await task.value
        }
        
        let task = Task<Void, Error> {
            try await waitForBluetoothPower()
            try await startScanAndConnect()
        }
        
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60 seconds
            guard connectContinuation != nil else { return }
            centralManager.stopScan()
            if peripheral != nil {
                centralManager.cancelPeripheralConnection(peripheral!)
            }

            finishConnect(.failure(BluetoothError.connectionTimeout))
            task.cancel()
        }
        
        connectTask = task
        
        do {
            try await task.value
            timeout.cancel()
        } catch {
            connectTask = nil
            throw error
        }
        
        connectTask = nil
    }
    
    func waitForBluetoothPower() async throws {
        if centralManager.state == .poweredOn { return }
        while centralManager.state != .poweredOn {
            if centralManager.state == .poweredOff ||
                centralManager.state == .unauthorized ||
                centralManager.state == .unsupported {
                throw BluetoothError.bluetoothUnavailable
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
    
    func startScanAndConnect() async throws {
        try await withCheckedThrowingContinuation { continuation in
            connectContinuation = continuation
            centralManager.scanForPeripherals(
                withServices: nil,
                options: nil
            )
            
            setState(.scanning)
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        guard peripheral.name == "VEEPEAK" else {
            return
        }
        
        print("Connecting to \(peripheral.name!)")
        
        self.peripheral = peripheral
        peripheral.delegate = self
        
        central.stopScan()
        central.connect(peripheral)
        
        setState(.connecting)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        
        setState(.idle)
        finishConnect(.failure(error ?? BluetoothError.connectionFailed))
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        setState(.discovering)
        peripheral.discoverServices(nil)
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard error == nil else {
            finishConnect(.failure(error!))
            setState(.idle)
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            finishConnect(.failure(error!))
            setState(.idle)
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            switch characteristic.uuid.uuidString.uppercased() {
                case "FFF2":
                    writeCharacteristic = characteristic
                case "FFF1":
                    notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    break
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.isNotifying else {
            finishConnect(.failure(error ?? BluetoothError.connectionFailed))
            setState(.idle)
            return
        }
        
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            finishConnect(.success(()))
            setState(.ready)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        var currentSession: BluetoothSession?
        
        sessionLock.withLock { _ in
            currentSession = session
        }
        
        guard currentSession != nil else {
            print("Session object not initialized.")
            return
        }
            
        guard error == nil else {
            currentSession!.failure(BluetoothError.sessionError(error!.localizedDescription))
            return
        }
        
        if let data = characteristic.value {
            currentSession!.append(data)
        }
    }
    
    func query<T>(_ parameter: OBDParameter<T>) async throws -> T {
        let bytes = try await sendRaw(parameter.command)
        let parsed = try parseResponse(bytes)
        return try parameter.decode(parsed)
    }
    
    func sendRaw(_ command: String) async throws -> [UInt8] {
        let terminatedCommand = command.hasSuffix("\r")
            ? command
            : command + "\r"
        
        guard
            let characteristic = writeCharacteristic,
            let writeData = terminatedCommand.data(using: .ascii),
            let device = peripheral
        else {
            throw BluetoothError.bluetoothUnavailable
        }
        
        var currentSession: BluetoothSession?
        
        defer {
            sessionLock.withLock { _ in
                if currentSession == session {
                    session = nil
                }
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var error: Error?
            
            sessionLock.withLock { _ in
                if session != nil {
                    error = BluetoothError.sessionError("Bluetooth transport busy.")
                } else {
                    currentSession = BluetoothSession(continuation)
                    session = currentSession
                }
            }
            
            guard error == nil else {
                continuation.resume(throwing: error!)
                return
            }
            
            device.writeValue(writeData, for: characteristic, type: .withResponse)
        }
    }
    
    private func parseResponse(_ bytes: [UInt8]) throws -> [UInt8] {
        guard let string = String(bytes: bytes, encoding: .ascii) else {
            throw PIDError.decodingError("Invalid ASCII response.")
        }
        
        let hex = string
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !hex.isEmpty else {
            throw PIDError.decodingError("Empty response.")
        }
        
        guard hex.count % 2 == 0 else {
            throw PIDError.decodingError("Invalid hex response: \(hex)")
        }
        
        return stride(from: 0, to: hex.count, by: 2).compactMap { index in
            let start = hex.index(hex.startIndex, offsetBy: index)
            let end = hex.index(start, offsetBy: 2)

            return UInt8(hex[start..<end], radix: 16)
        }
    }
    
    private func setState(_ newState: ConnectionState) {
        state = newState
        print("Bluetooth state -> \(newState)")
    }
    
    private func finishConnect(_ result: Result<Void, Error>) {
        switch result {
            case .success:
                connectContinuation?.resume()
            case .failure(let error):
                connectContinuation?.resume(throwing: error)
        }
        
        connectContinuation = nil
    }
    
    func disconnect() {
        centralManager.stopScan()
        finishConnect(.failure(BluetoothError.connectionFailed))
        
        guard let peripheral else {
            return
        }
        
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        print("Disconnected")
        
        centralManager.stopScan()
        
        self.peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        
        setState(.idle)
    }
}
