//
//  MockSimpleStoreProvider.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/28/24.
//

import Foundation
import AsyncRedux
import AsyncSimpleStore
import Synchronization

final class MockSimpleStoreProvider<Value>: StorageProviding where Value: Sendable {
    private let value: Mutex<Value?>
    
    init(_ value: Value? = nil) {
        self.value = Mutex(value)
    }
    
    func read() -> Value? {
        value.withLock { v in
            v
        }
    }
    
    func write(value: Value) throws {
        self.value.withLock { v in
            v = value
        }
    }
    
    func destroy() {
        value.withLock { v in
            v = nil
        }
    }
}
