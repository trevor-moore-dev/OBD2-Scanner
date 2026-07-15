//
//  OBDTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

import CoreBluetooth

protocol OBDTransport {
    var onPeripheralsUpdated: (([CBPeripheral]) -> Void)? { get set }
    
    func startScan() async throws
    func stopScan()
    func connect(_ peripheral: CBPeripheral) async throws
    func disconnect()
    func query<T>(_ parameter: OBDParameter<T>) async throws -> T
    func sendRaw(_ command: String) async throws -> [UInt8]
}
