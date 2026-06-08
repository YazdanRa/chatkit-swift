import AppKit
import ChatKitSwift
import SwiftUI

@main
struct ChatKitWidgetSnapshot {
    static func main() async throws {
        let options: SnapshotOptions
        do {
            options = try SnapshotOptions(arguments: CommandLine.arguments)
        } catch SnapshotError.requestedHelp {
            return
        }
        try await MainActor.run {
            try SnapshotRenderer(options: options).render()
        }
    }
}

private struct SnapshotOptions {
    var fixturesURL: URL
    var outputURL: URL

    init(arguments: [String]) throws {
        var fixtures = "WidgetParity/fixtures/widgets.json"
        var output = ".widget-parity/swift"

        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--fixtures":
                index += 1
                fixtures = try Self.value(at: index, in: arguments, option: "--fixtures")
            case "--output":
                index += 1
                output = try Self.value(at: index, in: arguments, option: "--output")
            case "--help", "-h":
                print(
                    """
                    Usage: swift run ChatKitWidgetSnapshot [--fixtures WidgetParity/fixtures/widgets.json] [--output .widget-parity/swift]

                    Renders native SwiftUI screenshots for each widget parity fixture.
                    """
                )
                throw SnapshotError.requestedHelp
            default:
                throw SnapshotError.invalidArgument(arguments[index])
            }
            index += 1
        }

        fixturesURL = URL(fileURLWithPath: fixtures, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
        outputURL = URL(fileURLWithPath: output, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
    }

    private static func value(at index: Int, in arguments: [String], option: String) throws -> String {
        guard index < arguments.count else {
            throw SnapshotError.missingValue(option)
        }
        return arguments[index]
    }
}

@MainActor
private struct SnapshotRenderer {
    var options: SnapshotOptions

    func render() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)

        let manifest = try loadManifest()
        try FileManager.default.createDirectory(at: options.outputURL, withIntermediateDirectories: true)

        var snapshots: [SnapshotOutput] = []
        for fixture in manifest.fixtures {
            let pngName = "\(fixture.id).png"
            let pngURL = options.outputURL.appending(path: pngName)
            try render(fixture: fixture, to: pngURL)
            snapshots.append(SnapshotOutput(
                id: fixture.id,
                name: fixture.name,
                theme: fixture.theme,
                width: fixture.viewport.width,
                height: fixture.viewport.height,
                threshold: fixture.threshold,
                file: pngName,
            ))
            print("Rendered \(pngURL.path)")
        }

        let output = SnapshotOutputManifest(version: manifest.version, snapshots: snapshots)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)
        try data.write(to: options.outputURL.appending(path: "manifest.json"), options: .atomic)
    }

    private func loadManifest() throws -> WidgetParityManifest {
        let data = try Data(contentsOf: options.fixturesURL)
        return try JSONDecoder().decode(WidgetParityManifest.self, from: data)
    }

    private func render(fixture: WidgetParityFixture, to url: URL) throws {
        let size = CGSize(width: fixture.viewport.width, height: fixture.viewport.height)
        let rootView = SnapshotRoot(fixture: fixture)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw SnapshotError.cannotCreateBitmap(fixture.id)
        }
        representation.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw SnapshotError.cannotCreatePNG(fixture.id)
        }
        try png.write(to: url, options: .atomic)
    }
}

private struct SnapshotRoot: View {
    var fixture: WidgetParityFixture

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            ChatKitWidgetPreview(widget: fixture.widget, theme: fixture.chatKitTheme)
                .frame(width: CGFloat(fixture.viewport.width - 32), alignment: .topLeading)
                .padding(16)
        }
        .frame(width: CGFloat(fixture.viewport.width), height: CGFloat(fixture.viewport.height), alignment: .topLeading)
        .environment(\.colorScheme, fixture.colorScheme)
        .preferredColorScheme(fixture.colorScheme)
    }

    private var background: some View {
        Rectangle()
            .fill(fixture.theme == "dark" ? Color(red: 0.03, green: 0.04, blue: 0.06) : .white)
            .ignoresSafeArea()
    }
}

private struct WidgetParityManifest: Decodable {
    var version: Int
    var fixtures: [WidgetParityFixture]
}

private struct WidgetParityFixture: Decodable {
    var id: String
    var name: String
    var theme: String
    var viewport: WidgetParityViewport
    var threshold: Double
    var widget: ChatKitWidgetNode

    var colorScheme: SwiftUI.ColorScheme {
        theme == "dark" ? .dark : .light
    }

    var chatKitTheme: ChatKitTheme {
        ChatKitTheme(colorScheme: theme == "dark" ? .dark : .light)
    }
}

private struct WidgetParityViewport: Decodable {
    var width: Int
    var height: Int
}

private struct SnapshotOutputManifest: Encodable {
    var version: Int
    var snapshots: [SnapshotOutput]
}

private struct SnapshotOutput: Encodable {
    var id: String
    var name: String
    var theme: String
    var width: Int
    var height: Int
    var threshold: Double
    var file: String
}

private enum SnapshotError: Error, CustomStringConvertible {
    case requestedHelp
    case invalidArgument(String)
    case missingValue(String)
    case cannotCreateBitmap(String)
    case cannotCreatePNG(String)

    var description: String {
        switch self {
        case .requestedHelp:
            "Help requested."
        case let .invalidArgument(argument):
            "Invalid argument: \(argument)"
        case let .missingValue(option):
            "Missing value for \(option)."
        case let .cannotCreateBitmap(id):
            "Cannot create bitmap for fixture \(id)."
        case let .cannotCreatePNG(id):
            "Cannot create PNG for fixture \(id)."
        }
    }
}
