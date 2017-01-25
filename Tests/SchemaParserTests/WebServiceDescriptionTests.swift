import XCTest

@testable import Lark
@testable import SchemaParser

class WebServiceDescriptionTests: XCTestCase {
    func deserialize(_ input: String) throws -> WebServiceDescription {
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Inputs")
            .appendingPathComponent(input)
        return try parseWebServiceDefinition(contentsOf: url)
    }

    func qname(_ localName: String) -> QualifiedName {
        return QualifiedName(uri: "http://www.dataaccess.com/webservicesserver/", localName: localName)
    }

    func testNumberConversion() throws {
        let webService = try deserialize("numberconversion.wsdl")
        XCTAssertEqual(webService.bindings.count, 2)
        XCTAssertEqual(webService.bindings.first?.name, qname("NumberConversionSoapBinding"))
        XCTAssertEqual(webService.bindings.map({ $0.operations }).count, 2)

        XCTAssertEqual(webService.messages.count, 4)
        XCTAssertEqual(webService.messages.first?.name, qname("NumberToWordsSoapRequest"))
        XCTAssertEqual(webService.messages.flatMap({ $0.parts }).count, 4)

        XCTAssertEqual(webService.portTypes.count, 1)
        XCTAssertEqual(webService.portTypes.first?.name, qname("NumberConversionSoapType"))
        XCTAssertEqual(webService.portTypes.flatMap({ $0.operations }).count, 2)

        XCTAssertEqual(webService.schema.count, 4)
        XCTAssertEqual(webService.schema.first?.element?.name, qname("NumberToWords"))

        XCTAssertEqual(webService.services.count, 1)
        XCTAssertEqual(webService.services.first?.name, qname("NumberConversion"))
        XCTAssertEqual(webService.services.flatMap({ $0.ports }).count, 2)
    }

    func testImport() throws {
        let webService = try deserialize("import.wsdl")
        XCTAssertEqual(webService.schema.count, 3)
    }

    func testFileNotFound() throws {
        do {
            _ = try deserialize("file_not_found.wsdl")
        } catch let error as NSError where error.code == 260 {
        }
    }

    func testBrokenImport() throws {
        do {
            _ = try deserialize("broken_import.wsdl")
            XCTFail("Parsing WSDL with broken import should fail")
        } catch let error as NSError where error.code == 260 {
        } catch let error as NSError where error.code == -1014 {
            XCTFail("Should have thrown error code 260 (file not found), not -1014 (zero byte resource). Possible cause is that a relative path was not resolved correctly.")
        }
    }
}
