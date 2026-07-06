//
//  BluetoothSession.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/6/26.
//

import Foundation

class BluetoothSession: Equatable {
    
    private var buffer: Data
    private var continuation: CheckedContinuation<[UInt8], Error>?
    private var timeout: Task<Void, Never>?
    
    init(_ continuation: CheckedContinuation<[UInt8], Error>) {
        self.buffer = Data()
        self.continuation = continuation
        self.timeout = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.continuation?.resume(throwing: BluetoothError.sessionTimeout)
            self?.continuation = nil
        }
    }
    
    deinit {
        self.timeout?.cancel()
    }
    
    static func == (lhs: BluetoothSession, rhs: BluetoothSession) -> Bool {
        lhs === rhs
    }
    
    func append(_ data: Data) {
        guard self.continuation != nil else {
            return
        }
        
        self.buffer.append(data)
        
        if let endIndex = self.buffer.firstIndex(of: 62) {
            self.timeout?.cancel()
            self.continuation?.resume(
                returning:[UInt8](self.buffer[self.buffer.startIndex...endIndex])
            )
            self.continuation = nil
        }
    }
    
    func failure(_ error: Error) {
        self.timeout?.cancel()
        self.continuation?.resume(throwing: error)
        self.continuation = nil
    }
}
