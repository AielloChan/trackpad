import Foundation

public struct PairingQRCodePayload: Equatable, Sendable {
    public enum ParseError: Error, Equatable, Sendable {
        case unsupportedScheme
        case unsupportedHost
        case missingField(String)
        case invalidVersion(String)
        case invalidPort(String)
    }

    public static let currentVersion = 1
    public static let urlScheme = "trackpad"
    public static let urlHost = "pair"
    public static let lanTCPTransport = "lan-tcp"

    public let version: Int
    public let transport: String
    public let host: String
    public let port: UInt16
    public let pairingCode: String
    public let serviceName: String

    public init(
        version: Int = Self.currentVersion,
        transport: String = Self.lanTCPTransport,
        host: String,
        port: UInt16,
        pairingCode: String,
        serviceName: String
    ) {
        self.version = version
        self.transport = transport
        self.host = host
        self.port = port
        self.pairingCode = pairingCode
        self.serviceName = serviceName
    }

    public var urlString: String {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = Self.urlHost
        components.queryItems = [
            URLQueryItem(name: "v", value: String(version)),
            URLQueryItem(name: "transport", value: transport),
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "code", value: pairingCode),
            URLQueryItem(name: "name", value: serviceName),
        ]

        return components.url?.absoluteString ?? ""
    }

    public init(urlString: String) throws {
        guard let components = URLComponents(string: urlString),
              components.scheme == Self.urlScheme else {
            throw ParseError.unsupportedScheme
        }

        guard components.host == Self.urlHost else {
            throw ParseError.unsupportedHost
        }

        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        let versionText = try Self.required("v", in: items)
        guard let version = Int(versionText), version == Self.currentVersion else {
            throw ParseError.invalidVersion(versionText)
        }

        let portText = try Self.required("port", in: items)
        guard let portValue = UInt16(portText) else {
            throw ParseError.invalidPort(portText)
        }

        self.version = version
        self.transport = try Self.required("transport", in: items)
        self.host = try Self.required("host", in: items)
        self.port = portValue
        self.pairingCode = try Self.required("code", in: items)
        self.serviceName = try Self.required("name", in: items)
    }

    private static func required(_ key: String, in items: [String: String]) throws -> String {
        guard let value = items[key], !value.isEmpty else {
            throw ParseError.missingField(key)
        }

        return value
    }
}
