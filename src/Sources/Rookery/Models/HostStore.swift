import Foundation
import Observation

@Observable
final class HostStore {
    private static let storageKey = "Rookery.hosts.v1"

    var hosts: [HostProfile] {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([HostProfile].self, from: data) {
            self.hosts = decoded
        } else {
            self.hosts = []
        }
    }

    func add(_ host: HostProfile) {
        hosts.append(host)
    }

    func update(_ host: HostProfile) {
        guard let idx = hosts.firstIndex(where: { $0.id == host.id }) else { return }
        hosts[idx] = host
    }

    func remove(id: HostProfile.ID) {
        hosts.removeAll { $0.id == id }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(hosts) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
