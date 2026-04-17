import SwiftUI

@MainActor
public final class ConnectivityObject: ObservableObject {
    
    @Published private(set) var state: Connectivity.State?
    
    private let connectivity: Connectivity
    private var task: Task<Void, Never>?
    
    init(connectivity: Connectivity) {
        self.connectivity = connectivity
    }
    
    func start() {
        guard task == nil else { return }
        
        task = Task {
            for await state in await connectivity.stream() {
                self.state = state
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
        
        Task {
            await connectivity.stop()
        }
    }
}
