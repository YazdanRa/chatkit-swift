import ChatKitSwift
import SwiftUI

struct ChatScreen: View {
    private let optionsResult: Result<ChatKitOptions, Error>

    init(configuration: BackendHostedChatKitConfiguration = .init()) {
        optionsResult = configuration.options()
    }

    var body: some View {
        switch optionsResult {
        case let .success(options):
            DemoChatSurface(options: options)
        case let .failure(error):
            ConfigurationErrorView(message: error.localizedDescription)
        }
    }
}

private struct DemoChatSurface: View {
    @State private var session: ChatKitSession
    @State private var sheet: DemoSheet?

    @MainActor
    init(options: ChatKitOptions) {
        var options = options
        options.usesNavigationStack = false
        _session = State(initialValue: ChatKitSession(options: options))
    }

    var body: some View {
        NavigationStack {
            ChatKitView(session: session)
                .navigationTitle(session.options.frameTitle)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("ChatKit Options", systemImage: "slider.horizontal.3") {
                            sheet = .options(.init(options: session.options))
                        }
                        .labelStyle(.iconOnly)
                    }
                }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .options(draft):
                DemoChatKitOptionsSheet(draft: draft) { draft in
                    session.setOptions(draft.applying(to: session.options))
                }
            }
        }
    }
}

private enum DemoSheet: Identifiable {
    case options(DemoChatKitOptionsDraft)

    var id: String {
        switch self {
        case .options:
            "options"
        }
    }
}

private struct DemoChatKitOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DemoChatKitOptionsDraft
    let onSave: (DemoChatKitOptionsDraft) -> Void

    init(draft: DemoChatKitOptionsDraft, onSave: @escaping (DemoChatKitOptionsDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                promptsSection
                featuresSection
                composerSection
                advancedSection
            }
            .navigationTitle("ChatKit Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Color scheme", selection: $draft.colorScheme) {
                ForEach(DemoChatKitOptionsDraft.colorSchemes, id: \.rawValue) { colorScheme in
                    Text(colorScheme.rawValue.capitalized).tag(colorScheme)
                }
            }

            Picker("Accent", selection: $draft.accent) {
                ForEach(DemoAccentPreset.allCases) { accent in
                    Label(accent.title, systemImage: accent.symbol).tag(accent)
                }
            }

            Picker("Surface", selection: $draft.surface) {
                ForEach(DemoSurfacePreset.allCases) { surface in
                    Label(surface.title, systemImage: surface.symbol).tag(surface)
                }
            }

            Picker("Radius", selection: $draft.radius) {
                ForEach(DemoChatKitOptionsDraft.radii, id: \.rawValue) { radius in
                    Text(radius.rawValue.capitalized).tag(radius)
                }
            }

            Picker("Density", selection: $draft.density) {
                ForEach(DemoChatKitOptionsDraft.densities, id: \.rawValue) { density in
                    Text(density.rawValue.capitalized).tag(density)
                }
            }

            Stepper(value: $draft.baseFontSize, in: 14 ... 22) {
                Label("Base font: \(draft.baseFontSize) pt", systemImage: "textformat.size")
            }

            Toggle(isOn: $draft.glassEffect) {
                Label("Liquid glass", systemImage: "circle.dashed")
            }
        } header: {
            Label("Appearance", systemImage: "paintpalette")
        }
    }

    private var promptsSection: some View {
        Section {
            TextField("Greeting", text: $draft.greeting, axis: .vertical)
                .lineLimit(2 ... 4)

            Picker("Example prompts", selection: $draft.promptPreset) {
                ForEach(DemoPromptPreset.allCases) { preset in
                    Label(preset.title, systemImage: preset.symbol).tag(preset)
                }
            }
        } header: {
            Label("Start screen", systemImage: "text.bubble")
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $draft.headerEnabled) {
                Label("Header", systemImage: "rectangle.topthird.inset.filled")
            }

            Toggle(isOn: $draft.historyEnabled) {
                Label("Thread history", systemImage: "sidebar.left")
            }

            if draft.historyEnabled {
                Toggle(isOn: $draft.historyRenameEnabled) {
                    Label("Rename threads", systemImage: "pencil")
                }

                Toggle(isOn: $draft.historyDeleteEnabled) {
                    Label("Delete threads", systemImage: "trash")
                }
            }

            Toggle(isOn: $draft.feedbackEnabled) {
                Label("Feedback actions", systemImage: "hand.thumbsup")
            }

            Toggle(isOn: $draft.retryEnabled) {
                Label("Retry action", systemImage: "arrow.clockwise")
            }

            Toggle(isOn: $draft.autoScrollEnabled) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
        } header: {
            Label("Features", systemImage: "switch.2")
        }
    }

    private var composerSection: some View {
        Section {
            TextField("Placeholder", text: $draft.placeholder)

            Toggle(isOn: $draft.attachmentsEnabled) {
                Label("Attachments", systemImage: "paperclip")
            }

            Toggle(isOn: $draft.dictationEnabled) {
                Label("Dictation", systemImage: "mic")
            }

            Toggle(isOn: $draft.toolsEnabled) {
                Label("Tool picker", systemImage: "wrench.and.screwdriver")
            }

            Toggle(isOn: $draft.modelsEnabled) {
                Label("Model picker", systemImage: "cpu")
            }

            Toggle(isOn: $draft.entitiesEnabled) {
                Label("Entity search", systemImage: "at")
            }
        } header: {
            Label("Composer", systemImage: "square.and.pencil")
        }
    }

    private var advancedSection: some View {
        Section {
            Toggle(isOn: $draft.disclaimerEnabled) {
                Label("Disclaimer", systemImage: "info.circle")
            }

            Toggle(isOn: $draft.clientToolEnabled) {
                Label("Client tool callback", systemImage: "hammer")
            }

            Toggle(isOn: $draft.widgetActionsEnabled) {
                Label("Widget action callback", systemImage: "rectangle.3.group")
            }
        } header: {
            Label("Compatibility", systemImage: "shippingbox")
        } footer: {
            Text("Save replaces the live demo session's ChatKitOptions. Cancel leaves the current options unchanged.")
        }
    }
}

