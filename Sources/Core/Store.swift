//
//  Store.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/27/24.
//

import Synchronization
import AsyncReactiveSequences

@available(iOS 18.0, *)
public class Store<State>: StoreProtocol where State: AsyncRedux.State {
    enum StoreAction: Action {
        case initialize
    }
    
    private typealias ChannelKey = Int
    
    typealias SendableKeyPath = KeyPath<State, Sendable>
    
    fileprivate struct Channel {
        let sequenceContainer: SequenceContainer
        let reactionKeyPath: PartialKeyPath<State>
        let valueKeyPath: PartialKeyPath<State>
    }
    
    public nonisolated lazy var state: AsyncReadOnlyCurrentValueSequence<State> = AsyncReadOnlyCurrentValueSequence(from: sequence)
    
    private let criticalState: Mutex<State>
    private let reducer: Reducer<State>
    private let sequence: AsyncCurrentValueSequence<State>
    private var channels = [ChannelKey: Channel]()
    
    // Uses the nonisolated initialization technique found here so initialization can take place in a globally isolated context.
    // https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems#Non-Isolated-Initialization
    public init(reducer: @escaping Reducer<State>, state: State? = nil) {
        self.reducer = reducer
        let state = state ?? reducer(StoreAction.initialize, nil)
        self.criticalState = .init(state)
        self.sequence = .init(state)
    }
    
    // MARK: - AsyncSequence
    
    public func sequence<Value: Hashable & Sendable>(for keyPath: KeyPath<State, Value>) -> AnyAsyncSequence<Value> {
        sequence(reactionKeyPath: keyPath, valueKeyPath: keyPath)
    }
    
    public func sequence<Value: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>) -> AnyAsyncSequence<Value?> {
        sequence(reactionKeyPath: keyPath, valueKeyPath: keyPath)
    }
    
    public func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value> {
        sequence(reactionKeyPath: reactionKeyPath, valueKeyPath: keyPath)
    }
    
    public func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor>) -> AnyAsyncSequence<Value?> {
        sequence(reactionKeyPath: reactionKeyPath, valueKeyPath: keyPath)
    }
    
    public func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value> {
        sequence(reactionKeyPath: reactionKeyPath, valueKeyPath: keyPath)
    }
    
    public func sequence<Value: Hashable & Sendable, Reactor: Hashable & Sendable>(for keyPath: KeyPath<State, Value?>, reactingTo reactionKeyPath: KeyPath<State, Reactor?>) -> AnyAsyncSequence<Value?> {
        sequence(reactionKeyPath: reactionKeyPath, valueKeyPath: keyPath)
    }
    
    private func sequence<ReactionValue: Hashable & Sendable, Value: Hashable & Sendable>(reactionKeyPath: KeyPath<State, ReactionValue>, valueKeyPath: KeyPath<State, Value>) -> AnyAsyncSequence<Value> {
        let identifier = channelIdentifier(reactionKeyPath: reactionKeyPath, valueKeyPath: valueKeyPath)
        
        if let channel = channels[identifier] {
            return channel.sequenceContainer.sequence()
        }
        
        let value = state.value[keyPath: valueKeyPath]
        let channel = Channel(sequenceContainer: .init(value), reactionKeyPath: reactionKeyPath, valueKeyPath: valueKeyPath)
        channels[identifier] = channel
        
        return channel.sequenceContainer.sequence()
    }
    
    // MARK: - Dispatch
    
    @discardableResult
    public func dispatch(isolation: isolated (any Actor)? = #isolation, action: Action) async -> State {
        let (state, original) = perform(action: action)
        
        if state != original {
            sequence.send(state)
        }
        
        dispatch(channels: channels, state: (state, original))
        
        return state
    }
    
    private func dispatch(channels: [ChannelKey: Channel], state: (next: State, previous: State?), ignoresEquality: Bool = false) {
        let notifications = channels.reduce(into: [(value: Any, channel: Channel)]()) { (notifications, channel) in
            let channel = channel.value
            let previous = state.previous?[keyPath: channel.reactionKeyPath] as? AnyHashable
            let next = state.next[keyPath: channel.reactionKeyPath] as? AnyHashable
            
            guard next != previous || ignoresEquality else {
                return
            }
            
            // Determine the value to be sent through the channel:
            // - If the reaction key path differs from the value key path, retrieve the value from the value key path.
            // - Otherwise, use the `next` value directly.
            let value = channel.reactionKeyPath != channel.valueKeyPath ? state.next[keyPath: channel.valueKeyPath] : next as Any
            notifications.append((value, channel))
        }
        
        for notification in notifications {
            notification.channel.sequenceContainer.send(value: notification.value)
        }
    }
    
    @discardableResult
    private nonisolated func perform(action: Action) -> (next: State, previous: State?) {
        criticalState.withLock { previous in
            let next = reducer(action, previous)
            defer { previous = next }
            return (next: next, previous: previous)
        }
    }
    
    // MARK: - Channels
    
    private func channelIdentifier(reactionKeyPath: AnyKeyPath, valueKeyPath: AnyKeyPath) -> ChannelKey {
        var hasher = Hasher()
        hasher.combine(reactionKeyPath)
        hasher.combine(valueKeyPath)
        return hasher.finalize()
    }
}

extension Store.Channel {
    struct SequenceContainer {
        struct UnsafeValueBox: @unchecked Sendable {
            nonisolated(unsafe) var value: Any
        }
        
        private let base: AsyncCurrentValueSequence<UnsafeValueBox?>
        
        init<Value: Sendable>(_ value: Value) {
            self.base = .init(.init(value: value))
        }
        
        func send(value: Any) {
            base.send(UnsafeValueBox(value: value))
        }
        
        func sequence<Value: Sendable>() -> AnyAsyncSequence<Value> {
            base.compactMap { box in
                box?.value as? Value
            }.eraseToAnyAsyncSequence()
        }
    }
}
