import Alamofire
import Foundation

/// Client instances are the gateway to access services.
///
/// Usually you wouldn't instantiate the `Client` class directly, but one
/// of the classes inheriting from `Client`. Such inheriting classes are
/// generated by Lark from WSDL provided by the service. These generated
/// classes contain typed operations as defined in the WSDL.
///
/// However advised against, you could also use a `Client` instance directly
/// to pass messages to a service. Be aware that the API of `Client` might
/// change without further warning.
open class Client {

    /// URL of the service to send the HTTP messages.
    open let endpoint: URL

    /// `Alamofire.SessionManager` that manages the the underlying `URLSession`.
    open let sessionManager: SessionManager

    /// SOAP headers that will be added on every outgoing `Envelope` (message).
    open var headers: [HeaderSerializable] = []

    /// Optional delegate for this client instance.
    open weak var delegate: ClientDelegate? = nil

    /// Instantiates a `Client`.
    ///
    /// - Parameters:
    ///   - endpoint: URL of the service to send the HTTP messages.
    ///   - sessionManager: an `Alamofire.SessionManager` that manages the
    ///     the underlying `URLSession`.
    public init(
        endpoint: URL,
        sessionManager: SessionManager = SessionManager())
    {
        self.endpoint = endpoint
        self.sessionManager = sessionManager
    }

    /// Synchronously call a method on the service.
    ///
    /// - Parameters:
    ///   - action: name of the action to call.
    ///   - serialize: closure that will be called to serialize the request parameters.
    ///   - deserialize: closure that will be called to deserialize the reponse message.
    /// - Returns: the service's response.
    /// - Throws: errors that might occur when serializing, deserializing or in
    ///   the communication with the service. Also it might throw a `Fault` if the
    ///   service was unable to process the request.
    open func call<T>(
        action: URL,
        serialize: @escaping (Envelope) throws -> Envelope,
        deserialize: @escaping (Envelope) throws -> T)
        throws -> DataResponse<T>
    {
        let semaphore = DispatchSemaphore(value: 0)
        var response: DataResponse<T>!
        let request = self.request(action: action, serialize: serialize)
        delegate?.client(self, didSend: request)
        request.responseSOAP(queue: DispatchQueue.global(qos: .default)) {
            response = DataResponse(
                request: $0.request,
                response: $0.response,
                data: $0.data,
                result: $0.result.map { try deserialize($0) },
                timeline: $0.timeline)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        return response
    }

    /// Asynchronously call a method on the service.
    ///
    /// - Parameters:
    ///   - action: name of the action to call.
    ///   - serialize: closure that will be called to serialize the request parameters.
    ///   - deserialize: closure that will be called to deserialize the reponse message.
    ///   - completionHandler: closure that will be called when a response has
    ///     been received and deserialized. If an error occurs, the closure will
    ///     be called with a `Result.failure(Error)` value.
    /// - Returns: an `Alamofire.DataRequest` instance for chaining additional
    ///   response handlers and to facilitate logging.
    open func call<T>(
        action: URL,
        serialize: @escaping (Envelope) throws -> Envelope,
        deserialize: @escaping (Envelope) throws -> T,
        completionHandler: @escaping (Result<T>) -> Void)
        -> DataRequest
    {
        let request = self.request(action: action, serialize: serialize)
        delegate?.client(self, didSend: request)
        return request.responseSOAP {
            do {
                completionHandler(.success(try deserialize($0.result.resolve())))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }

    /// Perform the request and validate the response.
    ///
    /// - Parameters:
    ///   - action: name of the action to call.
    ///   - serialize: closure that will be called to serialize the request parameters.
    /// - Returns: an `Alamofire.DataRequest` instance on which a deserializer 
    ///   can be chained.
    func request(
        action: URL,
        serialize: @escaping (Envelope) throws -> Envelope)
        -> DataRequest
    {
        let call = Call(
            endpoint: endpoint,
            action: action,
            serialize: serialize,
            headers: headers)
        return sessionManager.request(call)
            .validate(contentType: ["text/xml"])
            .validate(statusCode: [200, 500])
            .deserializeFault()
    }
}

/// Client delegate protocol. Can be used to inspect incoming and outgoing messages.
///
/// For example the following example shows how to print incoming and outgoing messages to
/// standard output. You can adapt this code to log full message bodies to your logging 
/// facility. The response completion handler must be scheduled on the global queue if there
/// is no runloop (e.g. CLI applications).
///
/// ```swift
/// class Logger: Lark.ClientDelegate {
///     func client(_ client: Lark.Client, didSend request: Alamofire.DataRequest) {
///         guard let httpRequest = request.request, let identifier = request.task?.taskIdentifier else {
///             return
///         }
///         print("[\(identifier)] > \(httpRequest) \(httpRequest.httpBody)")
///         request.response(queue: DispatchQueue.global(qos: .default)) {
///             guard let httpResponse = $0.response else {
///                 return
///             }
///             print("[\(identifier)] < \(httpResponse.statusCode) \($0.data)")
///         }
///     }
/// }
/// ```
public protocol ClientDelegate: class {

    /// Will be called when a request has been sent. To see the response to the message,
    /// append a response handler; e.g. `request.response { ... }`.
    func client(_: Client, didSend request: DataRequest)
}

struct Call: URLRequestConvertible {
    let endpoint: URL
    let action: URL
    let serialize: (Envelope) throws -> Envelope
    let headers: [HeaderSerializable]

    func asURLRequest() throws -> URLRequest {
        let envelope = try serialize(Envelope())

        for header in headers {
            envelope.header.addChild(try header.serialize())
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue(action.absoluteString, forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body = envelope.document.xmlData
        request.httpBody = body
        request.addValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        return request
    }
}

extension DataRequest {
    @discardableResult
    func responseSOAP(
        queue: DispatchQueue? = DispatchQueue.global(qos: .default),
        completionHandler: @escaping (_ response: DataResponse<Envelope>) -> Void)
        -> Self {
        return response(queue: queue, responseSerializer: EnvelopeDeserializer(), completionHandler: completionHandler)
    }
}
