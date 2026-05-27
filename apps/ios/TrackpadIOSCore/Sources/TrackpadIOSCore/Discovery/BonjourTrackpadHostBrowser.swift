import Foundation
import Network

public final class BonjourTrackpadHostBrowser: @unchecked Sendable {
    public typealias UpdateHandler = @Sendable ([DiscoveredTrackpadHost]) -> Void

    private let queue = DispatchQueue(label: "trackpad.ios.bonjour-browser")
    private let updateHandler: UpdateHandler
    private var browser: NWBrowser?

    public init(updateHandler: @escaping UpdateHandler) {
        self.updateHandler = updateHandler
    }

    public func start() {
        guard browser == nil else {
            return
        }

        let browser = NWBrowser(
            for: .bonjour(
                type: TrackpadDiscoveryDefaults.bonjourType,
                domain: nil
            ),
            using: .tcp
        )

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results)
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    public func stop() {
        browser?.cancel()
        browser = nil
        updateHandler([])
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        let hosts = results.compactMap(host(from:)).sorted { first, second in
            first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
        updateHandler(hosts)
    }

    private func host(from result: NWBrowser.Result) -> DiscoveredTrackpadHost? {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return nil
        }

        return DiscoveredTrackpadHost(
            name: name,
            type: type,
            domain: domain.isEmpty ? TrackpadDiscoveryDefaults.bonjourDomain : domain
        )
    }
}
