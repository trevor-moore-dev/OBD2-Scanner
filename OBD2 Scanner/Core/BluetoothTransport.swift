//
//  BluetoothTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/4/26.
//

import CoreBluetooth

enum BluetoothError: Error {
    case connectionFailed
    case connectionTimeout
    case bluetoothUnavailable
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
            do {
                try await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60 seconds
            } catch {
                return
            }
            
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
        
        print("Service: \(service.uuid)")
        
        for characteristic in characteristics {
            print("Characteristic: \(characteristic.uuid)")
            printProperties(characteristic.properties)
            
            if characteristic.properties.contains(.write) ||
                characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }
            
            if characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
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
        guard error == nil else {
            print(error!.localizedDescription)
            return
        }
        
        // TODO
    }
    
    func send<T>(_ command: OBDParameter<T>) async -> [UInt8] {
        // TODO
        return []
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
    
    private func printProperties(_ properties: CBCharacteristicProperties) {
        if properties.contains(.broadcast) {
            print("  • broadcast")
        }
        if properties.contains(.read) {
            print("  • read")
        }
        if properties.contains(.writeWithoutResponse) {
            print("  • writeWithoutResponse")
        }
        if properties.contains(.write) {
            print("  • write")
        }
        if properties.contains(.notify) {
            print("  • notify")
        }
        if properties.contains(.indicate) {
            print("  • indicate")
        }
        if properties.contains(.authenticatedSignedWrites) {
            print("  • authenticatedSignedWrites")
        }
        if properties.contains(.extendedProperties) {
            print("  • extendedProperties")
        }
        if properties.contains(.notifyEncryptionRequired) {
            print("  • notifyEncryptionRequired")
        }
        if properties.contains(.indicateEncryptionRequired) {
            print("  • indicateEncryptionRequired")
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
