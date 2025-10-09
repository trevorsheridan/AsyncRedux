//
//  DispatchableStoreProtocol.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 10/9/25.
//

@available(iOS 18.0, *)
public protocol DispatchableStoreProtocol<State, Action>: StoreProtocol {
    func dispatch(action: Action) throws -> State
}
