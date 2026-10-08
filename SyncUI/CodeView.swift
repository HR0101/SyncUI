import SwiftUI
import AppKit

/// SwiftUIコードを直接編集でき，変更がリアルタイムでキャンバスとインスペクタに反映されるビュー
struct CodeView: View {
    @Binding var code: String
    /// コードが解析できなかった場合にtrue
    var parseError: Bool = false
    /// 「適用」ボタン押下時に呼ばれるクロージャ（貼り付け後の確実なパース用）
    var onApply: (() -> Void)? = nil

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            codeHeader

            Divider()
                .background(Color.white.opacity(0.07))

            // NSTextViewベースのコードエディタ（行番号・ハイライト付き）
            CodeTextView(text: $code)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - ヘッダー

    private var codeHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.3))

            Text("CODE EDITOR")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Color.white.opacity(0.3))

            Spacer()

            // 解析エラー表示
            if parseError {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text("Text(...) が見つかりません")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.4))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 1.0, green: 0.5, blue: 0.4).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if let apply = onApply {
                Button(action: apply) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("適用")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.5))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.3, green: 0.85, blue: 0.5).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("コードをパースしてキャンバスとインスペクタに反映します")
            }

            Text("SwiftUI")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.98, green: 0.56, blue: 0.33))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.98, green: 0.56, blue: 0.33).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            copyButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }

    private var copyButton: some View {
        Button(action: copyCode) {
            HStack(spacing: 5) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 11))
            }
            .foregroundColor(
                isCopied
                    ? Color(red: 0.3, green: 0.85, blue: 0.5)
                    : Color(red: 0.4, green: 0.65, blue: 1.0)
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (isCopied
                    ? Color(red: 0.3, green: 0.85, blue: 0.5)
                    : Color(red: 0.4, green: 0.65, blue: 1.0)
                ).opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func copyCode() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.15)) { isCopied = false }
        }
    }
}

// MARK: - NSTextViewベースのコードエディタ

/// 行番号・シンタックスハイライトを備えたコードエディタ（NSTextViewラッパー）
struct CodeTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // 基本設定
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Theme.editorFont
        textView.textColor = Theme.foreground
        textView.backgroundColor = Theme.background
        textView.insertionPointColor = Theme.caret
        textView.textContainerInset = NSSize(width: 6, height: 12)

        // 自動補正をすべて無効化（コード編集の邪魔になるため）
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // 折り返しを無効化（行番号と論理行を1対1で対応させるため）
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        if let container = textView.textContainer {
            container.widthTracksTextView = false
            container.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // スクロールビュー
        scrollView.backgroundColor = Theme.background
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        // 行番号ルーラー
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        // 初期テキストとハイライト
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        context.coordinator.applyHighlight()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 最新のBinding（self）をCoordinatorへ反映する（古いBindingを掴み続けてViewModelに届かない問題を防ぐ）
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? NSTextView else { return }
        // 外部（GUI操作）からの変更時のみテキストを差し替える
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlight()
            nsView.verticalRulerView?.needsDisplay = true
        }
    }

    // MARK: - コーディネーター

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView
        weak var textView: NSTextView?
        weak var ruler: NSRulerView?

        init(_ parent: CodeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlight()
            ruler?.needsDisplay = true
        }

        /// 現在のテキストにシンタックスハイライトを適用する
        func applyHighlight() {
            guard let textView = textView, let storage = textView.textStorage else { return }
            SyntaxHighlighter.highlight(storage)
        }
    }
}

// MARK: - テーマ

