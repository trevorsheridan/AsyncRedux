import Testing
import Foundation
import Synchronization
import AsyncReactiveSequences
import AsyncAlgorithms
@testable import AsyncRedux

@MainActor
final class StoreTests: Sendable {
    let store = Store<State> { action, state in
        var state = state ?? .defaultState
        
        switch action {
        case Action.incrementAge(let age):
            state.user?.age = age
        default:
            break
        }
        
        return state
    }
    
    let ages = Mutex<[Int]>([])
    
    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
    func dispatchUpdatesState() async throws {
        let state = await store.dispatch(action: Action.incrementAge(36))
        #expect(state.user?.age == 36)
    }
    
    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
    func dispatchRemovesDuplicateState() async throws {
        let expectedAges: [Int] = [35, 36, 37]
        
        let agesTask = Task {
            try await store.sequence(for: \.user?.age)
            .compacted()
            .reductions(into: [Int](), { accumulator, age in
                accumulator.append(age)
            })
            .first { @Sendable ages in
                ages == expectedAges
            }
        }
        
        Task {
            // Due to the async nature of `agesTask` we need to delay briefly in order for it to begin iteration.
            try await Task.sleep(for: .milliseconds(16))
            
            await store.dispatch(action: Action.incrementAge(36))
            // Intentionally repeat the number from above to ensure it doesn't end up being repeated by the store.
            await store.dispatch(action: Action.incrementAge(36))
            await store.dispatch(action: Action.incrementAge(37))
        }
        
        #expect(try await agesTask.value == expectedAges)
    }
    
//    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
//    func dispatchNotifiesKeyPathObservers() async throws {
//        let newAge = store.state.value.user?.age
//        
//        async let age = store.sequence(for: \.user?.age)
//            .first { value in
//                value == newAge
//            }
//        
//        async let state = store.dispatch(action: Action.incrementAge(newAge))
//        
//        #expect(try await state.user?.age == newAge)
//        #expect(try await age == newAge)
//    }
    
//    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
//    func dispatchNotifiesObserverOfDifferentBranch() async throws {
//        async let address = store.sequence(for: \.user?.address, reactingTo: \.user?.age)
//            .dropFirst()
//            .first { @Sendable date in
//                true
//            }
//        
//        // Sleep, otherwise store.sequence and store.dispatch will race, not giving sequence enough time to get registered first and drop the first element which will cause this test to hang because the sequence above is looking for two values to be emitted, the first one that's naturally returned when subscribing and the second one that is returned by dispatching Action.incrementAge.
//        try await Task.sleep(for: .milliseconds(16))
//        
//        let state = await store.dispatch(action: Action.incrementAge(36))
//        
//        #expect(try await address??.city == "Cupertino")
//        #expect(try await state.user?.age == 36)
//    }
    
    @Test(.tags(.dispatch), .timeLimit(.minutes(1)))
    func sequenceImmediatelySendsCurrentValue() async throws {
        let value = try await store.sequence(for: \.user?.age).first { @Sendable _ in true }
        #expect(value == 35)
    }
}
