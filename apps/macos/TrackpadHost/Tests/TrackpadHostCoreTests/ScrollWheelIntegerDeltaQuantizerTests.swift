import Testing
@testable import TrackpadHostCore

@Test func scrollWheelIntegerDeltaQuantizerCarriesSubpixelTailDeltas() {
    var quantizer = ScrollWheelIntegerDeltaQuantizer()

    let first = quantizer.integerDeltas(dx: 0, dy: 0.4, phase: .changed)
    let second = quantizer.integerDeltas(dx: 0, dy: 0.4, phase: .changed)
    let third = quantizer.integerDeltas(dx: 0, dy: 0.4, phase: .changed)

    #expect(first.dy == 0)
    #expect(second.dy == 0)
    #expect(third.dy == 1)
}

@Test func scrollWheelIntegerDeltaQuantizerResetsResidualWhenScrollEnds() {
    var quantizer = ScrollWheelIntegerDeltaQuantizer()

    _ = quantizer.integerDeltas(dx: 0, dy: 0.8, phase: .changed)
    _ = quantizer.integerDeltas(dx: 0, dy: 0, phase: .ended)
    let next = quantizer.integerDeltas(dx: 0, dy: 0.3, phase: .changed)

    #expect(next.dy == 0)
}