private struct DemoChatKitOptionsDraft: Identifiable {
    static let colorSchemes: [ChatKitTheme.ColorScheme] = [.system, .light, .dark]
    static let radii: [ChatKitTheme.Radius] = [.pill, .round, .soft, .sharp]
    static let densities: [ChatKitTheme.Density] = [.compact, .normal, .spacious]

    let id = UUID()
    var colorScheme: ChatKitTheme.ColorScheme
    var accent: DemoAccentPreset
    var surface: DemoSurfacePreset
    var radius: ChatKitTheme.Radius
    var density: ChatKitTheme.Density
    var baseFontSize: Int
    var glassEffect: Bool
    var greeting: String
    var promptPreset: DemoPromptPreset
    var headerEnabled: Bool
    var historyEnabled: Bool
    var historyRenameEnabled: Bool
    var historyDeleteEnabled: Bool
    var feedbackEnabled: Bool
    var retryEnabled: Bool
    var autoScrollEnabled: Bool
    var placeholder: String
    var attachmentsEnabled: Bool
    var dictationEnabled: Bool
    var toolsEnabled: Bool
    var modelsEnabled: Bool
    var entitiesEnabled: Bool
    var disclaimerEnabled: Bool
    var clientToolEnabled: Bool
    var widgetActionsEnabled: Bool

    init(options: ChatKitOptions) {
        colorScheme = options.theme.colorScheme
        accent = .init(theme: options.theme)
        surface = .init(theme: options.theme)
        radius = options.theme.radius
        density = options.theme.density
        baseFontSize = options.theme.typography.baseSize ?? 16
        glassEffect = options.glassEffect
        greeting = options.startScreen.greeting
        promptPreset = .init(prompts: options.startScreen.prompts)
        headerEnabled = options.header.enabled
        historyEnabled = options.history.enabled
        historyRenameEnabled = options.history.showRename
        historyDeleteEnabled = options.history.showDelete
        feedbackEnabled = options.threadItemActions.feedback
        retryEnabled = options.threadItemActions.retry
        autoScrollEnabled = options.thread.autoScroll
        placeholder = options.composer.placeholder
        attachmentsEnabled = options.composer.attachments?.enabled == true
        dictationEnabled = options.composer.dictation?.enabled == true
        toolsEnabled = !options.composer.tools.isEmpty
        modelsEnabled = !options.composer.models.isEmpty
        entitiesEnabled = options.entities.showComposerMenu && options.entities.onTagSearch != nil
        disclaimerEnabled = options.disclaimer != nil
        clientToolEnabled = options.onClientTool != nil
        widgetActionsEnabled = options.widgets.onAction != nil
    }

