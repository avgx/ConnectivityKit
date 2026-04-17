import Foundation
import Testing
@testable import ConnectivityKit

@MainActor
@Test
func better_ugly_test_then_no_test() async throws {
    let connectivity = Connectivity()
    let obj = ConnectivityObject(connectivity: connectivity)
    
    Task {
        for await state in await connectivity.stream() {
            print("\(state)")
        }
    }
    
    obj.start()
    
    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
    
    obj.stop()
    print("\(obj.state?.description ?? "-")")
}
