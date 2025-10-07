//
//  AsyncEffectfulStore 2.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 10/6/25.
//

import Synchronization
import Semaphore
import AsyncReactiveSequences
import AsyncSimpleStore

@available(iOS 18.0, *)
public class AsyncPersistentStore<State, Action, Provider>: AsyncDispatchableStoreProtocol
where State: AsyncRedux.State & Codable & Sendable, Action: AsyncRedux.Action, Provider: StorageProviding, Provider.Value == State {
    enum Error: Swift.Error {
        case unrecognizedInternalDispatch
    }
    
    public var state: AsyncReadOnlyCurrentValueSequence<State> {
        store.state
    }
    
    private let store: any StoreProtocol<State, Action>
    private let persistentStore: SimpleStore<State, Provider>
    private let transform: (@Sendable (_ state: State) -> State)?
    private let semaphore = AsyncSemaphore(value: 1)
    private var cancellables = Set<TaskCancellable>()
    
    public init(wrapping store: any StoreProtocol<State, Action>, persistentStore: SimpleStore<State, Provider>, transform:  (@Sendable (_ state: State) -> State)? = nil) {
        self.store = store
        self.persistentStore = persistentStore
        self.transform = transform
    }
    
    @discardableResult
    public func dispatch(isolation: isolated (any Actor)? = #isolation, action: Action) async throws -> State {
        // Ensure only one task can execute the entire body of this function from top to bottom at a time.
        await semaphore.wait()
        defer { semaphore.signal() }
  
        var state: State
        
        switch store {
        case let store as any AsyncDispatchableStoreProtocol<State, Action>:
            state = try await store.dispatch(isolation: isolation, action: action)
        case let store as any DispatchableStoreProtocol<State, Action>:
            state = try store.dispatch(action: action)
        default:
            throw Error.unrecognizedInternalDispatch
        }
        
        if let transform {
            state = transform(state)
        }
        
        try persistentStore.write(value: state)
        
        return state
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
