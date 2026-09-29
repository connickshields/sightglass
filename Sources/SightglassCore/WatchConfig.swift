import Foundation

/// Settings for one watched file.
public struct WatchConfig: Codable, Hashable, Identifiable, Sendable {
    public static let defaultStaleAfter: TimeInterval = 300

    public var id: UUID
    /// Absolute path to the watched file.
    public var path: String
    public var name: String
    /// Rendered left to right in the menu bar, in this order.
    public var fields: [FieldConfig]
    /// Seconds without changes before the watch is stale; nil turns it off.
    public var staleAfter: TimeInterval?

    public init(
        id: UUID = UUID(),
        path: String,
        name: String? = nil,
        fields: [FieldConfig] = [],
        staleAfter: TimeInterval? = WatchConfig.defaultStaleAfter
    ) {
        self.id = id
        self.path = path
        self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
        self.fields = fields
        self.staleAfter = staleAfter
    }

    public var url: URL { URL(fileURLWithPath: path) }

    /// Paths whose numeric history should be recorded.
    public var trackedPaths: Set<FieldPath> { Set(fields.map(\.path)) }
}
