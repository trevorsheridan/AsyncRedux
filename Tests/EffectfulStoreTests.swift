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

actor TestNetworkManager {
    func request<T>(response: T) async throws -> T {
        try await Task.sleep(for: .milliseconds(300))
        return response
    }
}

let networkManager = TestNetworkManager()

enum StateAction: AsyncRedux.Action {
    case advanceToAuthenticated
}

@MainActor
final class EffectfulStoreTests {
    private lazy var store = redux()
    
    private func redux() -> EffectfulStore<State> {
        withEffect(Store<State> { action, state in
            var state = state ?? .defaultState
            
            switch action {
            case Action.login(let username, let password) where state.phase == .unauthenticated:
                state.phase = .authenticating
            case StateAction.advanceToAuthenticated where state.phase == .authenticating:
                state.phase = .authenticated
            default:
                break
            }
            
            return state
        }) { action, state in
            switch action {
            case Action.login(username: let username, password: let password):
                let response = try await networkManager.request(response: true)
                return .success(StateAction.advanceToAuthenticated)
            default:
                return nil
            }
        }
    }
    
    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
    func dispatchWaitingForEffectToFinish() async throws {
        Task {
            for try await state in store.state {
                print("sequence change", state.phase)
            }
        }
        
        #expect(store.state.value.phase == .unauthenticated)
        let state = try await store.dispatch(action: Action.login(username: "test", password: "test"))
        #expect(state.phase == .authenticated)
    }
    
    @Test(.tags(.dispatch, .effects), .timeLimit(.minutes(1)))
    func dispatchEnsuringMultipleCallsDontRace() async throws {
        let phases = Task {
            try await store.state.drop(while: { state in
                state.phase == .unauthenticated
            }).map { state in
                state.phase
            }.collect(count: 2)
        }
        
//        async let phases = store.state.drop(while: { state in
//            state.phase == .unauthenticated
//        }).map { state in
//            state.phase
//        }.collect(count: 2)
        
        try await store.dispatch(action: Action.login(username: "test", password: "test"))
        try await store.dispatch(action: Action.login(username: "test", password: "test"))
        
        let test = [AuthenticationPhase.authenticating, AuthenticationPhase.authenticated]
        #expect((try await phases.value) == test)
    }
}
