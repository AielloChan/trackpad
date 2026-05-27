import SwiftUI

@main
struct TrackpadHostApp: App {
    var body: some Scene {
        WindowGroup {
            HostStatusView()
        }
        .windowResizability(.contentSize)
    }
}

