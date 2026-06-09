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
    let parentType: String?

    @Environment(\.colorScheme) private var colorScheme

    init(node: ChatKitWidgetNode, item: ChatKitWidgetItem, session: ChatKitSession, parentType: String? = nil) {
        self.node = node
        self.item = item
        self.session = session
        self.parentType = parentType
    }

    var body: some View {
        switch node.type {
        case "Basic", "Box", "Form":
            directionalStack(direction: node.widgetDirection(default: .col)) {
                if let status = node.object("status") {
                    ChatKitWidgetStatusView(status: status)
                }
                children
            }
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme, parentType: parentType)
        case "Row":
            row
        case "Col":
            VStack(alignment: node.horizontalAlignment, spacing: node.gapOrDefault(0)) {
                children
            }
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme, parentType: parentType)
        case "Card":
            VStack(alignment: .leading, spacing: node.gapOrDefault(12)) {
                if let status = node.object("status") {
                    ChatKitWidgetStatusView(status: status)
                }

                cardBody
                cardActions
            }
            .frame(maxWidth: ChatKitWidgetMetrics.cardMaxWidth(node.string("size")) ?? .infinity, alignment: .leading)
        case "ListView":
            ChatKitWidgetListView(node: node, item: item, session: session)
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
            text(
                node.value ?? "",
                pointSize: ChatKitWidgetMetrics.titlePointSize(node.string("size")),
                lineHeight: ChatKitWidgetMetrics.titleLineHeight(node.string("size")),
                defaultWeight: .medium,
            )
        case "Caption":
            text(
                node.value ?? "",
                pointSize: ChatKitWidgetMetrics.captionPointSize(node.string("size")),
                lineHeight: ChatKitWidgetMetrics.captionLineHeight(node.string("size")),
                defaultColor: .secondary,
            )
        case "Text":
            text(
                node.value ?? "",
                pointSize: ChatKitWidgetMetrics.textPointSize(node.string("size")),
                lineHeight: ChatKitWidgetMetrics.textLineHeight(node.string("size")),
            )
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
            text(
                node.value ?? node.label ?? "",
                pointSize: ChatKitWidgetMetrics.textPointSize(node.string("size")),
                lineHeight: ChatKitWidgetMetrics.textLineHeight(node.string("size")),
                defaultWeight: node.fontWeight,
            )
        case "Table":
            ChatKitWidgetTableView(node: node, item: item, session: session)
        case "Table.Row":
            HStack(alignment: .top, spacing: 16) {
                children
            }
        case "Table.Cell":
            VStack(alignment: node.horizontalAlignment, spacing: 4) {
                children
            }
            .padding(node.tableCellInsets)
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
            ChatKitWidgetNodeView(node: child, item: item, session: session, parentType: node.type)
        }
    }

    @ViewBuilder
    private var row: some View {
        if node.hasPercentageWidthChildren {
            ChatKitWidgetInlineRowLayout(alignment: node.verticalAlignment, spacing: node.gapOrDefault(0)) {
                ForEach(node.children, id: \.stableID) { child in
                    ChatKitWidgetNodeView(node: child, item: item, session: session, parentType: node.type)
                        .layoutValue(key: ChatKitWidgetWidthPercentageKey.self, value: child.widthPercentage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme, parentType: parentType)
        } else {
            HStack(alignment: node.verticalAlignment, spacing: node.gapOrDefault(0)) {
                children
            }
            .frame(maxWidth: node.hasSpacerChildren ? .infinity : nil, alignment: .leading)
            .fixedSize(horizontal: parentType == "Row" && !node.hasSpacerChildren, vertical: false)
            .layoutPriority(parentType == "Row" ? 1 : 0)
            .chatKitWidgetBoxStyle(node: node, colorScheme: colorScheme, parentType: parentType)
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
        let buttonRadius = ChatKitWidgetMetrics.buttonCornerRadius(node.raw["radius"], pill: node.bool("pill"))
        let fillWidth = node.buttonFillsAvailableWidth(parentType: parentType)

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
                        .truncationMode(.tail)
                }
                if let iconEnd {
                    Image(systemName: ChatKitStyle.systemImage(for: iconEnd))
                        .font(ChatKitWidgetMetrics.iconFont(node.string("iconSize")))
                }
            }
            .frame(maxWidth: fillWidth ? .infinity : nil)
        }
        .controlSize(ChatKitWidgetMetrics.controlSize(node.string("size")))
        .buttonStyle(ChatKitWidgetButtonStyle(
            variant: variant,
            tone: tone,
            height: ChatKitWidgetMetrics.buttonHeight(node.string("size")),
            fontPointSize: ChatKitWidgetMetrics.buttonFontPointSize(node.string("size")),
            horizontalPadding: ChatKitWidgetMetrics.buttonHorizontalPadding(node.string("size"), pill: buttonRadius >= 999),
            cornerRadius: buttonRadius,
        ))
        .clipShape(RoundedRectangle(cornerRadius: buttonRadius))
        .disabled(node.isDisabled)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: node.gapOrDefault(12)) {
            if !node.bool("collapsed") {
                children
            }
        }
        .padding(ChatKitWidgetMetrics.insets(node.raw["padding"], fallback: node.cardPadding))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            node.color("background", colorScheme: colorScheme) ?? ChatKitWidgetMetrics.defaultCardBackground(colorScheme: colorScheme),
            in: RoundedRectangle(cornerRadius: node.cornerRadius),
        )
        .overlay {
            RoundedRectangle(cornerRadius: node.cornerRadius)
                .stroke(
                    node.borderColor(colorScheme: colorScheme) ?? ChatKitWidgetMetrics.defaultCardBorder(colorScheme: colorScheme),
                    lineWidth: node.borderWidth ?? 1,
                )
        }
    }

    @ViewBuilder
    private var cardActions: some View {
        if node.cardAction("confirm") != nil || node.cardAction("cancel") != nil {
            HStack(spacing: 8) {
                if let confirm = node.cardAction("confirm") {
                    cardActionButton(label: confirm.label, action: confirm.action, variant: "solid", tone: .primary)
                }
                if let cancel = node.cardAction("cancel") {
                    cardActionButton(label: cancel.label, action: cancel.action, variant: "outline", tone: .secondary)
                }
            }
        }
    }

    private func cardActionButton(label: String, action: ChatKitAction, variant: String, tone: ChatKitWidgetTone) -> some View {
        Button {
            Task { await performActionIfPossible(action) }
        } label: {
            Text(label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(ChatKitWidgetButtonStyle(
            variant: variant,
            tone: tone,
            height: ChatKitWidgetMetrics.buttonHeight(nil),
            fontPointSize: ChatKitWidgetMetrics.buttonFontPointSize(nil),
            horizontalPadding: ChatKitWidgetMetrics.buttonHorizontalPadding(nil, pill: true),
            cornerRadius: ChatKitWidgetMetrics.buttonCornerRadius(nil, pill: true),
        ))
    }

    @ViewBuilder
    private func directionalStack(direction: ChatKitWidgetDirection, @ViewBuilder content: () -> some View) -> some View {
        if direction == .row {
            HStack(alignment: node.verticalAlignment, spacing: node.gapOrDefault(0), content: content)
        } else {
            VStack(alignment: node.horizontalAlignment, spacing: node.gapOrDefault(0), content: content)
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
    private func text(_ value: String, pointSize: CGFloat, lineHeight: CGFloat, defaultColor: Color? = nil, defaultWeight: Font.Weight? = nil) -> some View {
        let color = node.color("color", colorScheme: colorScheme) ?? defaultColor
        let fontWeight = node.fontWeight ?? defaultWeight ?? .regular
        let lineLimit = node.lineLimit
        let text = Text(value)
            .font(.system(size: pointSize, weight: fontWeight))
            .strikethrough(node.bool("lineThrough"))
            .italic(node.bool("italic"))
            .multilineTextAlignment(node.textAlignment)
            .lineLimit(lineLimit)
            .lineSpacing(ChatKitWidgetMetrics.additionalLineSpacing(pointSize: pointSize, lineHeight: lineHeight))
            .truncationMode(.tail)
            .layoutPriority(parentType == "Row" ? 1 : 0)

        if let color {
            text.foregroundStyle(color)
        } else {
            text
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

private struct ChatKitWidgetListView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: node.gapOrDefault(8)) {
            if let status = node.object("status") {
                ChatKitWidgetStatusView(status: status)
            }
            ForEach(node.visibleListChildren(isExpanded: isExpanded), id: \.stableID) { child in
                ChatKitWidgetNodeView(node: child, item: item, session: session, parentType: node.type)
            }
            if !isExpanded, let label = node.hiddenListDisclosureLabel {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded = true
                    }
                } label: {
                    Text(label)
                }
                .buttonStyle(ChatKitWidgetListDisclosureButtonStyle())
                .accessibilityLabel(label)
            }
        }
    }
}

private struct ChatKitWidgetWidthPercentageKey: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

private struct ChatKitWidgetInlineRowLayout: Layout {
    let alignment: VerticalAlignment
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = measuredSizes(proposal: proposal, subviews: subviews)
        let width = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, subviews.count - 1))
        let height = sizes.map(\.height).max() ?? 0

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = measuredSizes(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        var x = bounds.minX

        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            subview.place(
                at: CGPoint(x: x, y: yPosition(for: size, in: bounds)),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height),
            )
            x += size.width + spacing
        }
    }

    private func measuredSizes(proposal: ProposedViewSize, subviews: Subviews) -> [CGSize] {
        let naturalSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let availableWidth = proposal.width ?? naturalSizes.map(\.width).reduce(0, +)
        let spacingWidth = spacing * CGFloat(max(0, subviews.count - 1))
        let fixedWidth = zip(subviews, naturalSizes)
            .filter { subview, _ in subview[ChatKitWidgetWidthPercentageKey.self] == nil }
            .map { _, size in size.width }
            .reduce(0, +)
        let remainingWidth = max(0, availableWidth - fixedWidth - spacingWidth)
        let desiredPercentageWidths = subviews.map { subview in
            subview[ChatKitWidgetWidthPercentageKey.self].map { max(0, availableWidth * $0) }
        }
        let totalDesiredPercentageWidth = desiredPercentageWidths.compactMap(\.self).reduce(0, +)
        let percentageScale = totalDesiredPercentageWidth > remainingWidth && totalDesiredPercentageWidth > 0
            ? remainingWidth / totalDesiredPercentageWidth
            : 1

        return subviews.enumerated().map { index, subview in
            if let desiredWidth = desiredPercentageWidths[index] {
                let width = desiredWidth * percentageScale
                return subview.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
            }
            return naturalSizes[index]
        }
    }

    private func yPosition(for size: CGSize, in bounds: CGRect) -> CGFloat {
        switch alignment {
        case .center:
            bounds.midY - size.height / 2
        case .bottom:
            bounds.maxY - size.height
        default:
            bounds.minY
        }
    }
}

private struct ChatKitWidgetListDisclosureButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ChatKitWidgetMetrics.textPointSize("sm"), weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 24)
            .frame(minHeight: 36, alignment: .center)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private var foreground: Color {
        colorScheme == .dark
            ? (Color(chatKitHex: "#D4D4D4") ?? .secondary)
            : (Color(chatKitHex: "#5D5D5D") ?? .secondary)
    }

    private var background: Color {
        colorScheme == .dark
            ? (Color(chatKitHex: "#2F2F2F") ?? .clear)
            : (Color(chatKitHex: "#FFFFFF") ?? .white)
    }

    private var border: Color {
        colorScheme == .dark
            ? (Color(chatKitHex: "#5D5D5D") ?? .secondary.opacity(0.45))
            : (Color(chatKitHex: "#D7D7D7") ?? .secondary.opacity(0.25))
    }
}

private struct ChatKitWidgetBadgeView: View {
    let node: ChatKitWidgetNode

    @Environment(\.colorScheme) private var colorScheme

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
                        .stroke(outlineColor(for: tone))
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
        if tone == .primary, node.string("variant") == "solid" {
            return lowEmphasisForeground(for: tone)
        }
        return node.string("variant") == "solid" ? tone.foreground : lowEmphasisForeground(for: tone)
    }

    private func background(for tone: ChatKitWidgetTone) -> Color {
        switch node.string("variant") {
        case "solid":
            if tone == .primary {
                return .clear
            }
            return tone.solidBackground
        case "outline":
            return .clear
        default:
            return lowEmphasisBackground(for: tone)
        }
    }

    private func outlineColor(for tone: ChatKitWidgetTone) -> Color {
        lowEmphasisForeground(for: tone)
    }

    private func lowEmphasisForeground(for tone: ChatKitWidgetTone) -> Color {
        guard colorScheme == .dark else {
            return tone.softForeground
        }
        let hex = switch tone {
        case .primary:
            "#F3F3F3"
        case .secondary:
            "#D4D4D4"
        case .info:
            "#3DA1FF"
        case .discovery:
            "#B08CFF"
        case .success:
            "#41D67A"
        case .warning:
            "#FF7A2F"
        case .danger:
            "#FF6B66"
        }
        return Color(chatKitHex: hex) ?? tone.softForeground
    }

    private func lowEmphasisBackground(for tone: ChatKitWidgetTone) -> Color {
        guard colorScheme == .dark else {
            return tone.softBackground
        }
        let hex = switch tone {
        case .primary:
            "#2F2F2F"
        case .secondary:
            "#2F2F2F"
        case .info:
            "#0D2A42"
        case .discovery:
            "#2B2142"
        case .success:
            "#0F3321"
        case .warning:
            "#3A2418"
        case .danger:
            "#421C1C"
        }
        return Color(chatKitHex: hex) ?? tone.softBackground
    }
}

