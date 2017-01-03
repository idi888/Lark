import Foundation
import Evergreen

public protocol Transport {
    func send(action: URL?, message: Data) throws -> Data
}

public enum HTTPTransportError: Error {
    case notOk(Int, Data)
    case invalidMimeType(String?)
}

open class HTTPTransport: Transport {
    open let endpoint: URL
    open let logger = Evergreen.getLogger("Lark.HTTPTransport")

    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    open func send(action: URL?, message: Data) throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpBody = message
        request.httpMethod = "POST"
        if let action = action {
            request.addValue(action.absoluteString, forHTTPHeaderField: "SOAPAction")
        }
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("\(message.count)", forHTTPHeaderField: "Content-Length")
        logger.debug("Request: " + request.debugDescription + "\n" + (request.allHTTPHeaderFields?.map({"\($0): \($1)"}).joined(separator: "\n") ?? ""))

        var response: URLResponse? = nil
        let data = try NSURLConnection.sendSynchronousRequest(request, returning: &response)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }
        logger.debug("Response: " + httpResponse.debugDescription)
        logger.debug("Response body: " + (String(data: data, encoding: .utf8) ?? "Failed to decode the body as UTF-8 for logging"))
        guard httpResponse.statusCode == 200 else {
            throw HTTPTransportError.notOk(httpResponse.statusCode, data)
        }
        guard httpResponse.mimeType == "text/xml" else {
            throw HTTPTransportError.invalidMimeType(httpResponse.mimeType)
        }
        return data
    }
}
