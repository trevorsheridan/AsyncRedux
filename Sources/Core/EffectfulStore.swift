//
//  EffectfulStore.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/9/24.
//

import Synchronization
import Semaphore
import AsyncReactiveSequences

@available(iOS 18.0, *)
public class EffectfulStore<State, Action>: StoreProtocol where State: AsyncRedux.State & Sendable, Action: AsyncRedux.Action {
    public typealias Effect = (_ action: Action, _ state: State, _ previous: State) async throws -> Result
    
    public enum Result: Sendable {
        case `continue`(Action)
        case fail(any Swift.Error, (Action)?)
        case stop
    }
    
    enum Error: Swift.Error {
        case unexpectedError
    }
    
    public var state: AsyncReadOnlyCurrentValueSequence<State> {
        store.state
    }
    
    private let store: Store<State, Action>
    private let effect: Effect
    private let semaphore = AsyncSemaphore(value: 1)
    
    public init(wrapping store: Store<State, Action>, effect: @escaping Effect) {
        self.store = store
        self.effect = effect
    }
    
    @discardableResult
    public func dispatch(isolation: isolated (any Actor)? = #isolation, action: Action) async throws -> State {
        // Ensure only one task can execute the entire body of this function from top to bottom at a time.
        await semaphore.wait()
        defer { semaphore.signal() }
        
        var action = action
        var previous = store.state.value
        
        while true {
            // Dispatch a state change to the store.
            let state = await store.dispatch(action: action)
            
            guard state != previous else {
                // There is no further action to take, return the state that was passed into the effect.
                return state
            }
            
            let result = try await effect(action, state, previous)
            
            switch result {
            case .continue(let nextAction):
                // The effect indicated that processing should continue: dispatch another action to the store and run another effect.
                action = nextAction
                previous = state
            case .fail(let error, let action):
                if let action {
                    // The effect provided a final action to dispatch so the store can perform any last state changes.
                    await store.dispatch(action: action)
                }
                
                throw error
            case .stop:
                // The effect indicated there's no further action to take, return the current state.
                return state
            }
        }
    }
    
    public func sequence<Value>(for keyPath: KeyPath<State, Value>) -> AnyAsyncSequence<Value> where Value : Hashable, Value : Sendable {
        store.sequence(for: keyPath)
    }
    
    public func sequence<Value>(for keyPath: KeyPath<State, Value?>) -> AnyAsyncSequence<Value?> where Value : Hashable, Value : Sendable {
        store.sequence(for: keyPath)
    }
    
    public func sequence<Value, Reactor>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value> where Value : Hashable, Value : Sendable, Reactor : Hashable, Reactor : Sendable {
        store.sequence(for: keyPath, reactingTo: reactionKeyPath)
    }
    
    public func sequence<Value, Reactor>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value?> where Value : Hashable, Value : Sendable, Reactor : Hashable, Reactor : Sendable {
        store.sequence(for: keyPath, reactingTo: reactionKeyPath)
    }
    
    public func sequence<Value, Reactor>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value> where Value : Hashable, Value : Sendable, Reactor : Hashable, Reactor : Sendable {
        store.sequence(for: keyPath, reactingTo: reactionKeyPath)
    }
    
    public func sequence<Value, Reactor>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value?> where Value : Hashable, Value : Sendable, Reactor : Hashable, Reactor : Sendable {
        store.sequence(for: keyPath, reactingTo: reactionKeyPath)
    }
}
