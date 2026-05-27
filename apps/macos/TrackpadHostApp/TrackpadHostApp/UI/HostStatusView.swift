import SwiftUI
import TrackpadHostCore

struct HostStatusView: View {
    @StateObject private var model = HostAppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            statusRows

            HStack {
                Button("Request Permission") {
                    model.requestPermission()
                }

                Button("Refresh") {
                    model.refreshPermission()
                }

                if model.status.state == .running || model.status.state == .starting {
                    Button("Stop Server") {
                        model.stopServer()
                    }
                } else {
                    Button("Start Server") {
                        model.startServer()
                    }
                    .disabled(!model.isTrusted)
                }
            }

            Button("New Pairing Code") {
                model.regeneratePairingCode()
            }
            .disabled(model.status.state == .running || model.status.state == .starting)
        }
        .padding(24)
        .frame(width: 440)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trackpad Host")
                .font(.title2)
                .bold()

            Text("Bonjour: \(HostDefaults.bonjourType)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusRows: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            statusRow("Permission", model.isTrusted ? "Granted" : "Required", model.isTrusted ? .green : .orange)
            statusRow("Server", model.status.state.rawValue.capitalized, model.status.state == .running ? .green : .secondary)
            statusRow("Pairing Code", model.pairingCode.value, .primary)
            statusRow("Port", model.status.port.map(String.init) ?? "-", .secondary)
            statusRow("Connections", "\(model.status.connectionCount)", .secondary)
            statusRow("Authorized", "\(model.status.authorizedConnectionCount)", .secondary)
            statusRow("Events", "\(model.status.handledEventCount)", .secondary)
            statusRow("Log File", model.logFilePath, .secondary)

            if let lastError = model.status.lastError {
                statusRow("Error", lastError, .red)
            }
        }
    }

    private func statusRow(_ label: String, _ value: String, _ color: Color) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(color)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    HostStatusView()
}
