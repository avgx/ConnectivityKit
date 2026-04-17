import Foundation
import Network

public actor Connectivity {
    
    public struct State: Equatable, Sendable, CustomStringConvertible {
        
        public enum Interface: String, Sendable, Equatable {
            case wifi
            case cellular
            case wired
            case loopback
            case other
        }
        
        public let isOnline: Bool
        public let interface: Interface?
        public let ipv4: String?
        
        public var isWifi: Bool { interface == .wifi }
        
        public var description: String {
            "\(isOnline ? "Online" : "Offline") on \(ipv4 ?? "noip") \(interface?.rawValue ?? "unknown")"
        }
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Connectivity")
    
    private let ipv4Resolver: IPv4Resolver
    
    private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]
    private var lastState: State?
    private var pendingTask: Task<Void, Never>?
    private var isStarted = false
    
    public init() {
        self.ipv4Resolver = IPv4Resolver()
    }
    
    // MARK: - Public
    
    public func stream() -> AsyncStream<State> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
            
            startIfNeeded()
        }
    }
    
    public func start() {
        startIfNeeded()
    }
    
    public func stop() {
        monitor.cancel()
        pendingTask?.cancel()
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
        isStarted = false
    }
    
    // MARK: - Private
    
    private func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handle(path) }
        }
        
        monitor.start(queue: queue)
    }
    
    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
        
        if continuations.isEmpty {
            stop()
        }
    }
    
    private func handle(_ path: NWPath) {
        pendingTask?.cancel()
        
        pendingTask = Task {
            let ipv4 = await ipv4Resolver.resolve(from: path)
            
            let newState = State(
                isOnline: path.status == .satisfied,
                interface: mapInterface(activeInterface(path)),
                ipv4: ipv4
            )
            
            guard newState != self.lastState else { return }
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            guard newState != self.lastState else { return }
            
            self.lastState = newState
            broadcast(newState)
        }
    }
    
    private func broadcast(_ state: State) {
        for c in continuations.values {
            c.yield(state)
        }
    }
    
    private func activeInterface(_ path: NWPath) -> NWInterface.InterfaceType? {
        path.availableInterfaces.first {
            path.usesInterfaceType($0.type)
        }?.type
    }
    
    private func mapInterface(_ type: NWInterface.InterfaceType?) -> State.Interface? {
        switch type {
        case .wifi: return .wifi
        case .cellular: return .cellular
        case .wiredEthernet: return .wired
        case .loopback: return .loopback
        case .other: return .other
        case nil: return nil
        @unknown default: return .other
        }
    }
}


actor IPv4Resolver {
    
    func resolve(from path: NWPath) -> String? {
        for interface in path.availableInterfaces {
            if let ip = interface.ipv4 {
                return ip
            }
        }
        return nil
    }
}

// MARK: - Low level

private extension NWInterface {
    
    func address(family: Int32) -> String? {
        var result: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            
            guard interface.ifa_addr.pointee.sa_family == UInt8(family) else { continue }
            guard name == String(cString: interface.ifa_name) else { continue }
            
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            
            /// This code is warning now `result = String(cString: host)`.
            /// Complicating...
            if let end = host.firstIndex(of: 0) {
                result = String(
                    decoding: host[..<end].map { UInt8(bitPattern: $0) },
                    as: UTF8.self
                )
            }
        }
        
        return result
    }
    
    var ipv4: String? { address(family: AF_INET) }
}
