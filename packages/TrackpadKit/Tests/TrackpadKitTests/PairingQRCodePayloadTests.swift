import Testing
@testable import TrackpadKit

@Test func pairingQRCodePayloadRoundTripsThroughURLString() throws {
    let payload = PairingQRCodePayload(
        host: "192.168.1.20",
        port: 44787,
        pairingCode: "123456",
        serviceName: "Trackpad Host"
    )

    let decoded = try PairingQRCodePayload(urlString: payload.urlString)

    #expect(decoded == payload)
}

@Test func pairingQRCodePayloadRejectsUnsupportedScheme() throws {
    #expect(throws: PairingQRCodePayload.ParseError.unsupportedScheme) {
        try PairingQRCodePayload(urlString: "https://pair?v=1")
    }
}

@Test func pairingQRCodePayloadRejectsMissingHostField() throws {
    #expect(throws: PairingQRCodePayload.ParseError.missingField("host")) {
        try PairingQRCodePayload(
            urlString: "trackpad://pair?v=1&transport=lan-tcp&port=44787&code=123456&name=Trackpad%20Host"
        )
    }
}

@Test func pairingQRCodePayloadRejectsInvalidPort() throws {
    #expect(throws: PairingQRCodePayload.ParseError.invalidPort("99999")) {
        try PairingQRCodePayload(
            urlString: "trackpad://pair?v=1&transport=lan-tcp&host=192.168.1.20&port=99999&code=123456&name=Trackpad%20Host"
        )
    }
}
