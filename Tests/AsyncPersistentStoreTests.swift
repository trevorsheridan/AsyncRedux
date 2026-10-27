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

    @Test("Test transform applies to the persisted state but not the returned state", .timeLimit(.minutes(1)))
    func transformedPersistence() async throws {
        let store: AsyncPersistentStore<State, Action, MockSimpleStoreProvider> = withAsyncPersistentStore(Store(reducing: { action, state in
            switch action {
            case .start:
                state = .running
            case .finishLongRunningTask:
                state = .finished
            case .cleanup:
                state = .failed
            }
        }, state: .initializing), persistentStore: persistentStore) { state in
            state == .running ? .initializing : state
        }

        #expect(try await store.dispatch(action: .start) == .running)
        #expect(store.state.value == .running)
        #expect(persistentStore.value == .initializing)
    }

    @Test("Test wrapped effectful store persists the final action's state when the effect fails", .timeLimit(.minutes(1)))
    func failedEffectPersistsFinalState() async throws {
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
                return .fail(Error.standardError, .cleanup)
            default:
                break
            }

            return .stop
        }, persistentStore: persistentStore)

        await #expect(throws: Error.standardError) {
            try await store.dispatch(action: .start)
        }

        #expect(store.state.value == .failed)
        #expect(persistentStore.value == .failed)
    }

    @Test("Test a failed write doesn't fail the dispatch", .timeLimit(.minutes(1)))
    func failedWrite() async throws {
        let store: AsyncPersistentStore<State, Action, FailingSimpleStoreProvider> = withAsyncPersistentStore(Store(reducing: { action, state in
            switch action {
            case .start:
                state = .running
            case .finishLongRunningTask:
                state = .finished
            case .cleanup:
                state = .failed
            }
        }, state: .initializing), persistentStore: SimpleStore(provider: FailingSimpleStoreProvider()))

        #expect(try await store.dispatch(action: .start) == .running)
    }
}

private final class FailingSimpleStoreProvider: BasicStorageProviding {
    func read() -> AsyncPersistentStoreTests.State? {
        nil
    }

    func write(value: AsyncPersistentStoreTests.State) throws {
        throw AsyncPersistentStoreTests.Error.standardError
    }

    func destroy() {}
}
