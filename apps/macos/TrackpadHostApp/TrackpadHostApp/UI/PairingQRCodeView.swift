import AppKit
import CoreImage
import SwiftUI

struct PairingQRCodeView: View {
    let message: String
    let endpointText: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let image = PairingQRCodeImageFactory.makeImage(from: message, size: 176) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 176, height: 176)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .overlay(Text("QR unavailable").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Scan to Pair")
                    .font(.headline)

                Text(endpointText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("Open the iOS app and scan this code to fill the host, port, and pairing code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum PairingQRCodeImageFactory {
    private static let context = CIContext()

    static func makeImage(from message: String, size: CGFloat) -> NSImage? {
        guard let data = message.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scale = size / max(outputImage.extent.width, outputImage.extent.height)
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
