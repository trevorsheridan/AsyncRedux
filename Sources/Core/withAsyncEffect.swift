//
//  withAsyncEffect.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/9/24.
//

public func withAsyncEffect<State, Action: AsyncRedux.Action>(_ store: Store<State, Action>, effect: @escaping (_ action: Action, _ state: State) async throws -> AsyncEffectfulStore<State, Action>.Result) -> AsyncEffectfulStore<State, Action> {
    AsyncEffectfulStore(wrapping: store) { action, state, previous in
        try await effect(action, state)
    }
}

public func withAsyncEffect<State, Action: AsyncRedux.Action>(_ store: Store<State, Action>, effect: @escaping (_ action: Action, _ state: State, _ previous: State) async throws -> AsyncEffectfulStore<State, Action>.Result) -> AsyncEffectfulStore<State, Action> {
    AsyncEffectfulStore(wrapping: store, effect: effect)
}