    func applying(to options: ChatKitOptions) -> ChatKitOptions {
        var next = options
        next.theme = .init(
            colorScheme: colorScheme,
            typography: .init(baseSize: baseFontSize),
            radius: radius,
            density: density,
            color: .init(
                accent: .init(primary: accent.hex, level: accent.level),
                surface: surface.chatKitSurface,
            ),
        )
        next.glassEffect = glassEffect
        next.usesNavigationStack = false
        next.header = .init(enabled: headerEnabled, title: .init(enabled: true, text: "ChatKitSwiftDemo"))
        next.history = .init(enabled: historyEnabled, showDelete: historyDeleteEnabled, showRename: historyRenameEnabled)
        next.startScreen = .init(greeting: normalizedGreeting, prompts: promptPreset.prompts)
        next.threadItemActions = .init(feedback: feedbackEnabled, retry: retryEnabled)
        next.composer = .init(
            placeholder: normalizedPlaceholder,
            attachments: attachmentsEnabled ? Self.demoAttachments : nil,
            tools: toolsEnabled ? Self.demoTools : [],
            models: modelsEnabled ? Self.demoModels : [],
            dictation: dictationEnabled ? .init(enabled: true) : nil,
        )
        next.disclaimer = disclaimerEnabled ? .init(text: "AI can make mistakes. Verify important information.", highContrast: false) : nil
        if entitiesEnabled {
            let onTagSearch: @Sendable (String) async throws -> [ChatKitEntity] = { query in
                try await Self.searchDemoEntities(query: query)
            }
            let onClick: @Sendable (ChatKitEntity) -> Void = { entity in
                print("Selected entity: \(entity.id)")
            }
            next.entities = .init(onTagSearch: onTagSearch, showComposerMenu: true, onClick: onClick)
        } else {
            next.entities = .init()
        }

        if widgetActionsEnabled {
            let onAction: @Sendable (ChatKitAction, ChatKitWidgetItem) async throws -> Void = { action, item in
                print("Widget action \(action.type) from \(item.id)")
            }
            next.widgets = .init(onAction: onAction)
        } else {
            next.widgets = .init()
        }

        next.thread = .init(autoScroll: autoScrollEnabled)
        if clientToolEnabled {
            let onClientTool: @Sendable (ChatKitClientToolCall) async throws -> [String: JSONValue] = { toolCall in
                [
                    "handled_by": .string("ChatKitSwiftDemo"),
                    "tool_name": .string(toolCall.name),
                ]
            }
            next.onClientTool = onClientTool
        } else {
            next.onClientTool = nil
        }
        return next
    }

    private var normalizedGreeting: String {
        let trimmed = greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "What can I help with today?" : trimmed
    }

    private var normalizedPlaceholder: String {
        let trimmed = placeholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Message the assistant" : trimmed
    }

    private static let demoAttachments = ChatKitOptions.AttachmentConfiguration(
        enabled: true,
        maxSize: .bytes(25 * 1024 * 1024),
        maxCount: 5,
        accept: [
            "application/pdf": [".pdf"],
            "image/*": [".png", ".jpg", ".jpeg", ".heic"],
            "text/plain": [".txt", ".md"],
        ],
        onRequest: {
            print("Present a native file picker from the host app.")
        },
    )

    private static let demoTools: [ChatKitOptions.ToolOption] = [
        .init(id: "research", label: "Research", icon: "magnifyingglass", shortLabel: "Research", placeholderOverride: "Ask the assistant to research...", pinned: true),
        .init(id: "write", label: "Draft", icon: "square.and.pencil", shortLabel: "Draft"),
        .init(id: "analyze", label: "Analyze", icon: "chart.bar", shortLabel: "Analyze", persistent: true),
    ]

    private static let demoModels: [ChatKitOptions.ModelOption] = [
        .init(id: "gpt-4.1", label: "GPT-4.1", description: "Balanced reasoning and speed.", isDefault: true),
        .init(id: "gpt-4.1-mini", label: "GPT-4.1 mini", description: "Fast responses for lightweight work."),
        .init(id: "o4-mini", label: "o4-mini", description: "Compact reasoning model."),
    ]

