import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func magnifyScrollDeltaQuantizerMapsSpreadToZoomInWheelDelta() {
    var quantizer = MagnifyScrollDeltaQuantizer()

    let delta = quantizer.integerDelta(magnification: 0.125, phase: .began)

    #expect(delta == 45)
}

@Test func magnifyScrollDeltaQuantizerMapsPinchToZoomOutWheelDelta() {
    var quantizer = MagnifyScrollDeltaQuantizer()

    let delta = quantizer.integerDelta(magnification: -0.125, phase: .began)

    #expect(delta == -45)
}

@Test func magnifyScrollDeltaQuantizerCarriesSubpixelResidualAndResetsOnEnd() {
    var quantizer = MagnifyScrollDeltaQuantizer()

    let first = quantizer.integerDelta(magnification: 0.001, phase: .began)
    let second = quantizer.integerDelta(magnification: 0.002, phase: .changed)
    let ended = quantizer.integerDelta(magnification: 0, phase: .ended)
    let afterEnd = quantizer.integerDelta(magnification: 0.001, phase: .began)

    #expect(first == 0)
    #expect(second == 1)
    #expect(ended == 0)
    #expect(afterEnd == 0)
}
