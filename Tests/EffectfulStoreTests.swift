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
        withEffect(.init(reducing: { action, state in
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
                return .continue(.finishLongRunningTask)
            default:
                break
            }
            
            return .stop
        }
    }
    
    // MARK: - Continue
    
    @Test("Reducer and effect continue processing until an effect signals .stop", .timeLimit(.minutes(1)))
    func continueUntilStopIsReached() throws {
        #expect(try store.dispatch(action: .start) == .finished)
        #expect(try store.state.value == .finished)
    }
    
    // MARK: - Failure
    
    @Test("Effect explicitly fails and returns one final action for the reducer to run.", .timeLimit(.minutes(1)))
    func explicitFail() throws {
        let store: EffectfulStore<State, Action> = withEffect(.init(reducing: { action, state in
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
        
        #expect(throws: Error.standardError, performing: {
            try store.dispatch(action: .start)
        })
        
        #expect(store.state.value == .failed)
    }
    
    @Test("Effect calls an internal function that throws an error and returns the current state.", .timeLimit(.minutes(1)))
    func implicitFail() throws {
        let store: EffectfulStore<State, Action> = withEffect(.init(reducing: { action, state in
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
        
        #expect(throws: Error.standardError, performing: {
            try store.dispatch(action: .start)
        })
        
        #expect(store.state.value == .running)
    }
}
