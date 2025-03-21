//
//  Stub.swift
//  AsyncRedux
//
//  Created by Trevor Sheridan on 8/28/24.
//

import Foundation
import AsyncRedux

struct Address: Hashable {
    var street: String
    var city: String
    var state: String
    var zipCode: Int
}

struct User: Hashable {
    var name: String
    var age: Int?
    var address: Address
}

enum AuthenticationPhase: Hashable {
    case unauthenticated
    case authenticating
    case authenticated
}

struct State: AsyncRedux.State {
    var date: Date
    var phase: AuthenticationPhase
    var user: User?
}

enum Action: AsyncRedux.Action {
    case login(username: String, password: String)
    case incrementAge(Int?)
}

extension State {
    static var defaultState: State {
        let address = Address(street: "1 Infinite Loop", city: "Cupertino", state: "CA", zipCode: 95014)
        let user = User(name: "Trevor", age: 35, address: address)
        return State(date: Date.distantFuture, phase: .unauthenticated, user: user)
    }
}
