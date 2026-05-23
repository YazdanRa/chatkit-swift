import Foundation

public struct ChatKitOptions: Sendable {
    public var api: ChatKitAPI
    public var locale: String?
    public var theme: ChatKitTheme
    public var glassEffect: Bool
    public var usesNavigationStack: Bool
    public var frameTitle: String
    public var initialThread: String?
    public var onClientTool: (@Sendable (ChatKitClientToolCall) async throws -> [String: JSONValue])?
    public var header: Header
    public var history: History
    public var startScreen: StartScreen
    public var threadItemActions: ThreadItemActions
    public var composer: Composer
    public var disclaimer: Disclaimer?
    public var entities: Entities
    public var widgets: Widgets
    public var thread: Thread
    public var events: ChatKitEventHandlers

    public init(
        api: ChatKitAPI,
        locale: String? = nil,
        theme: ChatKitTheme = .init(),
        glassEffect: Bool = true,
        usesNavigationStack: Bool = true,
        frameTitle: String = "Chat",
        initialThread: String? = nil,
        onClientTool: (@Sendable (ChatKitClientToolCall) async throws -> [String: JSONValue])? = nil,
        header: Header = .init(),
        history: History = .init(),
        startScreen: StartScreen = .init(),
        threadItemActions: ThreadItemActions = .init(),
        composer: Composer = .init(),
        disclaimer: Disclaimer? = nil,
        entities: Entities = .init(),
        widgets: Widgets = .init(),
        thread: Thread = .init(),
        events: ChatKitEventHandlers = .init()
    ) {
        self.api = api
        self.locale = locale
        self.theme = theme
        self.glassEffect = glassEffect
        self.usesNavigationStack = usesNavigationStack
        self.frameTitle = frameTitle
        self.initialThread = initialThread
        self.onClientTool = onClientTool
        self.header = header
        self.history = history
        self.startScreen = startScreen
        self.threadItemActions = threadItemActions
        self.composer = composer
        self.disclaimer = disclaimer
        self.entities = entities
        self.widgets = widgets
        self.thread = thread
        self.events = events
    }

    public struct Header: Sendable {
        public var enabled: Bool
        public var title: Title
        public var leftAction: Action?
        public var rightAction: Action?

        public init(enabled: Bool = true, title: Title = .init(), leftAction: Action? = nil, rightAction: Action? = nil) {
            self.enabled = enabled
            self.title = title
            self.leftAction = leftAction
            self.rightAction = rightAction
        }

        public struct Title: Sendable {
            public var enabled: Bool
            public var text: String?

            public init(enabled: Bool = true, text: String? = nil) {
                self.enabled = enabled
                self.text = text
            }
        }

        public struct Action: Sendable {
            public var icon: String
            public var accessibilityLabel: String
            public var perform: @Sendable () -> Void

            public init(icon: String, accessibilityLabel: String, perform: @escaping @Sendable () -> Void) {
                self.icon = icon
                self.accessibilityLabel = accessibilityLabel
                self.perform = perform
            }
        }
    }

    public struct History: Sendable {
        public var enabled: Bool
        public var showDelete: Bool
        public var showRename: Bool

        public init(enabled: Bool = true, showDelete: Bool = true, showRename: Bool = true) {
            self.enabled = enabled
            self.showDelete = showDelete
            self.showRename = showRename
        }
    }

    public struct StartScreen: Sendable {
        public var greeting: String
        public var prompts: [Prompt]

        public init(greeting: String = "What can I help with today?", prompts: [Prompt] = []) {
            self.greeting = greeting
            self.prompts = prompts
        }

        public struct Prompt: Identifiable, Equatable, Sendable {
            public var id: String
            public var label: String
            public var prompt: PromptContent
            public var icon: String?

            public init(id: String = UUID().uuidString, label: String, prompt: PromptContent, icon: String? = nil) {
                self.id = id
                self.label = label
                self.prompt = prompt
                self.icon = icon
            }
        }

        public enum PromptContent: Equatable, Sendable {
            case text(String)
            case content([ChatKitUserMessageContent])
        }
    }

    public struct ThreadItemActions: Sendable {
        public var feedback: Bool
        public var retry: Bool

        public init(feedback: Bool = false, retry: Bool = false) {
            self.feedback = feedback
            self.retry = retry
        }
    }

    public struct Composer: Sendable {
        public var placeholder: String
        public var attachments: AttachmentConfiguration?
        public var tools: [ToolOption]
        public var models: [ModelOption]
        public var dictation: Dictation?

        public init(
            placeholder: String = "Message the AI",
            attachments: AttachmentConfiguration? = nil,
            tools: [ToolOption] = [],
            models: [ModelOption] = [],
            dictation: Dictation? = nil
        ) {
            self.placeholder = placeholder
            self.attachments = attachments
            self.tools = tools
            self.models = models
            self.dictation = dictation
        }
    }