/// エディタの配色とフォントを集約した定数
enum Theme {
    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    static let background = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.14, alpha: 1)
    static let gutterBackground = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.13, alpha: 1)
    static let foreground = NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.85, alpha: 1)
    static let caret = NSColor(calibratedRed: 0.40, green: 0.65, blue: 1.0, alpha: 1)
    static let lineNumber = NSColor.white.withAlphaComponent(0.28)

    static let keyword = NSColor(calibratedRed: 0.98, green: 0.38, blue: 0.64, alpha: 1)
    static let type = NSColor(calibratedRed: 0.36, green: 0.85, blue: 1.0, alpha: 1)
    static let modifier = NSColor(calibratedRed: 0.63, green: 0.45, blue: 0.92, alpha: 1)
    static let number = NSColor(calibratedRed: 0.82, green: 0.72, blue: 0.42, alpha: 1)
    static let string = NSColor(calibratedRed: 0.99, green: 0.58, blue: 0.37, alpha: 1)
}

// MARK: - シンタックスハイライト

/// NSTextStorageに対してSwiftUIコードのシンタックスハイライトを適用するユーティリティ
enum SyntaxHighlighter {
    static func highlight(_ storage: NSTextStorage) {
        let text = storage.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()

        // ベース（フォントと既定文字色）をリセット
        storage.addAttribute(.font, value: Theme.editorFont, range: fullRange)
        storage.addAttribute(.foregroundColor, value: Theme.foreground, range: fullRange)

        // 適用順序：後に適用したものが優先される
        apply(storage, text, #"\.[a-zA-Z_][a-zA-Z0-9_]*(?=\()"#, Theme.modifier)
        apply(storage, text, #"(?<![.\w])\d+(\.\d+)?"#, Theme.number)
        apply(storage, text, #"\b(View|Text|Color|Font|CGFloat|String|Int|Double|Bool|RoundedRectangle|HStack|VStack|ZStack|Image)\b"#, Theme.type)
        apply(storage, text, #"\b(import|struct|class|enum|var|let|func|return|some|if|else|for|in|true|false|nil|self|init|private|public|internal)\b"#, Theme.keyword)
        // 文字列は最後に適用してキーワードより優先させる
        apply(storage, text, #""[^"\n]*""#, Theme.string)

        storage.endEditing()
    }

    private static func apply(_ storage: NSTextStorage, _ text: String, _ pattern: String, _ color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, range: range) {
            storage.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}

// MARK: - 行番号ルーラー

/// NSTextViewのスクロールに完全同期する行番号表示（折り返し無効前提で論理行と1対1）
final class LineNumberRulerView: NSRulerView {

    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 46
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // ガター背景を塗る
        Theme.gutterBackground.setFill()
        bounds.fill()

        let nsString = textView.string as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Theme.lineNumberFont,
            .foregroundColor: Theme.lineNumber
        ]
        let yInset = textView.textContainerInset.height
        let relativePoint = self.convert(NSPoint.zero, from: textView)

        // 可視範囲のグリフ／文字レンジを取得
        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        // 最初の可視文字が何行目かを数える（改行文字の数 + 1）
        var lineNumber = 1
        var index = 0
        while index < visibleCharRange.location {
            if nsString.character(at: index) == 10 { // '\n'
                lineNumber += 1
            }
            index += 1
        }

        // 各行フラグメントに行番号を描画（折り返し無効なので1フラグメント=1行）
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { fragmentRect, _, _, _, _ in
            self.drawNumber(lineNumber, at: fragmentRect, yInset: yInset, relativeY: relativePoint.y, attributes: attributes)
            lineNumber += 1
        }

        // 末尾が改行で終わる場合（または空テキスト）の最終行
        if nsString.length == 0 || nsString.character(at: nsString.length - 1) == 10 {
            let extraRect = layoutManager.extraLineFragmentRect
            drawNumber(lineNumber, at: extraRect, yInset: yInset, relativeY: relativePoint.y, attributes: attributes)
        }
    }

    /// 指定したフラグメント矩形の位置に行番号を右寄せで描画する
    private func drawNumber(
        _ number: Int,
        at fragmentRect: NSRect,
        yInset: CGFloat,
        relativeY: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let x = ruleThickness - size.width - 8
        let y = fragmentRect.minY + relativeY + yInset + (fragmentRect.height - size.height) / 2
        label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
    }
}
