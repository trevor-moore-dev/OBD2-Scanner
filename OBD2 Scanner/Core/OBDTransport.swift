//
//  OBDTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

protocol OBDTransport {
    func connect() async throws
    func disconnect()
    func send<T>(_ command: OBDParameter<T>) async -> [UInt8]
}