    public struct AttachmentConfiguration: Sendable {
        public var enabled: Bool
        public var maxSize: AttachmentSizeLimit
        public var maxCount: Int
        public var accept: [String: [String]]
        public var onRequest: (@MainActor @Sendable () -> Void)?

        public init(
            enabled: Bool,
            maxSize: AttachmentSizeLimit = .bytes(100 * 1024 * 1024),
            maxCount: Int = 10,
            accept: [String: [String]] = [:],
            onRequest: (@MainActor @Sendable () -> Void)? = nil
        ) {
            self.enabled = enabled
            self.maxSize = maxSize
            self.maxCount = maxCount
            self.accept = accept
            self.onRequest = onRequest
        }
    }

    public enum AttachmentSizeLimit: Equatable, Sendable {
        case bytes(Int)
        case mimeTypeLimits([String: Int])
    }

    public struct Dictation: Sendable {
        public var enabled: Bool

        public init(enabled: Bool) {
            self.enabled = enabled
        }
    }

    public struct ToolOption: Identifiable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var icon: String
        public var shortLabel: String?
        public var placeholderOverride: String?
        public var pinned: Bool
        public var persistent: Bool

        public init(id: String, label: String, icon: String, shortLabel: String? = nil, placeholderOverride: String? = nil, pinned: Bool = false, persistent: Bool = false) {
            self.id = id
            self.label = label
            self.icon = icon
            self.shortLabel = shortLabel
            self.placeholderOverride = placeholderOverride
            self.pinned = pinned
            self.persistent = persistent
        }
    }

    public struct ModelOption: Identifiable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var description: String?
        public var disabled: Bool
        public var isDefault: Bool

        public init(id: String, label: String, description: String? = nil, disabled: Bool = false, isDefault: Bool = false) {
            self.id = id
            self.label = label
            self.description = description
            self.disabled = disabled
            self.isDefault = isDefault
        }
    }

    public struct Disclaimer: Equatable, Sendable {
        public var text: String
        public var highContrast: Bool

        public init(text: String, highContrast: Bool = false) {
            self.text = text
            self.highContrast = highContrast
        }
    }

    public struct Entities: Sendable {
        public var onTagSearch: (@Sendable (String) async throws -> [ChatKitEntity])?
        public var showComposerMenu: Bool
        public var onClick: (@Sendable (ChatKitEntity) -> Void)?
        public var onRequestPreview: (@Sendable (ChatKitEntity) async throws -> ChatKitWidgetNode?)?

        public init(
            onTagSearch: (@Sendable (String) async throws -> [ChatKitEntity])? = nil,
            showComposerMenu: Bool = false,
            onClick: (@Sendable (ChatKitEntity) -> Void)? = nil,
            onRequestPreview: (@Sendable (ChatKitEntity) async throws -> ChatKitWidgetNode?)? = nil
        ) {
            self.onTagSearch = onTagSearch
            self.showComposerMenu = showComposerMenu
            self.onClick = onClick
            self.onRequestPreview = onRequestPreview
        }
    }

    public struct Widgets: Sendable {
        public var onAction: (@Sendable (ChatKitAction, ChatKitWidgetItem) async throws -> Void)?

        public init(onAction: (@Sendable (ChatKitAction, ChatKitWidgetItem) async throws -> Void)? = nil) {
            self.onAction = onAction
        }
    }

    public struct Thread: Sendable {
        public var autoScroll: Bool

        public init(autoScroll: Bool = false) {
            self.autoScroll = autoScroll
        }
    }
}

public struct ChatKitTheme: Equatable, Sendable {
    public var colorScheme: ColorScheme
    public var typography: Typography
    public var radius: Radius
    public var density: Density
    public var color: Color

    public init(colorScheme: ColorScheme = .system, typography: Typography = .init(), radius: Radius = .pill, density: Density = .normal, color: Color = .init()) {
        self.colorScheme = colorScheme
        self.typography = typography
        self.radius = radius
        self.density = density
        self.color = color
    }

    public enum ColorScheme: String, Equatable, Sendable {
        case light
        case dark
        case system
    }

    public enum Radius: String, Equatable, Sendable {
        case pill
        case round
        case soft
        case sharp
    }

    public enum Density: String, Equatable, Sendable {
        case compact
        case normal
        case spacious
    }

    public struct Typography: Equatable, Sendable {
        public var baseSize: Int?
        public var fontFamily: String?
        public var fontFamilyMono: String?
        public var fontSources: [FontSource]

        public init(baseSize: Int? = nil, fontFamily: String? = nil, fontFamilyMono: String? = nil, fontSources: [FontSource] = []) {
            self.baseSize = baseSize
            self.fontFamily = fontFamily
            self.fontFamilyMono = fontFamilyMono
            self.fontSources = fontSources
        }
    }

