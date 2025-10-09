//
//  AsyncEffectfulStoreTests.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/10/24.
//

import Testing
import AsyncReactiveSequences
import AsyncSimpleStore
@testable import AsyncRedux

@MainActor
final class AsyncPersistentStoreTests {
    enum Error: Swift.Error {
        case standardError
    }
    
    enum State: Codable, Hashable {
        case initializing
        case running
        case finished
        case failed
    }
    
    enum Action: AsyncRedux.Action {
        case start
        case finishLongRunningTask
        case cleanup
    }
    
    private let persistentStore = SimpleStore(provider: MockSimpleStoreProvider<State>())
    
    @Test("Test wrapped store persists value", .timeLimit(.minutes(1)))
    func wrappedStore() async throws {
        let store: AsyncPersistentStore<State, Action, MockSimpleStoreProvider> = withAsyncPersistentStore(Store(reducing: { action, state in
            switch action {
            case .start:
                state = .running
            case .finishLongRunningTask:
                state = .finished
            case .cleanup:
                state = .failed
            }
        }, state: .initializing), persistentStore: persistentStore)
        
        #expect(try await store.dispatch(action: .start) == .running)
        #expect(persistentStore.value == .running)
        
        #expect(try await store.dispatch(action: .finishLongRunningTask) == .finished)
        #expect(persistentStore.value == .finished)
    }
    
    @Test("Test wrapped effectful store persists state when final state change is emitted", .timeLimit(.minutes(1)))
    func wrappedEffectfulStore() async throws {
        let store: AsyncPersistentStore<State, Action, MockSimpleStoreProvider> = withAsyncPersistentStore(withAsyncEffect(.init(reducing: { action, state in
            switch action {
            case .start:
                state = .running
            case .finishLongRunningTask:
                state = .finished
            case .cleanup:
                state = .failed
            }
        }, state: .initializing)) { action, state in
            switch state {
            case .running:
                try await Task.sleep(for: .milliseconds(300))
                return .continue(.finishLongRunningTask)
            default:
                break
            }
            
            return .stop
        }, persistentStore: persistentStore)
        
        #expect(try await store.dispatch(action: .start) == .finished)
        #expect(persistentStore.value == .finished)
    }
}
