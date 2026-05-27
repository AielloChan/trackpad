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
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Connected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(latencyText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .leading)

                Text(rateText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 88, alignment: .leading)

                Text(model.connectionPathLabel)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 82, maxWidth: 142, alignment: .leading)

                Spacer()

                Button("Disconnect", action: model.disconnect)
                    .buttonStyle(.bordered)
            }

            tuningSlider(
                title: "Pointer",
                value: $model.pointerSpeedMultiplier,
                range: 0.2...3,
                step: 0.1,
                format: { String(format: "%.1fx", $0) }
            )

            VStack(spacing: 4) {
                tuningSlider(
                    title: "Tap",
                    value: $model.tapMaximumDurationMilliseconds,
                    range: 60...500,
                    step: 10,
                    format: { "\(Int($0.rounded())) ms" }
                )

                tuningSlider(
                    title: "Drag",
                    value: $model.tapDragMaximumIntervalMilliseconds,
                    range: 40...250,
                    step: 10,
                    format: { "\(Int($0.rounded())) ms" }
                )

                tuningSlider(
                    title: "Guard",
                    value: $model.scrollReleaseTapSuppressionMilliseconds,
                    range: 0...250,
                    step: 10,
                    format: { "\(Int($0.rounded())) ms" }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func tuningSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Slider(value: value, in: range, step: step)
                .frame(minWidth: 86)

            Text(format(value.wrappedValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
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
