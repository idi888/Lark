import Foundation

public protocol XMLDeserializable {
    init(deserialize: XMLElement) throws
}

public protocol XMLSerializable {
    func serialize(_ element: XMLElement) throws
}

public enum XMLDeserializationError: Error {
    case noElementWithName(String)
    case cannotDeserialize
}

public enum XMLSerializationError: Error {
    case invalidNamespace(String)
}

public protocol StringDeserializable {
    init(string: String) throws
}

public protocol StringSerializable {
    func serialize() throws -> String
}