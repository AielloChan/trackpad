import SwiftUI

struct ConfigurationValueField: View {
    @Binding var value: Double

    let range: ClosedRange<Double>
    let fractionDigits: Int

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .frame(width: 76)
            .focused($isFocused)
            .onAppear {
                syncText()
            }
            .onChange(of: value) { _, _ in
                if !isFocused {
                    syncText()
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    return
                }

                applyText()
            }
            .onSubmit {
                applyText()
            }
    }

    private func applyText() {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let parsed = Double(normalized), parsed.isFinite else {
            syncText()
            return
        }

        value = min(max(parsed, range.lowerBound), range.upperBound)
        syncText()
    }

    private func syncText() {
        text = String(format: "%.\(fractionDigits)f", value)
    }
}
