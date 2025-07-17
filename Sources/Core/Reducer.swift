//
//  Reducer.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/27/24.
//

public typealias Reducer<State: AsyncRedux.State, Action: AsyncRedux.Action> = (_ action: Action, _ state: State) -> State
