//
//  withEffect.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/9/24.
//

public func withEffect<State>(_ store: Store<State>, effect: @escaping (_ action: any Action, _ state: State) async throws -> EffectfulStore<State>.Result?) -> EffectfulStore<State> {
    EffectfulStore(wrapping: store) { action, state, previous in
        try await effect(action, state)
    }
}

public func withEffect<State>(_ store: Store<State>, effect: @escaping (_ action: any Action, _ state: State, _ previous: State) async throws -> EffectfulStore<State>.Result?) -> EffectfulStore<State> {
    EffectfulStore(wrapping: store, effect: effect)
}
