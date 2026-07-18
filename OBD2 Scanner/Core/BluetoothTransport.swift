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
    
    private var session: BluetoothSession?
    private let sessionLock = Mutex<Void>(())
    
    private(set) var state: ConnectionState = .idle
    
    private var peripherals: [CBPeripheral] = []
    var onPeripheralsUpdated: (([CBPeripheral]) -> Void)?
    
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
    
    func startScan() async throws {
        try await waitForBluetoothPower()
        scanForPeripherals()
    }
    
    func stopScan() {
        centralManager.stopScan()
        setState(.idle)
    }
    
    func connect(_ peripheral: CBPeripheral) async throws {
        let connectTask = Task {
            try await connectToPeripheral(peripheral)
        }
        
        let timeout = Task {
            try? await Task.sleep(for: .seconds(60))
            guard connectContinuation != nil else { return }
            centralManager.cancelPeripheralConnection(peripheral)
            finishConnect(.failure(BluetoothError.connectionTimeout))
            connectTask.cancel()
        }
        
        do {
            try await connectTask.value
            timeout.cancel()
        } catch {
            throw error
        }
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
    
    func scanForPeripherals() {
        print("Scanning for peripherals...")
        
        peripherals = []
        DispatchQueue.main.async {
            self.onPeripheralsUpdated?(self.peripherals)
        }
        
        centralManager.scanForPeripherals(
            withServices: nil,
            options: nil
        )
        
        setState(.scanning)
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) async throws {
        print("Connecting to peripheral \(peripheral.name!).")
        
        try await withCheckedThrowingContinuation { continuation in
            connectContinuation = continuation
            self.peripheral = peripheral
            peripheral.delegate = self
            peripherals = []
            DispatchQueue.main.async {
                self.onPeripheralsUpdated?(self.peripherals)
            }

            centralManager.stopScan()
            centralManager.connect(peripheral)

            setState(.connecting)
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        guard let name = peripheral.name else {
            return
        }
        
        if !peripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            print("Discovered peripheral \(name).")
            peripherals.append(peripheral)
            
            DispatchQueue.main.async {
                self.onPeripheralsUpdated?(self.peripherals)
            }
        }
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
            print(error!)
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
            print(error!)
            finishConnect(.failure(error!))
            setState(.idle)
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        if service.uuid.uuidString.uppercased() == "FFF0" {
            for characteristic in characteristics {
                switch characteristic.uuid.uuidString.uppercased() {
                    case "FFF2":
                        writeCharacteristic = characteristic
                    case "FFF1":
                        notifyCharacteristic = characteristic
                        
                        let props = characteristic.properties
                        if props.contains(.notify) || props.contains(.indicate) {
                            peripheral.setNotifyValue(true, for: characteristic)
                        } else {
                            print("Unexpected: FFF1 in service FFF0 does not support notifications.")
                        }
                    default:
                        break
                }
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.isNotifying else {
            print(error ?? BluetoothError.connectionFailed)
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
    
    func query<T>(_ parameter: OBDParameter<T>) async throws -> Snapshot<T> {
        let bytes = try await sendRaw(Mode.command(parameter.mode, parameter.pid))
        let parsed = try parseResponse(bytes)
        return try await parameter.decode(parsed)
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
    
    private func parseResponse(_ bytes: [UInt8]) throws -> [[UInt8]] {
        let lines = bytes.split { $0 == 0x0D || $0 == 0x0A } // split by carriage return or new line
        var frames: [[UInt8]] = []
        
        for i in lines.indices {
            let line = lines[i]
            guard
                (i < 1 || line != lines[i - 1]) &&
                (i < 2 || line != lines[i - 2])
            else {
                continue
            }
            
            guard !line.isEmpty && line.count % 2 == 0 else {
                continue
            }
            
            var frame: [UInt8] = []
            var j = line.startIndex
            
            while j + 1 < line.endIndex {
                let high = line[j]
                let low = line[j + 1]
                
                guard
                    let highNibble = hexValue(high),
                    let lowNibble = hexValue(low)
                else {
                    j += 2
                    continue
                }
                
                frame.append((highNibble << 4) | lowNibble)
                j += 2
            }
            
            if !frame.isEmpty {
                frames.append(frame)
            }
        }

        return frames
    }
    
    private func hexValue(_ byte: UInt8) -> UInt8? {
        // incoming byte is an ASCII code
        switch byte {
            case 48...57: // 0-9
                return byte - 48
            case 65...70: // A-F
                return byte - 55
            case 97...102: // a-f
                return byte - 87
            default:
                return nil
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
