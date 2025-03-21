//
//  Reducer.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/27/24.
//

public typealias Reducer<State: AsyncRedux.State, Action: AsyncRedux.Action> = @Sendable (_ action: Action, _ state: inout State) -> Void
