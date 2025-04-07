//
//  StoreProtocol.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 9/9/24.
//

import AsyncReactiveSequences

@available(iOS 18.0, *)
public protocol StoreProtocol {
    associatedtype State: AsyncRedux.State & Sendable
    associatedtype Action: AsyncRedux.Action
    var state: AsyncReadOnlyCurrentValueSequence<State> { get }
    func sequence<Value: Hashable & Sendable>(for keyPath: KeyPath<State, Value>) -> AnyAsyncSequence<Value>
    func sequence<Value: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>) -> AnyAsyncSequence<Value?>
    func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value>
    func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value?>
    func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value>
    func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value?>
    @discardableResult func dispatch(isolation: isolated (any Actor)?, action: Action) async throws -> State
}
