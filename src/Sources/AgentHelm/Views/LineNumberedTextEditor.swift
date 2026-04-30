import SwiftUI
import AppKit

/// SwiftUI text editor with a line-number gutter on the left and optional
/// regex-based syntax highlighting. Built on `NSTextView` because SwiftUI's
/// `TextEditor` exposes neither the layout manager (needed for the gutter)
/// nor the text storage (needed to apply per-range color attributes).
struct LineNumberedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isMonospaced: Bool = true
    var languageSpec: LanguageSpec? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = font(for: isMonospaced)
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 8)

        if let container = textView.textContainer {
            container.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            container.widthTracksTextView = true
        }
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.bind(textView: textView, ruler: ruler, scrollView: scrollView)
        context.coordinator.applyHighlight(textView: textView, language: languageSpec)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let oldRange = textView.selectedRange()
            textView.string = text
            let safeLocation = min(oldRange.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
            scrollView.verticalRulerView?.needsDisplay = true
            context.coordinator.applyHighlight(textView: textView, language: languageSpec)
        }

        let target = font(for: isMonospaced)
        if textView.font != target {
            textView.font = target
            context.coordinator.applyHighlight(textView: textView, language: languageSpec)
            scrollView.verticalRulerView?.needsDisplay = true
        }

        if context.coordinator.lastLanguageName != languageSpec?.name {
            context.coordinator.lastLanguageName = languageSpec?.name
            context.coordinator.applyHighlight(textView: textView, language: languageSpec)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func font(for monospaced: Bool) -> NSFont {
        let size = NSFont.systemFontSize
        return monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberedTextEditor
        var lastLanguageName: String?
        private var observers: [NSObjectProtocol] = []
        private var debounceTask: Task<Void, Never>?

        init(_ parent: LineNumberedTextEditor) {
            self.parent = parent
            self.lastLanguageName = parent.languageSpec?.name
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func bind(textView: NSTextView, ruler: LineNumberRulerView, scrollView: NSScrollView) {
            let textChanged = NotificationCenter.default.addObserver(
                forName: NSText.didChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                ruler.needsDisplay = true
                self?.scheduleHighlight(textView: textView)
            }
            let scrolled = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { _ in
                ruler.needsDisplay = true
            }
            scrollView.contentView.postsBoundsChangedNotifications = true
            observers.append(contentsOf: [textChanged, scrolled])
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        private func scheduleHighlight(textView: NSTextView) {
            debounceTask?.cancel()
            let language = parent.languageSpec
            debounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)  // 200 ms debounce
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.applyHighlight(textView: textView, language: language)
                }
            }
        }

        func applyHighlight(textView: NSTextView, language: LanguageSpec?) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)

            textStorage.beginEditing()
            // Reset attributes to the editor's defaults before re-applying.
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            if let font = textView.font {
                textStorage.addAttribute(.font, value: font, range: fullRange)
            }

            if let language {
                let highlights = SyntaxHighlighter.highlight(textView.string, with: language)
                for (range, color) in highlights {
                    if NSMaxRange(range) <= textStorage.length {
                        textStorage.addAttribute(.foregroundColor, value: color, range: range)
                    }
                }
            }
            textStorage.endEditing()
        }
    }
}

/// Draws line numbers in the gutter on the left of an `NSTextView`.
final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 44
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor.black.withAlphaComponent(0.15)
                : NSColor.black.withAlphaComponent(0.04)
        }.setFill()
        rect.fill()

        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        let border = NSBezierPath()
        border.move(to: NSPoint(x: ruleThickness - 0.5, y: rect.minY))
        border.line(to: NSPoint(x: ruleThickness - 0.5, y: rect.maxY))
        border.lineWidth = 1
        border.stroke()

        let nsString = textView.string as NSString
        let visibleRect = textView.visibleRect

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.smallSystemFontSize,
                weight: .regular
            ),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        var lineNumber = 1
        var charIndex = 0
        let totalLength = nsString.length

        while charIndex <= totalLength {
            let probe = NSRange(location: min(charIndex, max(totalLength - 1, 0)), length: 0)
            let lineRange = totalLength == 0 ? NSRange(location: 0, length: 0) : nsString.lineRange(for: probe)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            let lineRectInText: NSRect
            if totalLength == 0 || glyphRange.length == 0 {
                lineRectInText = layoutManager.extraLineFragmentRect
            } else {
                lineRectInText = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            }

            if lineRectInText.maxY < visibleRect.minY {
                lineNumber += 1
                let next = NSMaxRange(lineRange)
                if next == charIndex { break }
                charIndex = next
                continue
            }
            if lineRectInText.minY > visibleRect.maxY { break }

            let lineRectInRuler = self.convert(lineRectInText, from: textView)
            let str = "\(lineNumber)" as NSString
            let size = str.size(withAttributes: attrs)
            let drawX = ruleThickness - size.width - 6
            let drawY = lineRectInRuler.minY + (lineRectInText.height - size.height) / 2 + textView.textContainerInset.height
            str.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attrs)

            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next == charIndex { break }
            charIndex = next
        }
    }
}
