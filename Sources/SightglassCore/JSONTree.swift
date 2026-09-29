import Foundation

/// A row in the Configure window's key tree.
public struct JSONTreeNode: Identifiable, Equatable, Sendable {
    public var id: String
    public var path: FieldPath
    public var title: String
    public var summary: String
    /// The value for leaves; nil for containers and "… N more" rows.
    public var leafValue: JSONValue?
    /// Child rows for containers; nil for leaves and "… N more" rows.
    public var children: [JSONTreeNode]?
}

public enum JSONTree {
    public static let defaultArrayLimit = 100

    /// Top-level rows for `root`. Object keys are sorted (JSONSerialization
    /// doesn't keep file order); arrays show at most `arrayLimit` elements
    /// followed by a "… N more" row.
    public static func nodes(for root: JSONValue, arrayLimit: Int = defaultArrayLimit) -> [JSONTreeNode] {
        if root.isContainer {
            return children(of: root, at: .root, arrayLimit: arrayLimit)
        }
        return [node(for: root, at: .root, title: "(value)", arrayLimit: arrayLimit)]
    }

    /// Leaves holding numbers (or numeric strings), within the same limits.
    public static func numericLeafPaths(in root: JSONValue?, arrayLimit: Int = defaultArrayLimit) -> [FieldPath] {
        guard let root else { return [] }
        var paths: [FieldPath] = []
        func visit(_ nodes: [JSONTreeNode]) {
            for node in nodes {
                if node.leafValue?.doubleValue != nil { paths.append(node.path) }
                visit(node.children ?? [])
            }
        }
        visit(nodes(for: root, arrayLimit: arrayLimit))
        return paths
    }

    private static func children(of value: JSONValue, at path: FieldPath, arrayLimit: Int) -> [JSONTreeNode] {
        switch value {
        case .object(let object):
            return object.keys.sorted().map { key in
                node(for: object[key] ?? .null, at: path.appending(.key(key)), title: key, arrayLimit: arrayLimit)
            }
        case .array(let array):
            var nodes = array.prefix(arrayLimit).enumerated().map { index, element in
                node(for: element, at: path.appending(.index(index)), title: "[\(index)]", arrayLimit: arrayLimit)
            }
            if array.count > arrayLimit {
                nodes.append(JSONTreeNode(
                    id: "\(path)#more", path: path, title: "… \(array.count - arrayLimit) more",
                    summary: "", leafValue: nil, children: nil
                ))
            }
            return nodes
        default:
            return []
        }
    }

    private static func node(for value: JSONValue, at path: FieldPath, title: String, arrayLimit: Int) -> JSONTreeNode {
        JSONTreeNode(
            id: path.description,
            path: path,
            title: title,
            summary: value.displayString,
            leafValue: value.isContainer ? nil : value,
            children: value.isContainer ? children(of: value, at: path, arrayLimit: arrayLimit) : nil
        )
    }
}