    public struct FontSource: Equatable, Sendable {
        public var family: String
        public var source: URL
        public var weight: String?
        public var style: String?
        public var display: String?
        public var unicodeRange: String?

        public init(family: String, source: URL, weight: String? = nil, style: String? = nil, display: String? = nil, unicodeRange: String? = nil) {
            self.family = family
            self.source = source
            self.weight = weight
            self.style = style
            self.display = display
            self.unicodeRange = unicodeRange
        }
    }

    public struct Color: Equatable, Sendable {
        public var grayscale: Grayscale?
        public var accent: Accent?
        public var surface: Surface?

        public init(grayscale: Grayscale? = nil, accent: Accent? = nil, surface: Surface? = nil) {
            self.grayscale = grayscale
            self.accent = accent
            self.surface = surface
        }
    }

    public struct Grayscale: Equatable, Sendable {
        public var hue: Double
        public var tint: Int
        public var shade: Int?

        public init(hue: Double, tint: Int, shade: Int? = nil) {
            self.hue = hue
            self.tint = tint
            self.shade = shade
        }
    }

    public struct Accent: Equatable, Sendable {
        public var primary: String
        public var level: Int

        public init(primary: String, level: Int) {
            self.primary = primary
            self.level = level
        }
    }

    public struct Surface: Equatable, Sendable {
        public var background: String
        public var foreground: String

        public init(background: String, foreground: String) {
            self.background = background
            self.foreground = foreground
        }
    }
}

public enum ChatKitAPI: Sendable {
    case custom(ChatKitCustomAPI)
    case hosted(ChatKitHostedAPI)

    public static func custom(url: URL, domainKey: String? = nil, uploadStrategy: ChatKitUploadStrategy? = nil, additionalHeaders: @escaping @Sendable () async throws -> [String: String] = { [:] }) -> ChatKitAPI {
        .custom(.init(url: url, domainKey: domainKey, uploadStrategy: uploadStrategy, additionalHeaders: additionalHeaders))
    }

    public static func hosted(getClientSecret: @escaping @Sendable (_ currentClientSecret: String?) async throws -> String, endpoint: URL = URL(string: "https://api.openai.com/v1/chatkit")!) -> ChatKitAPI {
        .hosted(.init(endpoint: endpoint, getClientSecret: getClientSecret))
    }
}

public struct ChatKitCustomAPI: Sendable {
    public var url: URL
    public var domainKey: String?
    public var uploadStrategy: ChatKitUploadStrategy?
    public var additionalHeaders: @Sendable () async throws -> [String: String]
}

public struct ChatKitHostedAPI: Sendable {
    public var endpoint: URL
    public var getClientSecret: @Sendable (_ currentClientSecret: String?) async throws -> String
}

public enum ChatKitUploadStrategy: Equatable, Sendable {
    case twoPhase
    case direct(uploadURL: URL)
}

public struct ChatKitClientToolCall: Equatable, Sendable {
    public var name: String
    public var params: [String: JSONValue]
}

public struct ChatKitEventHandlers: Sendable {
    public var onReady: (@Sendable () -> Void)?
    public var onError: (@Sendable (ChatKitEvent.ErrorEvent) -> Void)?
    public var onResponseStart: (@Sendable () -> Void)?
    public var onResponseEnd: (@Sendable () -> Void)?
    public var onThreadChange: (@Sendable (String?) -> Void)?
    public var onThreadLoadStart: (@Sendable (String) -> Void)?
    public var onThreadLoadEnd: (@Sendable (String) -> Void)?
    public var onToolChange: (@Sendable (String?) -> Void)?
    public var onLog: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)?
    public var onEffect: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)?
    public var onDeeplink: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)?

    public init(
        onReady: (@Sendable () -> Void)? = nil,
        onError: (@Sendable (ChatKitEvent.ErrorEvent) -> Void)? = nil,
        onResponseStart: (@Sendable () -> Void)? = nil,
        onResponseEnd: (@Sendable () -> Void)? = nil,
        onThreadChange: (@Sendable (String?) -> Void)? = nil,
        onThreadLoadStart: (@Sendable (String) -> Void)? = nil,
        onThreadLoadEnd: (@Sendable (String) -> Void)? = nil,
        onToolChange: (@Sendable (String?) -> Void)? = nil,
        onLog: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)? = nil,
        onEffect: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)? = nil,
        onDeeplink: (@Sendable (_ name: String, _ data: [String: JSONValue]?) -> Void)? = nil
    ) {
        self.onReady = onReady
        self.onError = onError
        self.onResponseStart = onResponseStart
        self.onResponseEnd = onResponseEnd
        self.onThreadChange = onThreadChange
        self.onThreadLoadStart = onThreadLoadStart
        self.onThreadLoadEnd = onThreadLoadEnd
        self.onToolChange = onToolChange
        self.onLog = onLog
        self.onEffect = onEffect
        self.onDeeplink = onDeeplink
    }
}
