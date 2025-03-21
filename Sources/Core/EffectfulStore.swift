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
public class EffectfulStore<State>: StoreProtocol where State: AsyncRedux.State & Sendable {
    public typealias Effect = (_ action: any Action, _ state: State, _ previous: State) async throws -> Result?
    
    public enum Result: Sendable {
        case success(any Action)
        case failure(any Swift.Error, (any Action)?)
    }
    
    enum Error: Swift.Error {
        case unexpectedError
    }
    
    private let store: Store<State>
    private let effect: Effect
    private let semaphore = AsyncSemaphore(value: 1)
    
    public nonisolated var state: AsyncReadOnlyCurrentValueSequence<State> {
        store.state
    }
    
    public init(wrapping store: Store<State>, effect: @escaping Effect) {
        self.store = store
        self.effect = effect
    }
    
    @discardableResult
    public func dispatch(isolation: isolated (any Actor)? = #isolation, action: any Action) async throws -> State {
        // Ensure only one task can execute the entire body of this function from top to bottom at a time.
        await semaphore.wait()
        defer { semaphore.signal() }
        
        var previous = store.state.value
        var action = action
        var error: Swift.Error?
        
        while true {
            // Dispatch a state change to the store.
            let state = await store.dispatch(action: action)
            
            if let error {
                throw error
            }
            
            guard state != previous, let result = try await effect(action, state, previous) else {
                // There is no further action to take, return the state that was passed into the effect.
                return state
            }
            
            switch result {
            case .success(let a):
                action = a
            case .failure(let e, let a):
                if let a {
                    action = a
                }
                error = e
            }
            
            previous = state
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
