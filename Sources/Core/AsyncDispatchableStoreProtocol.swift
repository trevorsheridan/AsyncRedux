//
//  AsyncDispatchableStoreProtocol.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 10/9/25.
//

@available(iOS 18.0, *)
public protocol AsyncDispatchableStoreProtocol<State, Action>: StoreProtocol {
    func dispatch(isolation: isolated (any Actor)?, action: Action) async throws -> State
}
