import Foundation
import Network

extension Notification.Name {
    static let networkBecameAvailable = Notification.Name("networkBecameAvailable")
    static let networkBecameUnavailable = Notification.Name("networkBecameUnavailable")
}

/// Monitors network connectivity and posts notifications on status changes
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.pigeonmail.networkmonitor")
    private var wasConnected: Bool = true

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        // .satisfied = fully connected, .requiresConnection = available but needs activation
        // Both states allow network requests on iOS
        let newIsConnected = path.status == .satisfied || path.status == .requiresConnection
        let previouslyConnected = isConnected

        isConnected = newIsConnected
        connectionType = determineConnectionType(path)

        // Post notification when network becomes available
        if newIsConnected && !previouslyConnected {
            NotificationCenter.default.post(name: .networkBecameAvailable, object: nil)
        } else if !newIsConnected && previouslyConnected {
            NotificationCenter.default.post(name: .networkBecameUnavailable, object: nil)
        }

        wasConnected = newIsConnected
    }

    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }
        return .unknown
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