private struct ChatKitWidgetStatusView: View {
    let status: [String: JSONValue]

    var body: some View {
        Label(status["text"]?.stringValue ?? "", systemImage: ChatKitStyle.systemImage(for: status["icon"]?.stringValue ?? "info"))
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.secondary)
    }
}

private struct ChatKitWidgetButtonStyle: ButtonStyle {
    let variant: String
    let tone: ChatKitWidgetTone?
    let height: CGFloat
    let fontPointSize: CGFloat
    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTone = tone ?? .secondary
        configuration.label
            .font(.system(size: fontPointSize, weight: .medium))
            .frame(minHeight: height)
            .padding(.horizontal, horizontalPadding)
            .foregroundStyle(isEnabled ? foreground(tone: resolvedTone) : disabledForeground)
            .background(background(tone: resolvedTone, pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if variant == "outline" {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isEnabled ? outlineBorder(tone: resolvedTone) : disabledForeground)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private func foreground(tone: ChatKitWidgetTone) -> Color {
        if colorScheme == .dark, variant == "solid", tone == .primary {
            return Color(chatKitHex: "#0D0D0D") ?? .black
        }

        switch variant {
        case "solid":
            return tone.foreground
        case "ghost", "outline", "soft":
            return darkAwareSoftForeground(tone: tone)
        default:
            return darkAwareSoftForeground(tone: tone)
        }
    }

    private func background(tone: ChatKitWidgetTone, pressed: Bool) -> Color {
        if !isEnabled {
            return variant == "ghost" ? .clear : disabledBackground
        }
        if colorScheme == .dark, variant == "solid", tone == .primary {
            return Color(chatKitHex: pressed ? "#DCDCDC" : "#F3F3F3") ?? .white
        }

        switch variant {
        case "solid":
            return tone.solidBackground
        case "ghost":
            return .clear
        case "outline":
            return .clear
        default:
            return tone.softBackground
        }
    }

    private var disabledForeground: Color {
        Color(chatKitHex: "#8F8F8F") ?? .secondary
    }

    private var disabledBackground: Color {
        Color(chatKitHex: "#EDEDED") ?? .secondary.opacity(0.12)
    }

    private func outlineBorder(tone: ChatKitWidgetTone) -> Color {
        if colorScheme == .dark {
            return tone == .secondary
                ? (Color(chatKitHex: "#5D5D5D") ?? .secondary.opacity(0.45))
                : darkAwareSoftForeground(tone: tone)
        }

        return tone == .secondary
            ? (Color(chatKitHex: "#D7D7D7") ?? .secondary.opacity(0.25))
            : tone.softForeground
    }

    private func darkAwareSoftForeground(tone: ChatKitWidgetTone) -> Color {
        guard colorScheme == .dark else {
            return tone.softForeground
        }
        let hex = switch tone {
        case .primary:
            "#F3F3F3"
        case .secondary:
            "#D4D4D4"
        case .info:
            "#3DA1FF"
        case .discovery:
            "#B08CFF"
        case .success:
            "#41D67A"
        case .warning:
            "#FF7A2F"
        case .danger:
            "#FF6B66"
        }
        return Color(chatKitHex: hex) ?? tone.softForeground
    }
}

private struct ChatKitWidgetControlField<Content: View>: View {
    let minHeight: CGFloat
    let isDisabled: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        minHeight: CGFloat,
        isDisabled: Bool = false,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.isDisabled = isDisabled
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: ChatKitWidgetMetrics.textPointSize(nil), weight: .regular))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(fieldBorder, lineWidth: 1)
            }
            .opacity(isDisabled ? 0.55 : 1)
    }

    private var fieldBackground: Color {
        Color(chatKitHex: ChatKitWidgetMetrics.defaultControlFieldBackgroundHex(colorScheme: colorScheme)) ?? .clear
    }

    private var fieldBorder: Color {
        Color(chatKitHex: ChatKitWidgetMetrics.defaultControlFieldBorderHex(colorScheme: colorScheme)) ?? .secondary.opacity(0.25)
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
        ChatKitWidgetControlField(
            minHeight: minHeight,
            isDisabled: node.isDisabled,
            verticalPadding: axis == .vertical ? 10 : 0,
        ) {
            if axis == .vertical {
                TextField(node.string("placeholder") ?? "", text: $value, axis: .vertical)
                    .lineLimit(node.number("rows").map(Int.init) ?? 3, reservesSpace: true)
                    .textFieldStyle(.plain)
            } else {
                TextField(node.string("placeholder") ?? "", text: $value)
                    .textFieldStyle(.plain)
                #if os(iOS) || os(visionOS)
                    .textInputAutocapitalization(.sentences)
                #endif
            }
        }
        .disabled(node.isDisabled)
        .onSubmit {
            Task { await performChangeAction() }
        }
    }

    private var minHeight: CGFloat {
        if axis == .vertical {
            return ChatKitWidgetMetrics.textareaMinHeight(rows: node.number("rows").map(Int.init) ?? 3)
        }
        return ChatKitWidgetMetrics.controlFieldHeight(node.string("size"))
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
        Menu {
            if node.bool("clearable") {
                Button(node.string("placeholder") ?? "None") {
                    value = ""
                    Task { await performChangeAction() }
                }
            }
            ForEach(options, id: \.value) { option in
                Button(option.label) {
                    value = option.value
                    Task { await performChangeAction() }
                }
            }
        } label: {
            ChatKitWidgetControlField(
                minHeight: ChatKitWidgetMetrics.controlFieldHeight(node.string("size")),
                isDisabled: node.isDisabled,
            ) {
                HStack(spacing: 8) {
                    Text(selectedLabel)
                        .foregroundStyle(value.isEmpty ? .secondary : .primary)
                    Spacer(minLength: 8)
                    if node.bool("clearable"), !value.isEmpty {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(node.isDisabled)
    }

    private var selectedLabel: String {
        options.first(where: { $0.value == value })?.label ?? node.string("placeholder") ?? node.name ?? "Select"
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
        ZStack {
            DatePicker(node.string("placeholder") ?? node.name ?? "Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .opacity(0.01)
                .frame(maxWidth: .infinity, minHeight: ChatKitWidgetMetrics.controlFieldHeight(node.string("size")), alignment: .leading)

            ChatKitWidgetControlField(
                minHeight: ChatKitWidgetMetrics.controlFieldHeight(node.string("size")),
                isDisabled: node.isDisabled,
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.primary)
                    Text(Self.displayFormatter.string(from: date))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .allowsHitTesting(false)
        }
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
        ChatKitWidgetMetrics.date(from: value)
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()
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
        Button {
            checked.toggle()
            Task { await performChangeAction() }
        } label: {
            HStack(spacing: 8) {
                checkboxIndicator
                Text(node.label ?? node.name ?? "")
                    .font(.system(size: ChatKitWidgetMetrics.textPointSize(nil), weight: .regular))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(node.isDisabled)
        .opacity(node.isDisabled ? 0.55 : 1)
    }

    private var checkboxIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(checked ? (Color(chatKitHex: "#282828") ?? .primary) : (Color(chatKitHex: "#FFFFFF") ?? .clear))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(checked ? Color.clear : (Color(chatKitHex: "#D7D7D7") ?? .secondary.opacity(0.25)), lineWidth: 1)
            }
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: ChatKitWidgetMetrics.checkboxIndicatorSize, height: ChatKitWidgetMetrics.checkboxIndicatorSize)
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
                Button {
                    guard !option.disabled else {
                        return
                    }
                    value = option.value
                    Task { await performChangeAction() }
                } label: {
                    HStack(spacing: 8) {
                        radioIndicator(isSelected: value == option.value)
                        Text(option.label)
                            .font(.system(size: ChatKitWidgetMetrics.textPointSize(nil), weight: .regular))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(node.isDisabled || option.disabled)
                .opacity((node.isDisabled || option.disabled) ? 0.55 : 1)
            }
        }
        .accessibilityLabel(node.string("ariaLabel") ?? node.name ?? "Options")
    }

    @ViewBuilder
    private func directionalStack(@ViewBuilder content: () -> some View) -> some View {
        if node.widgetDirection(default: .row) == .row {
            HStack(spacing: 18, content: content)
        } else {
            VStack(alignment: .leading, spacing: 8, content: content)
        }
    }

    private func radioIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? (Color(chatKitHex: "#282828") ?? .primary) : (Color(chatKitHex: "#FFFFFF") ?? .clear))
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.clear : (Color(chatKitHex: "#D7D7D7") ?? .secondary.opacity(0.25)), lineWidth: 1)
                }
            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: ChatKitWidgetMetrics.selectionIndicatorSize, height: ChatKitWidgetMetrics.selectionIndicatorSize)
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
            ForEach(Array(node.children.enumerated()), id: \.element.stableID) { index, row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row.children, id: \.stableID) { cell in
                        ChatKitWidgetNodeView(node: cell, item: item, session: session, parentType: row.type)
                            .fontWeight(row.bool("header") ? .semibold : nil)
                            .frame(maxWidth: .infinity, alignment: cell.frameAlignment)
                    }
                }
                if index < node.children.count - 1 {
                    Divider()
                }
            }
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
    func chatKitWidgetBoxStyle(node: ChatKitWidgetNode, colorScheme: SwiftUI.ColorScheme, parentType: String?) -> some View {
        chatKitWidgetSizedBoxStyle(node: node, colorScheme: colorScheme, parentType: parentType)
    }

    @ViewBuilder
    private func chatKitWidgetSizedBoxStyle(node: ChatKitWidgetNode, colorScheme: SwiftUI.ColorScheme, parentType: String?) -> some View {
        if node.widthPercentage != nil, let fixedHeight = node.fixedHeight, parentType == "Row" {
            padding(node.containerInsets)
                .frame(maxWidth: .infinity, minHeight: fixedHeight, maxHeight: fixedHeight, alignment: node.frameAlignment)
                .chatKitWidgetDecoratedBoxStyle(node: node, colorScheme: colorScheme)
        } else if let widthPercentage = node.widthPercentage,
                  parentType == "Box",
                  node.heightPercentage != nil || node.fixedHeight != nil
        {
            GeometryReader { proxy in
                padding(node.containerInsets)
                    .frame(
                        width: max(0, proxy.size.width * widthPercentage),
                        height: node.heightPercentage.map { max(0, proxy.size.height * $0) } ?? node.fixedHeight,
                        alignment: node.frameAlignment,
                    )
                    .chatKitWidgetDecoratedBoxStyle(node: node, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: node.frameAlignment)
            }
            .frame(height: node.fixedHeight)
        } else if let widthPercentage = node.widthPercentage, let fixedHeight = node.fixedHeight {
            GeometryReader { proxy in
                padding(node.containerInsets)
                    .frame(width: max(0, proxy.size.width * widthPercentage), height: fixedHeight, alignment: node.frameAlignment)
                    .chatKitWidgetDecoratedBoxStyle(node: node, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity, alignment: node.frameAlignment)
            }
            .frame(height: fixedHeight)
        } else {
            padding(node.containerInsets)
                .frame(
                    width: node.fixedWidth,
                    height: node.fixedHeight,
                    alignment: node.frameAlignment,
                )
                .frame(maxWidth: node.fillsAvailableWidth(parentType: parentType) ? .infinity : nil, alignment: node.frameAlignment)
                .chatKitWidgetDecoratedBoxStyle(node: node, colorScheme: colorScheme)
        }
    }

    private func chatKitWidgetDecoratedBoxStyle(node: ChatKitWidgetNode, colorScheme: SwiftUI.ColorScheme) -> some View {
        background {
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

extension ChatKitWidgetNode {
    var gap: CGFloat? {
        ChatKitWidgetMetrics.stackGap(raw["gap"], containerType: type, childTypes: children.map(\.type))
    }

    func gapOrDefault(_ fallback: CGFloat) -> CGFloat {
        gap ?? fallback
    }

    var cardPadding: CGFloat {
        switch string("size") {
        case "sm": 16
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

    var tableCellInsets: EdgeInsets {
        guard raw["padding"] == nil else {
            return ChatKitWidgetMetrics.insets(raw["padding"])
        }
        return EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
    }

    var containerInsets: EdgeInsets {
        if type == "Box" {
            return EdgeInsets()
        }
        return ChatKitWidgetMetrics.insets(raw["padding"], fallback: 0)
    }

    var fixedWidth: CGFloat? {
        ChatKitWidgetMetrics.fixedDimension(raw["width"])
    }

    var fixedHeight: CGFloat? {
        ChatKitWidgetMetrics.fixedDimension(raw["height"])
    }

    var widthPercentage: CGFloat? {
        ChatKitWidgetMetrics.percentage(raw["width"])
    }

    var heightPercentage: CGFloat? {
        ChatKitWidgetMetrics.percentage(raw["height"])
    }

    var hasPercentageWidthChildren: Bool {
        children.contains { $0.widthPercentage != nil }
    }

    var hasSpacerChildren: Bool {
        children.contains { $0.type == "Spacer" }
    }

    func fillsAvailableWidth(parentType: String?) -> Bool {
        if bool("block") || type == "Basic" || type == "Form" {
            return true
        }
        if type == "Box", parentType != "Row", fixedWidth == nil {
            return raw["background"] != nil || raw["border"] != nil || fixedHeight != nil
        }
        return false
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
