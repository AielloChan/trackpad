import SwiftUI
import TrackpadKit
import TrackpadHostCore

struct HostStatusView: View {
    @StateObject private var model = HostAppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            pairingQRCode

            statusRows

            configurationControls

            HStack {
                Button("Request Permission") {
                    model.requestPermission()
                }

                Button("Request Automation") {
                    model.requestAutomationPermission()
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

            Button("Request Client Logs") {
                model.requestClientLogs()
            }
            .disabled(model.status.authorizedConnectionCount == 0)

            Button("New Pairing Code") {
                model.regeneratePairingCode()
            }
            .disabled(model.status.state == .running || model.status.state == .starting)
        }
        .padding(24)
        .frame(width: 620)
        .onChange(of: model.pointerSpeedMultiplier) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.scrollMomentumAmount) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.scrollMomentumDecayRate) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.scrollMomentumTailWindowMilliseconds) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.tapMaximumDurationMilliseconds) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.tapDragMaximumIntervalMilliseconds) { _, _ in
            model.syncConfigurationFromControls()
        }
        .onChange(of: model.scrollReleaseTapSuppressionMilliseconds) { _, _ in
            model.syncConfigurationFromControls()
        }
    }

    @ViewBuilder
    private var pairingQRCode: some View {
        if let payload = model.pairingQRCodePayload {
            PairingQRCodeView(
                message: payload.message,
                endpointText: "\(payload.host):\(payload.port)"
            )
        } else {
            Text("Pairing QR unavailable. Connect this Mac to a local network and refresh.")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
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
            statusRow("Automation", model.hasAutomationPermission ? "Granted" : "Required for Spaces", model.hasAutomationPermission ? .green : .orange)
            statusRow("Server", model.status.state.rawValue.capitalized, model.status.state == .running ? .green : .secondary)
            statusRow("Pairing Code", model.pairingCode.value, .primary)
            statusRow("Port", model.status.port.map(String.init) ?? "-", .secondary)
            statusRow("Connections", "\(model.status.connectionCount)", .secondary)
            statusRow("Authorized", "\(model.status.authorizedConnectionCount)", .secondary)
            statusRow("Events", "\(model.status.handledEventCount)", .secondary)
            statusRow("Log File", model.logFilePath, .secondary)
            statusRow("Client Logs", clientLogDirectoryPath, .secondary)

            if let clientLogRequestStatus = model.clientLogRequestStatus {
                statusRow("Log Request", clientLogRequestStatus, .secondary)
            }

            if let lastError = model.status.lastError {
                statusRow("Error", lastError, .red)
            }
        }
    }

    private var configurationControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            configurationSlider(
                "Pointer",
                value: $model.pointerSpeedMultiplier,
                range: TrackpadConfigurationLimits.pointerSpeedMultiplier,
                step: 0.1,
                text: String(format: "%.1fx", model.pointerSpeedMultiplier)
            )
            configurationSlider(
                "Momentum",
                value: $model.scrollMomentumAmount,
                range: TrackpadConfigurationLimits.scrollMomentumAmount,
                step: 0.1,
                text: String(format: "%.1fx", model.scrollMomentumAmount)
            )
            configurationSlider(
                "Decel",
                value: $model.scrollMomentumDecayRate,
                range: TrackpadConfigurationLimits.scrollMomentumDecayRate,
                step: 0.005,
                text: String(format: "%.3f", model.scrollMomentumDecayRate)
            )
            configurationSlider(
                "Tail",
                value: $model.scrollMomentumTailWindowMilliseconds,
                range: TrackpadConfigurationLimits.scrollMomentumTailWindowMilliseconds,
                step: 10,
                text: "\(Int(model.scrollMomentumTailWindowMilliseconds.rounded())) ms"
            )
            configurationSlider(
                "Tap",
                value: $model.tapMaximumDurationMilliseconds,
                range: TrackpadConfigurationLimits.tapMaximumDurationMilliseconds,
                step: 10,
                text: "\(Int(model.tapMaximumDurationMilliseconds.rounded())) ms"
            )
            configurationSlider(
                "Drag",
                value: $model.tapDragMaximumIntervalMilliseconds,
                range: TrackpadConfigurationLimits.tapDragMaximumIntervalMilliseconds,
                step: 10,
                text: "\(Int(model.tapDragMaximumIntervalMilliseconds.rounded())) ms"
            )
            configurationSlider(
                "Scroll Guard",
                value: $model.scrollReleaseTapSuppressionMilliseconds,
                range: TrackpadConfigurationLimits.scrollReleaseTapSuppressionMilliseconds,
                step: 10,
                text: "\(Int(model.scrollReleaseTapSuppressionMilliseconds.rounded())) ms"
            )
        }
    }

    private func configurationSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        text: String
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .frame(width: 340)
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
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

    private var clientLogDirectoryPath: String {
        ClientLogUploadWriter.defaultDirectoryURL.path
    }
}

#Preview {
    HostStatusView()
}
