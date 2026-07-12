//
//  OBDTransport.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 6/29/26.
//

protocol OBDTransport {
    func connect() async throws
    func disconnect()
    func query<T>(_ parameter: OBDParameter<T>) async throws -> T
    func sendRaw(_ command: String) async throws -> [UInt8]
    func parseResponse(_ bytes: [UInt8]) throws -> [UInt8]
}
