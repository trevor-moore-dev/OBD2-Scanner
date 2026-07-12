//
//  DTCService.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/11/26.
//

import Foundation
internal import Combine

@MainActor
final class DTCService: ObservableObject {
    
    private let repository: DTCRepository
    private let transport: OBDTransport
    
    init(transport: OBDTransport, repository: DTCRepository) {
        self.transport = transport
        self.repository = repository
    }
    
    func readDiagnosticTroubleCodes() async -> [DTC] {
        do {
            let bytes = try await transport.sendRaw("03")
            guard let string = String(bytes: bytes, encoding: .ascii) else {
                return []
            }
            
            let lines = string.components(separatedBy: "\r")
            var allBytes: [UInt8] = []

            for line in lines {
                var cleanedLine = line
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: ">", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                guard cleanedLine.count >= 2 else {
                    continue
                }
                
                var lineBytes: [UInt8] = []
                
                for i in stride(from: 0, to: cleanedLine.count - 1, by: 2) {
                    let start = cleanedLine.index(cleanedLine.startIndex, offsetBy: i)
                    let end = cleanedLine.index(start, offsetBy: 2)
                    
                    guard let byte = UInt8(cleanedLine[start..<end], radix: 16) else {
                        continue
                    }
                    
                    if i != 0 || byte != 0x43 {
                        lineBytes.append(byte)
                    }
                }
                
                allBytes.append(contentsOf: lineBytes)
            }
            
            var errorCodes: [DTC] = []
            
            for i in stride(from: 0, to: allBytes.count - 1, by: 2) {
                let firstByte = allBytes[i]
                let secondByte = allBytes[i + 1]
                
                guard firstByte != 0x00 || secondByte != 0x00 else {
                    continue
                }
                
                let firstDigit = Int(firstByte >> 4) // shift left 4 bits to keep the original left nibble
                let secondDigit = Int(firstByte & 0x0F) // bitwise AND to keep the original right nibble
                let prefix = DTCUtils.getPrefix(for: firstDigit)
                let suffix = String(format: "%02X", secondByte)
                
                let code = "\(prefix)\(secondDigit)\(suffix)"
                let description = await repository.lookup(code)
                
                errorCodes.append(
                    DTC(code: code, description: description)
                )
            }
            
            return errorCodes
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
}
