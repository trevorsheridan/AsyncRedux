//
//  withEffect.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/9/24.
//

public func withEffect<State, Action: AsyncRedux.Action>(_ store: Store<State, Action>, effect: @escaping (_ action: Action, _ state: State) async throws -> EffectfulStore<State, Action>.Result) -> EffectfulStore<State, Action> {
    EffectfulStore(wrapping: store) { action, state, previous in
        try await effect(action, state)
    }
}

public func withEffect<State, Action: AsyncRedux.Action>(_ store: Store<State, Action>, effect: @escaping (_ action: Action, _ state: State, _ previous: State) async throws -> EffectfulStore<State, Action>.Result) -> EffectfulStore<State, Action> {
    EffectfulStore(wrapping: store, effect: effect)
}
