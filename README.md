# ConnectivityKit
NWPathMonitor wrapper

Usage:

```swift
import SwiftUI

@main
struct MyApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connectivityObject: ConnectivityObject
    
    init() {
        let connectivity = Connectivity()
        _connectivityObject = StateObject(
            wrappedValue: ConnectivityObject(connectivity: connectivity)
        )
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectivityObject)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                connectivityObject.start()
                
            case .background, .inactive:
                connectivityObject.stop()
                
            @unknown default:
                break
            }
        }
    }
}

struct RootView: View {
    
    @EnvironmentObject var connectivity: ConnectivityObject
    
    var body: some View {
        ContentView()
            .overlay(alignment: .top) {
                if let state = connectivity.state {
                    NetworkBanner(state: state)
                }
            }
            .onChange(of: connectivity.state) { state in
                guard let state else { return }
                
                if state.isWifi {
                    // Wi-Fi
                } else {
                    // не Wi-Fi
                }
            }
    }
}
```
