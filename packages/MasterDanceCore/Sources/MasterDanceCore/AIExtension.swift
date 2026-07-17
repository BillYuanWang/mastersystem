public struct AIExtensionRequest: Codable, Equatable, Sendable {
    public var capability: String
    public var context: [String: String]

    public init(capability: String, context: [String: String]) {
        self.capability = capability
        self.context = context
    }
}

public struct AIExtensionResponse: Codable, Equatable, Sendable {
    public var output: String

    public init(output: String) {
        self.output = output
    }
}

public protocol AIExtension: Sendable {
    func perform(_ request: AIExtensionRequest) async throws -> AIExtensionResponse
}
