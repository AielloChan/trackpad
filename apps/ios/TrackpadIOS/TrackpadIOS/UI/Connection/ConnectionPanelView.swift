import SwiftUI

struct ConnectionPanelView: View {
    @ObservedObject var model: TrackpadClientModel
    @State private var isShowingQRCodeScanner = false

    var body: some View {
        VStack(spacing: 10) {
            if !model.discoveredHosts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.discoveredHosts) { host in
                            hostButton(for: host)
                        }
                    }
                }
            }

            TextField("Host", text: $model.host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Port", text: $model.port)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Code", text: $model.pairingCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                statusText
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { isShowingQRCodeScanner = true }) {
                    Label("Scan QR", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.bordered)

                Button(action: { model.connect() }) {
                    Text(connectButtonTitle)
                        .frame(minWidth: 86)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.connectionState == .connecting)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 14)
        .sheet(isPresented: $isShowingQRCodeScanner) {
            QRCodeScannerView(
                onCodeScanned: { message in
                    isShowingQRCodeScanner = false
                    model.connect(usingQRCodeMessage: message)
                },
                onCancel: {
                    isShowingQRCodeScanner = false
                }
            )
            .ignoresSafeArea()
        }
    }

    private var statusText: Text {
        switch model.connectionState {
        case .disconnected:
            Text("Disconnected")
        case .connecting:
            Text("Connecting")
        case .connected:
            Text("Connected")
        case .failed(let message):
            Text(message)
        }
    }

    private var connectButtonTitle: String {
        model.connectionState == .connecting ? "Connecting" : "Connect"
    }

    @ViewBuilder
    private func hostButton(for host: DiscoveredTrackpadHost) -> some View {
        let button = Button(action: { model.select(host) }) {
            Text(host.name)
                .lineLimit(1)
        }

        if host.id == model.selectedHostID {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

#Preview {
    ConnectionPanelView(model: TrackpadClientModel())
        .background(Color.black)
}
