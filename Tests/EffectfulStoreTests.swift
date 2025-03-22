//
//  EffectfulStoreTests.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/10/24.
//

import Testing
import Foundation
import Synchronization
import AsyncReactiveSequences
@testable import AsyncRedux

@MainActor
final class EffectfulStoreTests {
    enum Error: Swift.Error {
        case standardError
    }
    
    enum State: Hashable {
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
    
    private lazy var store = defaultStore()
    
    private func defaultStore() -> EffectfulStore<State, Action> {
        withEffect(.init(reducer: { action, state in
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
        }
    }
    
    // MARK: - Continue
    
    @Test("Reducer and effect continue processing until an effect signals .stop", .timeLimit(.minutes(1)))
    func continueUntilStopIsReached() async throws {
        let states = Task {
            try await store.state.collect(count: 3)
        }
        
        #expect(try await store.dispatch(action: .start) == .finished)
        
        let test: [State] = [.initializing, .running, .finished]
        #expect((try await states.value) == test)
    }
    
    // MARK: - Failure
    
    @Test("Effect explicitly fails and returns one final action for the reducer to run.", .timeLimit(.minutes(1)))
    func explicitFail() async throws {
        let store: EffectfulStore<State, Action> = withEffect(.init(reducer: { action, state in
            switch action {
            case .start:
                state = .running
            case .cleanup:
                state = .failed
            default:
                break
            }
        }, state: .initializing)) { action, state in
            return .fail(Error.standardError, .cleanup)
        }
        
        await #expect(throws: Error.standardError, performing: {
            try await store.dispatch(action: .start)
        })
        
        #expect(store.state.value == .failed)
    }
    
    @Test("Effect calls an internal function that throws an error and returns the current state.", .timeLimit(.minutes(1)))
    func implicitFail() async throws {
        let store: EffectfulStore<State, Action> = withEffect(.init(reducer: { action, state in
            switch action {
            case .start:
                state = .running
            case .cleanup:
                state = .failed
            default:
                break
            }
        }, state: .initializing)) { action, state in
            throw Error.standardError
        }
        
        await #expect(throws: Error.standardError, performing: {
            try await store.dispatch(action: .start)
        })
        
        #expect(store.state.value == .running)
    }
    
    // MARK: - Reentrancy
    
    @Test("Ensures that a second dispatch waits for the first to complete and does not trigger duplicate state transitions")
    func ensureOnlyOneDispatchRunsAtATime() async throws {
        let states = Task {
            try await store.state.collect(count: 3)
        }
        
        let first = Task {
            try await store.dispatch(action: .start)
        }
        
        let second = Task {
            try await store.dispatch(action: .start)
        }
        
        try await #expect(first.value == .finished)
        try await #expect(second.value == .finished)
        
        let test: [State] = [.initializing, .running, .finished]
        #expect((try await states.value) == test)
    }
}