    private static func searchDemoEntities(query: String) async throws -> [ChatKitEntity] {
        let entities = [
            ChatKitEntity(title: "ChatKitSwift", id: "chatkitswift", icon: "shippingbox", group: "Projects"),
            ChatKitEntity(title: "OpenAI ChatKit", id: "openai-chatkit", icon: "sparkles", group: "Products"),
            ChatKitEntity(title: "Demo user", id: "demo-user", icon: "person.crop.circle", group: "People"),
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return entities
        }

        return entities.filter { entity in
            entity.title.localizedCaseInsensitiveContains(trimmed) ||
                entity.id.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private enum DemoAccentPreset: String, CaseIterable, Identifiable {
    case openAI
    case blue
    case purple
    case rose
    case slate

    var id: String {
        rawValue
    }

    init(theme: ChatKitTheme) {
        let primary = theme.color.accent?.primary.lowercased()
        self = Self.allCases.first { $0.hex.lowercased() == primary } ?? .openAI
    }

    var title: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        case .rose:
            "Rose"
        case .slate:
            "Slate"
        }
    }

    var symbol: String {
        switch self {
        case .openAI:
            "sparkles"
        case .blue:
            "drop"
        case .purple:
            "circle.hexagongrid"
        case .rose:
            "heart"
        case .slate:
            "square.stack.3d.down.right"
        }
    }

    var hex: String {
        switch self {
        case .openAI:
            "#10A37F"
        case .blue:
            "#2563EB"
        case .purple:
            "#7C3AED"
        case .rose:
            "#E11D48"
        case .slate:
            "#475569"
        }
    }

    var level: Int {
        switch self {
        case .slate:
            1
        default:
            2
        }
    }
}

private enum DemoSurfacePreset: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark
    case ink

    var id: String {
        rawValue
    }

    init(theme: ChatKitTheme) {
        guard let surface = theme.color.surface else {
            self = .automatic
            return
        }

        self = Self.allCases.first { preset in
            preset.chatKitSurface == surface
        } ?? .automatic
    }

    var title: String {
        switch self {
        case .automatic:
            "Automatic"
        case .light:
            "Light canvas"
        case .dark:
            "Dark canvas"
        case .ink:
            "Ink"
        }
    }

    var symbol: String {
        switch self {
        case .automatic:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        case .ink:
            "pencil.and.outline"
        }
    }

    var chatKitSurface: ChatKitTheme.Surface? {
        switch self {
        case .automatic:
            nil
        case .light:
            .init(background: "#F8FAFC", foreground: "#0F172A")
        case .dark:
            .init(background: "#111827", foreground: "#F9FAFB")
        case .ink:
            .init(background: "#F5F5F4", foreground: "#1C1917")
        }
    }
}

private enum DemoPromptPreset: String, CaseIterable, Identifiable {
    case starter
    case product
    case writing
    case support
    case none

    var id: String {
        rawValue
    }

    init(prompts: [ChatKitOptions.StartScreen.Prompt]) {
        self = Self.allCases.first { $0.prompts.map(\.label) == prompts.map(\.label) } ?? (prompts.isEmpty ? .none : .starter)
    }

    var title: String {
        switch self {
        case .starter:
            "Starter"
        case .product:
            "Product"
        case .writing:
            "Writing"
        case .support:
            "Support"
        case .none:
            "None"
        }
    }

    var symbol: String {
        switch self {
        case .starter:
            "sparkles"
        case .product:
            "shippingbox"
        case .writing:
            "pencil"
        case .support:
            "lifepreserver"
        case .none:
            "xmark.circle"
        }
    }

    var prompts: [ChatKitOptions.StartScreen.Prompt] {
        switch self {
        case .starter:
            [
                .init(id: "hello", label: "Test the assistant", prompt: .text("Say hello and briefly describe what you can do."), icon: "sparkles"),
                .init(id: "summarize", label: "Summarize ChatKit", prompt: .text("Summarize the key parts of OpenAI ChatKit."), icon: "doc.text.magnifyingglass"),
            ]
        case .product:
            [
                .init(id: "roadmap", label: "Draft a roadmap", prompt: .text("Create a short product roadmap for a native ChatKit demo."), icon: "map"),
                .init(id: "tradeoffs", label: "Compare tradeoffs", prompt: .text("Compare three implementation tradeoffs for a chat UI settings surface."), icon: "chart.bar"),
            ]
        case .writing:
            [
                .init(id: "rewrite", label: "Rewrite copy", prompt: .text("Rewrite this message in a concise professional tone."), icon: "pencil"),
                .init(id: "outline", label: "Create outline", prompt: .text("Create an outline for a short technical blog post about ChatKitSwift."), icon: "list.bullet.rectangle"),
            ]
        case .support:
            [
                .init(id: "triage", label: "Triage a bug", prompt: .text("Ask me for a bug report and help triage likely causes."), icon: "stethoscope"),
                .init(id: "reply", label: "Draft a reply", prompt: .text("Draft a concise support reply that explains next steps."), icon: "envelope"),
            ]
        case .none:
            []
        }
    }
}

private struct ConfigurationErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("ChatKitSwiftDemo", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text(message)
        }
        .padding()
    }
}
