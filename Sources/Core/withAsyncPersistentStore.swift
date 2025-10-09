//
//  withAsyncPersistentStore.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 10/6/25.
//

import AsyncSimpleStore

public func withAsyncPersistentStore<State, Action: AsyncRedux.Action, Provider>(_ store: any StoreProtocol<State, Action>, persistentStore: SimpleStore<State, Provider>, transform: (@Sendable (_ state: State) -> State)? = nil) -> AsyncPersistentStore<State, Action, Provider> where Provider: StorageProviding, Provider.Value == State {
    AsyncPersistentStore(wrapping: store, persistentStore: persistentStore, transform: transform)
}
