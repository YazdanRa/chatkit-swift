import XCTest

final class ChatKitTextualRenderingTests: XCTestCase {
    func testPackageDeclaresTextualPlatformRequirements() throws {
        let package = try readRepositoryFile("Package.swift")

        XCTAssertTrue(package.contains(".iOS(.v18)"))
        XCTAssertTrue(package.contains(".macOS(.v15)"))
        XCTAssertTrue(package.contains(".visionOS(.v2)"))
    }

    func testPackageDependsOnTextualForChatKitTarget() throws {
        let package = try readRepositoryFile("Package.swift")

        XCTAssertTrue(package.contains(#".package(url: "https://github.com/gonzalezreal/textual", from: "0.3.1")"#))
        XCTAssertTrue(package.contains(#".product(name: "Textual", package: "textual")"#))
    }

    func testAssistantResponsesUseTextualWithoutChangingWidgets() throws {
        let rowView = try readRepositoryFile("Sources/ChatKitSwift/ChatKitMessageRowView.swift")

        XCTAssertTrue(rowView.contains("ChatKitAssistantResponseTextView(markdown: content.text)"))
        XCTAssertTrue(rowView.contains("ChatKitWidgetView(item: widget, session: session)"))
    }

    private func readRepositoryFile(_ path: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot.appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
