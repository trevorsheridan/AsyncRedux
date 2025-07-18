import Testing
import Foundation
import Synchronization
import AsyncReactiveSequences
import AsyncAlgorithms
@testable import AsyncRedux

@MainActor
final class StoreTests: Sendable {
    var store: Store<State, Action>!
    
    init() {
        store = Store<State, Action>(reducing: { [weak self] action, state in
            guard let self else {
                return
            }
            
            switch action {
            case Action.incrementAge(let age):
                state.user?.age = verifyAge(age: age)
            }
        }, state: .defaultState)
    }
    
    @Test("Update state when dispatch performs an action and causes reducer to run", .timeLimit(.minutes(1)))
    func updatesState() async throws {
        let state = await store.dispatch(action: Action.incrementAge(36))
        #expect(state.user?.age == 36)
    }
    
    @Test("Do not allow duplicate state", .timeLimit(.minutes(1)))
    func removesDuplicateState() async throws {
        let expectedAges: [Int] = [35, 36, 37]
        
        let agesTask = Task {
            try await store.sequence(for: \.user?.age)
            .compactMap { $0 }
            .collect(count: 3)
        }
        
        // Wrapping the following dispatches in a task ensures `agesTask` above runs first and gets a subscriber reigstered to the store's state.
        Task {
            await store.dispatch(action: Action.incrementAge(36))
            // Intentionally repeat the number from above to ensure it doesn't end up being repeated by the store.
            await store.dispatch(action: Action.incrementAge(36))
            await store.dispatch(action: Action.incrementAge(37))
        }
        
        #expect(try await agesTask.value == expectedAges)
    }
    
    // MARK: - Observing KeyPaths
    
    @Test("State change notifies sequence registered on a specific key path", .timeLimit(.minutes(1)))
    func notifiesKeyPathSequence() async throws {
        let newAge = store.state.value.user?.age
        
        let age = Task {
            try await store.sequence(for: \.user?.age)
                .first { @Sendable value in
                    value == newAge
                }
        }
        
        let state = await store.dispatch(action: Action.incrementAge(newAge))
        
        #expect(state.user?.age == newAge)
        #expect(try await age.value == newAge)
    }
    
    @Test("State change notifies sequence about key path when a different key path changes", .timeLimit(.minutes(1)))
    func notifiesKeyPathSequenceOnDifferentBranch() async throws {
        let addressTask = Task {
            try await store.sequence(for: \.user?.address, reactingTo: \.user?.age)
                .dropFirst()
                .first()
        }
        
        // Wrapping the dispatch in a task ensures `addressTask` above runs first and gets a subscriber reigstered to the store's state.
        let state = Task {
            await store.dispatch(action: Action.incrementAge(36))
        }
        
        #expect(try await addressTask.value?.city == "Cupertino")
        #expect(await state.value.user?.age == 36)
    }
    
    @Test("Key path sequence immediately sends initial value.", .timeLimit(.minutes(1)))
    func keyPathSequenceImmediatelySendsFirstValue() async throws {
        let value = try await store.sequence(for: \.user?.age).first { @Sendable _ in true }
        #expect(value == 35)
    }
    
    // MARK: - Helpers
    
    // A simple function to ensure the reducer can access methods in the actor context that it was defined in.
    private func verifyAge(age: Int?) -> Int {
        age ?? 1
    }
}
