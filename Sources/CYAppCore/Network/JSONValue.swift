import Foundation

public enum CYJSONValue: Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([CYJSONValue])
    case object([String: CYJSONValue])
}

extension CYJSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([CYJSONValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: CYJSONValue].self) {
            self = .object(v)
        } else {
            throw DecodingError.typeMismatch(
                CYJSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "无法解码 JSON 值")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        case .array(let v):  try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

extension CYJSONValue: ExpressibleByStringLiteral { public init(stringLiteral value: String) { self = .string(value) } }
extension CYJSONValue: ExpressibleByIntegerLiteral { public init(integerLiteral value: Int) { self = .int(value) } }
extension CYJSONValue: ExpressibleByFloatLiteral { public init(floatLiteral value: Double) { self = .double(value) } }
extension CYJSONValue: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) { self = .bool(value) } }
extension CYJSONValue: ExpressibleByNilLiteral { public init(nilLiteral: ()) { self = .null } }

extension CYJSONValue {
    public var jsonObject: Any {
        switch self {
        case .string(let v): return v
        case .int(let v):    return v
        case .double(let v): return v
        case .bool(let v):   return v
        case .null:          return NSNull()
        case .array(let v):  return v.map { $0.jsonObject }
        case .object(let v): return v.mapValues { $0.jsonObject }
        }
    }

    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var stableDescription: String {
        switch self {
        case .string(let v): return "\"\(v)\""
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        case .null: return "null"
        case .array(let v): return "[\(v.map { $0.stableDescription }.joined(separator: ","))]"
        case .object(let v):
            let sorted = v.keys.sorted().map { "\"\($0)\":\(v[$0]?.stableDescription ?? "null")" }
            return "{\(sorted.joined(separator: ","))}"
        }
    }
}
