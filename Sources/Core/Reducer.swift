//
//  Reducer.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/27/24.
//

public typealias Reducer<State: AsyncRedux.State> = @Sendable (_ action: Action, _ state: State?) -> State
