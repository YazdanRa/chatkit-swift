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

    func testComposerRendersDisclaimerBelowControls() throws {
        let composerView = try readRepositoryFile("Sources/ChatKitSwift/ChatKitComposerView.swift")

        XCTAssertTrue(composerView.contains("if let disclaimer = session.options.disclaimer"))
        XCTAssertTrue(composerView.contains("ChatKitDisclaimerView(disclaimer: disclaimer)"))
    }

    func testHistoryRenamePresentsEditableTitleBeforeUpdatingThread() throws {
        let historyView = try readRepositoryFile("Sources/ChatKitSwift/ChatKitHistoryView.swift")

        XCTAssertTrue(historyView.contains("TextField(\"Thread title\""))
        XCTAssertTrue(historyView.contains("updateThreadTitle"))
    }

    func testComposerAllowsSendingUploadedAttachmentsWithoutText() throws {
        let composerView = try readRepositoryFile("Sources/ChatKitSwift/ChatKitComposerView.swift")

        XCTAssertTrue(composerView.contains("!session.composer.attachments.isEmpty"))
    }

    func testDemoDoesNotConfigureOpenAIAPIKeysInClientApp() throws {
        let demoConfiguration = try readRepositoryFile("Example/ChatKitSwiftDemo/ChatKitSwiftDemo/BackendHostedChatKitConfiguration.swift")
        let demoReadme = try readRepositoryFile("Example/ChatKitSwiftDemo/README.md")
        let project = try readRepositoryFile("Example/ChatKitSwiftDemo/project.yml")
        let generatedProject = try readRepositoryFile("Example/ChatKitSwiftDemo/ChatKitSwiftDemo.xcodeproj/project.pbxproj")

        XCTAssertFalse(demoConfiguration.contains("OPENAI_API_KEY"))
        XCTAssertFalse(demoConfiguration.contains("api.openai.com/v1/chatkit/sessions"))
        XCTAssertFalse(project.contains("Copy Local Env"))
        XCTAssertFalse(generatedProject.contains("Copy Local Env"))
        XCTAssertTrue(demoReadme.contains("OPENAI_CHATKIT_SESSION_ENDPOINT"))
        XCTAssertTrue(demoReadme.contains("Do not put an OpenAI API key in the demo app"))
    }

    func testReadmeIncludesChatKitJS17ParityMatrix() throws {
        let readme = try readRepositoryFile("README.md")

        XCTAssertTrue(readme.contains("## ChatKit.js 1.7.0 Parity"))
        XCTAssertTrue(readme.contains("| JS surface | Swift status | Notes |"))
        XCTAssertTrue(readme.contains("setComposerValue"))
        XCTAssertTrue(readme.contains("selectedToolId"))
        XCTAssertTrue(readme.contains("chatkit.tool.change"))
        XCTAssertTrue(readme.contains("chatkit.thread.load.end"))
        XCTAssertTrue(readme.contains("threads.create_from_shared"))
        XCTAssertTrue(readme.contains("assistant_message.content_part.inline_widget_added"))
        XCTAssertTrue(readme.contains("CSS bundle parity note"))
        XCTAssertTrue(readme.contains("index-D9b2ZX6j.css"))
        XCTAssertTrue(readme.contains("src_1dg3fzj._.js"))
    }

    func testWidgetRendererKeepsGeneratedFixtureParityDetailsVisible() throws {
        let widgetView = try readRepositoryFile("Sources/ChatKitSwift/ChatKitWidgetView.swift")

        XCTAssertTrue(widgetView.contains("ChatKitWidgetMetrics.cardMaxWidth(node.string(\"size\"))"))
        XCTAssertTrue(widgetView.contains(".frame(maxWidth: node.hasSpacerChildren ? .infinity : nil"))
        XCTAssertTrue(widgetView.contains(".fixedSize(horizontal: parentType == \"Row\" && !node.hasSpacerChildren, vertical: false)"))
        XCTAssertTrue(widgetView.contains(".layoutPriority(parentType == \"Row\" ? 1 : 0)"))
        XCTAssertTrue(widgetView.contains("Image(systemName: \"xmark\")"))
        XCTAssertTrue(widgetView.contains("ChatKitWidgetMetrics.date(from: value)"))
        XCTAssertTrue(widgetView.contains("node.heightPercentage.map"))
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
