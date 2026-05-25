import SwiftUI

struct ChatKitWidgetView: View {
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    var body: some View {
        ChatKitWidgetNodeView(node: item.widget, item: item, session: session)
    }
}

private struct ChatKitWidgetNodeView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch node.type {
        case "Basic", "Box", "Form":
            directionalStack(defaultDirection: node.type == "Basic" ? node.string("direction") : node.string("direction")) {
                if let status = node.object("status") {
                    ChatKitWidgetStatusView(status: status)
                }
                children
                if node.type == "Form", node.action(named: "onSubmitAction") != nil {
                    widgetButton(label: "Submit", actionKey: "onSubmitAction")
                }
            }
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme)
        case "Row":
            HStack(alignment: node.verticalAlignment, spacing: node.gap) {
                children
            }
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme)
        case "Col":
            VStack(alignment: node.horizontalAlignment, spacing: node.gap) {
                children
            }
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme)
        case "Card":
            VStack(alignment: .leading, spacing: node.gapOrDefault(12)) {
                if let status = node.object("status") {
                    ChatKitWidgetStatusView(status: status)
                }
                if !node.bool("collapsed") {
                    children
                }
                cardActions
            }
            .padding(ChatKitWidgetMetrics.insets(node.raw["padding"], fallback: node.cardPadding))
            .background(node.color("background", colorScheme: colorScheme) ?? Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: node.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: node.cornerRadius)
                    .stroke(node.borderColor(colorScheme: colorScheme) ?? Color.secondary.opacity(0.22), lineWidth: node.borderWidth ?? 1)
            }
        case "ListView":
            VStack(alignment: .leading, spacing: node.gapOrDefault(8)) {
                if let status = node.object("status") {
                    ChatKitWidgetStatusView(status: status)
                }
                ForEach(limitedChildren, id: \.stableID) { child in
                    ChatKitWidgetNodeView(node: child, item: item, session: session)
                }
            }
        case "ListViewItem":
            actionButtonOrContent {
                HStack(alignment: node.verticalAlignment, spacing: node.gapOrDefault(8)) {
                    children
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .padding(.vertical, 6)
        case "Title":
            text(node.value ?? "", font: titleFont, defaultWeight: .semibold)
        case "Caption":
            text(node.value ?? "", font: captionFont, defaultColor: .secondary)
        case "Text":
            text(node.value ?? "", font: textFont)
        case "Markdown":
            ChatKitAssistantResponseTextView(markdown: node.value ?? "")
        case "Badge":
            ChatKitWidgetBadgeView(node: node)
        case "Icon":
            Image(systemName: ChatKitStyle.systemImage(for: node.name ?? node.value ?? "sparkle"))
                .font(ChatKitWidgetMetrics.iconFont(node.string("size")))
                .foregroundStyle(node.color("color", colorScheme: colorScheme) ?? .primary)
                .accessibilityHidden(true)
        case "Image":
            widgetImage
        case "Button":
            widgetButton(label: node.label ?? "Action", actionKey: "onClickAction")
        case "Divider":
            Rectangle()
                .fill(node.color("color", colorScheme: colorScheme) ?? Color.secondary.opacity(0.25))
                .frame(height: ChatKitWidgetMetrics.spacing(node.raw["size"]) ?? 1)
                .padding(.vertical, ChatKitWidgetMetrics.spacing(node.raw["spacing"]) ?? 4)
        case "Spacer":
            Spacer(minLength: ChatKitWidgetMetrics.spacing(node.raw["minSize"]) ?? 8)
        case "Input":
            ChatKitWidgetTextInputView(node: node, item: item, session: session, axis: .horizontal)
        case "Textarea":
            ChatKitWidgetTextInputView(node: node, item: item, session: session, axis: .vertical)
        case "Select":
            ChatKitWidgetSelectView(node: node, item: item, session: session)
        case "DatePicker":
            ChatKitWidgetDatePickerView(node: node, item: item, session: session)
        case "Checkbox":
            ChatKitWidgetCheckboxView(node: node, item: item, session: session)
        case "RadioGroup":
            ChatKitWidgetRadioGroupView(node: node, item: item, session: session)
        case "Label":
            text(node.value ?? node.label ?? "", font: textFont, defaultWeight: node.fontWeight)
        case "Table":
            ChatKitWidgetTableView(node: node, item: item, session: session)
        case "Table.Row":
            HStack(alignment: .top, spacing: 0) {
                children
            }
        case "Table.Cell":
            VStack(alignment: node.horizontalAlignment, spacing: 4) {
                children
            }
            .padding(ChatKitWidgetMetrics.insets(node.raw["padding"], fallback: 8))
            .frame(minWidth: node.number("width").map { CGFloat($0) }, alignment: node.frameAlignment)
        case "Transition":
            children
                .animation(.default, value: node.stableID)
        case "Chart", "BarChart":
            ChatKitWidgetChartView(node: node, colorScheme: colorScheme)
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text(node.type)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                children
            }
        }
    }

    private var children: some View {
        ForEach(node.children, id: \.stableID) { child in
            ChatKitWidgetNodeView(node: child, item: item, session: session)
        }
    }

    private var limitedChildren: [ChatKitWidgetNode] {
        if let limit = node.number("limit") {
            Array(node.children.prefix(Int(limit)))
        } else {
            node.children
        }
    }

    @ViewBuilder
    private var widgetImage: some View {
        if let source = node.source, let url = URL(string: source) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: node.imageContentMode)
                } else if phase.error != nil {
                    Label("Image failed to load", systemImage: "exclamationmark.triangle")
                } else {
                    ProgressView()
                }
            }
            .frame(
                minWidth: node.number("minWidth").map { CGFloat($0) },
                maxWidth: node.number("maxWidth").map { CGFloat($0) } ?? (node.bool("block") ? .infinity : nil),
                minHeight: node.number("minHeight").map { CGFloat($0) },
                maxHeight: node.number("maxHeight").map { CGFloat($0) },
            )
            .clipShape(RoundedRectangle(cornerRadius: node.cornerRadius))
            .overlay {
                if node.bool("frame") {
                    RoundedRectangle(cornerRadius: node.cornerRadius)
                        .stroke(.secondary.opacity(0.25))
                }
            }
            .accessibilityLabel(node.altText ?? "Image")
        }
    }

    @ViewBuilder
    private func widgetButton(label: String, actionKey: String) -> some View {
        let iconStart = node.string("iconStart")
        let iconEnd = node.string("iconEnd")
        let tone = ChatKitWidgetTone(rawValue: node.string("color") ?? (node.string("style") == "primary" ? "primary" : "secondary"))
        let variant = node.string("variant") ?? (node.string("style") == "primary" ? "solid" : "outline")

        Button {
            Task { await performActionIfPossible(node.action(named: actionKey) ?? node.action) }
        } label: {
            HStack(spacing: 6) {
                if let iconStart {
                    Image(systemName: ChatKitStyle.systemImage(for: iconStart))
                        .font(ChatKitWidgetMetrics.iconFont(node.string("iconSize")))
                }
                if !label.isEmpty {
                    Text(label)
                        .lineLimit(1)
                }
                if let iconEnd {
                    Image(systemName: ChatKitStyle.systemImage(for: iconEnd))
                        .font(ChatKitWidgetMetrics.iconFont(node.string("iconSize")))
                }
            }
            .frame(maxWidth: node.bool("block") ? .infinity : nil)
        }
        .controlSize(ChatKitWidgetMetrics.controlSize(node.string("size")))
        .buttonStyle(ChatKitWidgetButtonStyle(variant: variant, tone: tone))
        .clipShape(CapsuleOrRoundedRectangle(pill: node.bool("pill"), radius: node.cornerRadius))
        .disabled(node.isDisabled)
    }

    private var cardActions: some View {
        HStack {
            if let cancel = node.cardAction("cancel") {
                Button(cancel.label) {
                    Task { await performActionIfPossible(cancel.action) }
                }
                .buttonStyle(.bordered)
            }
            if let confirm = node.cardAction("confirm") {
                Button(confirm.label) {
                    Task { await performActionIfPossible(confirm.action) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func directionalStack(defaultDirection: String?, @ViewBuilder content: () -> some View) -> some View {
        if defaultDirection == "row" {
            HStack(alignment: node.verticalAlignment, spacing: node.gap, content: content)
        } else {
            VStack(alignment: node.horizontalAlignment, spacing: node.gap, content: content)
        }
    }

    @ViewBuilder
    private func actionButtonOrContent(@ViewBuilder content: () -> some View) -> some View {
        if node.action != nil {
            Button(action: { Task { await performActionIfPossible(node.action) } }) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func text(_ value: String, font: Font, defaultColor: Color? = nil, defaultWeight: Font.Weight? = nil) -> some View {
        let color = node.color("color", colorScheme: colorScheme) ?? defaultColor
        let text = Text(value)
            .font(font)
            .fontWeight(node.fontWeight ?? defaultWeight)
            .strikethrough(node.bool("lineThrough"))
            .italic(node.bool("italic"))

        if let color {
            text.foregroundStyle(color)
                .multilineTextAlignment(node.textAlignment)
                .lineLimit(node.lineLimit)
        } else {
            text
                .multilineTextAlignment(node.textAlignment)
                .lineLimit(node.lineLimit)
        }
    }

    private var titleFont: Font {
        switch node.string("size") {
        case "sm": .headline
        case "lg": .title2
        case "xl": .title
        case "2xl", "3xl", "4xl", "5xl": .largeTitle
        default: .title3
        }
    }

    private var captionFont: Font {
        switch node.string("size") {
        case "lg": .callout
        case "md": .footnote
        default: .caption
        }
    }

    private var textFont: Font {
        switch node.string("size") {
        case "xs": .caption2
        case "sm": .footnote
        case "lg": .title3
        case "xl": .title2
        default: .body
        }
    }

    private func performActionIfPossible(_ action: ChatKitAction?) async {
        guard let action else {
            return
        }

        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}

private struct ChatKitWidgetBadgeView: View {
    let node: ChatKitWidgetNode

    var body: some View {
        let tone = ChatKitWidgetTone(rawValue: node.string("color") ?? "secondary") ?? .secondary
        Text(node.label ?? node.value ?? "")
            .font(font)
            .fontWeight(.medium)
            .foregroundStyle(foreground(for: tone))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background(for: tone), in: CapsuleOrRoundedRectangle(pill: node.bool("pill"), radius: 8))
            .overlay {
                if node.string("variant") == "outline" {
                    CapsuleOrRoundedRectangle(pill: node.bool("pill"), radius: 8)
                        .stroke(tone.softForeground.opacity(0.45))
                }
            }
    }

    private var font: Font {
        switch node.string("size") {
        case "lg": .callout
        case "sm": .caption2
        default: .footnote
        }
    }

    private var horizontalPadding: CGFloat {
        node.string("size") == "lg" ? 12 : 10
    }

    private var verticalPadding: CGFloat {
        node.string("size") == "lg" ? 7 : 5
    }

    private func foreground(for tone: ChatKitWidgetTone) -> Color {
        node.string("variant") == "solid" ? tone.foreground : tone.softForeground
    }

    private func background(for tone: ChatKitWidgetTone) -> Color {
        switch node.string("variant") {
        case "solid":
            tone.solidBackground
        case "outline":
            .clear
        default:
            tone.softBackground
        }
    }
}

private struct ChatKitWidgetStatusView: View {
    let status: [String: JSONValue]

    var body: some View {
        Label(status["text"]?.stringValue ?? "", systemImage: ChatKitStyle.systemImage(for: status["icon"]?.stringValue ?? "info"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct ChatKitWidgetButtonStyle: ButtonStyle {
    let variant: String
    let tone: ChatKitWidgetTone?

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTone = tone ?? .secondary
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(foreground(tone: resolvedTone))
            .background(background(tone: resolvedTone, pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if variant == "outline" {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(resolvedTone.softForeground.opacity(0.45))
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private func foreground(tone: ChatKitWidgetTone) -> Color {
        switch variant {
        case "solid":
            tone.foreground
        case "ghost", "outline", "soft":
            tone.softForeground
        default:
            tone.softForeground
        }
    }

    private func background(tone: ChatKitWidgetTone, pressed: Bool) -> Color {
        let opacity = pressed ? 0.24 : 0.16
        switch variant {
        case "solid":
            return tone.solidBackground
        case "ghost":
            return .clear
        case "outline":
            return .clear
        default:
            return tone.solidBackground.opacity(opacity)
        }
    }
}

private struct ChatKitWidgetTextInputView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession
    let axis: Axis

    @State private var value: String

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession, axis: Axis) {
        self.node = node
        self.item = item
        self.session = session
        self.axis = axis
        _value = State(initialValue: node.string("defaultValue") ?? "")
    }

    var body: some View {
        Group {
            if axis == .vertical {
                TextField(node.string("placeholder") ?? "", text: $value, axis: .vertical)
                    .lineLimit(node.number("rows").map(Int.init) ?? 3, reservesSpace: true)
            } else {
                TextField(node.string("placeholder") ?? "", text: $value)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                #endif
            }
        }
        .textFieldStyle(.roundedBorder)
        .controlSize(ChatKitWidgetMetrics.controlSize(node.string("size")))
        .padding(ChatKitWidgetMetrics.insets(node.raw["gutterSize"], fallback: node.string("variant") == "outline" ? 0 : 8))
        .background {
            if node.string("variant") != "outline" {
                RoundedRectangle(cornerRadius: node.cornerRadius)
                    .fill(Color.secondary.opacity(0.10))
            }
        }
        .disabled(node.isDisabled)
        .onSubmit {
            Task { await performChangeAction() }
        }
    }

    private func performChangeAction() async {
        guard var action = node.action(named: "onChangeAction") else {
            return
        }
        action.payload = action.payloadByAdding(name: node.name, value: .string(value))
        await perform(action)
    }

    private func perform(_ action: ChatKitAction) async {
        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}

private struct ChatKitWidgetSelectView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @State private var value: String

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession) {
        self.node = node
        self.item = item
        self.session = session
        _value = State(initialValue: node.string("defaultValue") ?? "")
    }

    var body: some View {
        Picker(node.string("placeholder") ?? node.name ?? "Select", selection: $value) {
            if node.bool("clearable") {
                Text(node.string("placeholder") ?? "None").tag("")
            }
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.menu)
        .controlSize(ChatKitWidgetMetrics.controlSize(node.string("size")))
        .disabled(node.isDisabled)
        .onChange(of: value) { _, _ in
            Task { await performChangeAction() }
        }
    }

    private var options: [(value: String, label: String)] {
        node.array("options").compactMap { value in
            guard case let .object(object) = value,
                  let optionValue = object["value"]?.stringValue
            else {
                return nil
            }
            return (optionValue, object["label"]?.stringValue ?? optionValue)
        }
    }

    private func performChangeAction() async {
        guard var action = node.action(named: "onChangeAction") else {
            return
        }
        action.payload = action.payloadByAdding(name: node.name, value: .string(value))
        await perform(action)
    }

    private func perform(_ action: ChatKitAction) async {
        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}

private struct ChatKitWidgetDatePickerView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @State private var date: Date

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession) {
        self.node = node
        self.item = item
        self.session = session
        _date = State(initialValue: node.string("defaultValue").flatMap(Self.parseDate) ?? Date())
    }

    var body: some View {
        DatePicker(node.string("placeholder") ?? node.name ?? "Date", selection: $date, displayedComponents: [.date])
            .datePickerStyle(.compact)
            .controlSize(ChatKitWidgetMetrics.controlSize(node.string("size")))
            .disabled(node.isDisabled)
            .onChange(of: date) { _, _ in
                Task { await performChangeAction() }
            }
    }

    private func performChangeAction() async {
        guard var action = node.action(named: "onChangeAction") else {
            return
        }
        action.payload = action.payloadByAdding(name: node.name, value: .string(Self.formatDate(date)))
        await perform(action)
    }

    private func perform(_ action: ChatKitAction) async {
        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private struct ChatKitWidgetCheckboxView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @State private var checked: Bool

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession) {
        self.node = node
        self.item = item
        self.session = session
        _checked = State(initialValue: node.raw["defaultChecked"]?.boolValue == true)
    }

    var body: some View {
        Toggle(node.label ?? node.name ?? "", isOn: $checked)
            .disabled(node.isDisabled)
            .onChange(of: checked) { _, _ in
                Task { await performChangeAction() }
            }
    }

    private func performChangeAction() async {
        guard var action = node.action(named: "onChangeAction") else {
            return
        }
        action.payload = action.payloadByAdding(name: node.name, value: .bool(checked))
        await perform(action)
    }

    private func perform(_ action: ChatKitAction) async {
        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}

private struct ChatKitWidgetRadioGroupView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @State private var value: String

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession) {
        self.node = node
        self.item = item
        self.session = session
        _value = State(initialValue: node.string("defaultValue") ?? "")
    }

    var body: some View {
        directionalStack {
            ForEach(options, id: \.value) { option in
                Toggle(isOn: Binding(
                    get: { value == option.value },
                    set: { isOn in
                        if isOn {
                            value = option.value
                            Task { await performChangeAction() }
                        }
                    },
                )) {
                    Text(option.label)
                }
                .toggleStyle(.button)
                .disabled(node.isDisabled || option.disabled)
            }
        }
        .accessibilityLabel(node.string("ariaLabel") ?? node.name ?? "Options")
    }

    @ViewBuilder
    private func directionalStack(@ViewBuilder content: () -> some View) -> some View {
        if node.string("direction") == "row" {
            HStack(spacing: 8, content: content)
        } else {
            VStack(alignment: .leading, spacing: 8, content: content)
        }
    }

    private var options: [(value: String, label: String, disabled: Bool)] {
        node.array("options").compactMap { value in
            guard case let .object(object) = value,
                  let optionValue = object["value"]?.stringValue
            else {
                return nil
            }
            return (optionValue, object["label"]?.stringValue ?? optionValue, object["disabled"]?.boolValue == true)
        }
    }

    private func performChangeAction() async {
        guard var action = node.action(named: "onChangeAction") else {
            return
        }
        action.payload = action.payloadByAdding(name: node.name, value: .string(value))
        await perform(action)
    }

    private func perform(_ action: ChatKitAction) async {
        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}

private struct ChatKitWidgetTableView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(node.children, id: \.stableID) { row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(row.children, id: \.stableID) { cell in
                        ChatKitWidgetNodeView(node: cell, item: item, session: session)
                            .fontWeight(row.bool("header") ? .semibold : nil)
                            .frame(maxWidth: .infinity, alignment: cell.frameAlignment)
                    }
                }
                .background(row.bool("header") ? Color.secondary.opacity(0.10) : Color.clear)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.secondary.opacity(0.2))
        }
    }
}

private struct ChatKitWidgetChartView: View {
    let node: ChatKitWidgetNode
    let colorScheme: SwiftUI.ColorScheme

    private var points: [ChatKitWidgetChartPoint] {
        ChatKitWidgetChartPoint.points(in: node)
    }

    private var maximum: Double {
        max(points.map(\.value).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(points) { point in
                HStack(spacing: 8) {
                    Text(point.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 88, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(ChatKitWidgetColor.color(point.colorToken) ?? .accentColor)
                            .frame(width: max(4, proxy.size.width * CGFloat(point.value / maximum)))
                    }
                    .frame(height: 10)
                    Text(point.value.formatted())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct CapsuleOrRoundedRectangle: Shape {
    let pill: Bool
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        if pill {
            Capsule().path(in: rect)
        } else {
            RoundedRectangle(cornerRadius: radius).path(in: rect)
        }
    }
}

private extension View {
    func chatKitWidgetBoxStyle(node: ChatKitWidgetNode, colorScheme: SwiftUI.ColorScheme) -> some View {
        padding(ChatKitWidgetMetrics.insets(node.raw["padding"], fallback: 0))
            .background {
                if let background = node.color("background", colorScheme: colorScheme) {
                    RoundedRectangle(cornerRadius: node.cornerRadius)
                        .fill(background)
                }
            }
            .overlay {
                if let borderWidth = node.borderWidth {
                    RoundedRectangle(cornerRadius: node.cornerRadius)
                        .stroke(node.borderColor(colorScheme: colorScheme) ?? .secondary.opacity(0.25), lineWidth: borderWidth)
                }
            }
    }
}

private extension ChatKitWidgetNode {
    var gap: CGFloat? {
        ChatKitWidgetMetrics.spacing(raw["gap"])
    }

    func gapOrDefault(_ fallback: CGFloat) -> CGFloat {
        gap ?? fallback
    }

    var cardPadding: CGFloat {
        switch string("size") {
        case "sm": 12
        case "lg", "full": 20
        default: 16
        }
    }

    var cornerRadius: CGFloat {
        if bool("pill") {
            return 999
        }
        return ChatKitWidgetMetrics.radius(raw["radius"])
    }

    var horizontalAlignment: HorizontalAlignment {
        switch string("align") {
        case "center": .center
        case "end": .trailing
        default: .leading
        }
    }

    var verticalAlignment: VerticalAlignment {
        switch string("align") {
        case "center": .center
        case "end": .bottom
        case "baseline": .firstTextBaseline
        default: .top
        }
    }

    var frameAlignment: Alignment {
        switch string("align") {
        case "center": .center
        case "end": .trailing
        default: .leading
        }
    }

    var imageContentMode: ContentMode {
        switch string("fit") {
        case "cover", "fill":
            .fill
        default:
            .fit
        }
    }

    var textAlignment: TextAlignment {
        switch string("textAlign") {
        case "center": .center
        case "end": .trailing
        default: .leading
        }
    }

    var lineLimit: Int? {
        number("maxLines").map(Int.init)
    }

    var fontWeight: Font.Weight? {
        switch string("weight") {
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        default: nil
        }
    }

    var borderWidth: CGFloat? {
        borderWidth(raw["border"])
    }

    func borderColor(colorScheme: SwiftUI.ColorScheme) -> Color? {
        borderColor(raw["border"], colorScheme: colorScheme)
    }

    func cardAction(_ key: String) -> (label: String, action: ChatKitAction)? {
        guard case let .object(object)? = raw[key],
              let label = object["label"]?.stringValue,
              case let .object(actionObject)? = object["action"],
              let type = actionObject["type"]?.stringValue
        else {
            return nil
        }
        return (label, ChatKitAction(type: type, payload: actionObject["payload"]?.objectValue))
    }

    private func borderWidth(_ value: JSONValue?) -> CGFloat? {
        switch value {
        case let .number(number):
            return CGFloat(number)
        case let .object(object):
            if let size = object["size"]?.numberValue {
                return CGFloat(size)
            }
            return 1
        default:
            return nil
        }
    }

    private func borderColor(_ value: JSONValue?, colorScheme: SwiftUI.ColorScheme) -> Color? {
        guard case let .object(object) = value else {
            return nil
        }
        return ChatKitWidgetColor.color(object["color"], colorScheme: colorScheme)
    }
}

private extension ChatKitAction {
    func payloadByAdding(name: String?, value: JSONValue) -> [String: JSONValue] {
        var payload = payload ?? [:]
        if let name {
            payload["name"] = .string(name)
        }
        payload["value"] = value
        return payload
    }
}
