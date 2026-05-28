import SwiftUI
import UIKit

struct TouchSurfaceView: View {
    @StateObject private var model = TrackpadClientModel()

    var body: some View {
        GeometryReader { geometry in
            let topOverlayPadding = min(max(geometry.safeAreaInsets.top, 12), 72)

            ZStack(alignment: .top) {
                TouchSurfaceRepresentable(
                    onTouchBegan: model.touchBegan,
                    onTouchMoved: model.touchMoved,
                    onTouchEnded: model.touchEnded
                )
                .ignoresSafeArea()

                if model.isConnected {
                    connectedBar
                        .padding(.top, topOverlayPadding)
                } else {
                    ConnectionPanelView(model: model)
                        .padding(.top, topOverlayPadding)
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                model.startDiscovery()
#if DEBUG
                model.runDebugAutomationIfRequested()
#endif
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                model.stopDiscovery()
                model.disconnect()
            }
    }

    private var connectedBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)

            Text("Connected")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(latencyText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 46, alignment: .leading)

            Text(rateText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 78, alignment: .leading)

            Text(model.connectionPathLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 74, maxWidth: 128, alignment: .leading)

            Spacer(minLength: 6)

            Button(action: model.disconnect) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Disconnect")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 24)
        .background(.thinMaterial)
    }

    private var latencyText: String {
        guard let latencyMilliseconds = model.latencyMilliseconds else {
            return "-- ms"
        }

        return "\(latencyMilliseconds) ms"
    }

    private var rateText: String {
        guard let touchSampleRateHz = model.touchSampleRateHz,
              let sentEventRateHz = model.sentEventRateHz else {
            return "--/-- Hz"
        }

        return "\(touchSampleRateHz)/\(sentEventRateHz) Hz"
    }
}

#Preview {
    TouchSurfaceView()
}
