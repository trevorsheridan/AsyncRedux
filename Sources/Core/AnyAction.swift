//
//  AnyAction.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 3/21/25.
//

public struct AnyAction: Action {
    public let action: any Action
    
    public init<A: Action>(action: A) {
        self.action = action
    }
}
