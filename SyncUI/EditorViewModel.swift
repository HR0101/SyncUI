import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

/// コード・キャンバス・インスペクタを双方向に同期し，JSON永続化も担うViewModel
///
/// 状態の唯一の源は `codeString`（ソースコードそのもの）．
/// - コード編集 → `document` へ解析 → キャンバスとインスペクタへ反映
/// - インスペクタ操作 → `SourceEditor` でコードの該当箇所だけを外科的に書き換え
///   （コード全体は再生成しないため，書式・コメント・未知モディファイアが保持される）
class EditorViewModel: ObservableObject {

    /// 状態の唯一の源．変更されると解析してdocumentを更新する
    @Published var codeString: String = "" {
        didSet { reparse() }
    }

    /// codeStringから解析された描画・編集用の構造（派生値）
    @Published var document: DesignDocument = .default

    /// コードが解析できなかった場合にtrue
    @Published var parseError: Bool = false

    init() {
        // 初期コードを既定ドキュメントから生成（init内代入はdidSetを発火しない）
        codeString = SwiftUICodeParser.serialize(.default)
        reparse()
    }

    // MARK: - 解析

    /// codeStringを解析してdocumentに反映する（「適用」ボタンからも呼ばれる）
    func parseFromCode() {
        reparse()
    }

    private func reparse() {
        if let parsed = SwiftUICodeParser.parse(codeString) {
            document = parsed
            parseError = false
        } else {
            parseError = true
        }
    }

    // MARK: - インスペクタ用アクセサ
    // get: documentから読む / set: SourceEditorでコードの該当箇所のみ書き換える

    var textContent: String {
        get { document.text }
        set { codeString = SourceEditor.setText(newValue, in: codeString) }
    }

    var fontSize: CGFloat {
        get { document.fontSize }
        set { codeString = SourceEditor.setFontSize(newValue, in: codeString) }
    }

    var fontWeight: FontWeightType {
        get { document.fontWeight }
        set { codeString = SourceEditor.setFontWeight(newValue, in: codeString) }
    }

    var fontDesign: FontDesignType {
        get { document.fontDesign }
        set {
            codeString = SourceEditor.setFontDesign(
                newValue,
                size: document.fontSize,
                weight: document.fontWeight,
                in: codeString
            )
        }
    }

    // --- 装飾（トグル） ---

    var italic: Bool {
        get { document.italic }
        set { codeString = SourceEditor.setToggleModifier(codeString, name: "italic", on: newValue) }
    }

    var underline: Bool {
        get { document.underline }
        set { codeString = SourceEditor.setToggleModifier(codeString, name: "underline", on: newValue) }
    }

    var strikethrough: Bool {
        get { document.strikethrough }
        set { codeString = SourceEditor.setToggleModifier(codeString, name: "strikethrough", on: newValue) }
    }

    var kerning: CGFloat {
        get { document.kerning }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "kerning", value: newValue,
                argsTemplate: { $0 }, numberLabel: nil, removeWhen: { $0 == 0 }
            )
        }
    }

    var lineSpacing: CGFloat {
        get { document.lineSpacing }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "lineSpacing", value: newValue,
                argsTemplate: { $0 }, numberLabel: nil, removeWhen: { $0 == 0 }
            )
        }
    }

    var textAlign: TextAlignType {
        get { document.textAlign }
        set {
            codeString = SourceEditor.setEnumModifier(
                codeString, name: "multilineTextAlignment",
                caseName: newValue.rawValue, removeWhenCase: "leading"
            )
        }
    }

    // --- 色 ---

    var textColor: Color {
        get { document.textColor?.color ?? .white }
        set { codeString = SourceEditor.setTextColor(CodableColor(newValue), in: codeString) }
    }

    var backgroundColor: Color {
        get { document.backgroundColor?.color ?? .clear }
        set { codeString = SourceEditor.setBackgroundColor(CodableColor(newValue), in: codeString) }
    }

    var opacity: CGFloat {
        get { CGFloat(document.opacityValue) }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "opacity", value: newValue,
                argsTemplate: { $0 }, numberLabel: nil, removeWhen: { $0 >= 0.999 }
            )
        }
    }

    // --- レイアウト ---

    var padding: CGFloat {
        get { document.padding }
        set { codeString = SourceEditor.setPadding(newValue, in: codeString) }
    }

    var cornerRadius: CGFloat {
        get { document.cornerRadius }
        set { codeString = SourceEditor.setCornerRadius(newValue, in: codeString) }
    }

    // --- エフェクト ---

    var shadowRadius: CGFloat {
        get { document.shadowRadiusValue }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "shadow", value: newValue,
                argsTemplate: { "radius: \($0)" }, numberLabel: "radius:", removeWhen: { $0 == 0 }
            )
        }
    }

    var blur: CGFloat {
        get { document.blurValue }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "blur", value: newValue,
                argsTemplate: { "radius: \($0)" }, numberLabel: "radius:", removeWhen: { $0 == 0 }
            )
        }
    }

    var rotation: CGFloat {
        get { document.rotationValue }
        set {
            codeString = SourceEditor.setNumericModifier(
                codeString, name: "rotationEffect", value: newValue,
                argsTemplate: { ".degrees(\($0))" }, numberLabel: nil, removeWhen: { $0 == 0 }
            )
        }
    }

    /// キャンバス描画用の解釈済み仕様
    var renderSpec: RenderSpec {
        document.renderSpec
    }

    // MARK: - Phase 2: JSON 永続化

    /// 現在のdocumentをJSONファイルに保存する
    func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "design.json"
        panel.canCreateDirectories = true
        panel.title = "デザインを保存"

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(self.document)
                try data.write(to: url)
            } catch {
                self.presentError("保存に失敗しました：\(error.localizedDescription)")
            }
        }
    }

    /// JSONファイルを読み込んでコードに反映する
    func loadFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "デザインを読み込み"

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode(DesignDocument.self, from: data)
                // 読み込んだドキュメントからコードを再生成（codeStringの変更でreparseが走る）
                self.codeString = SwiftUICodeParser.serialize(loaded)
            } catch {
                self.presentError("読み込みに失敗しました：\(error.localizedDescription)")
            }
        }
    }

    /// エラーをアラートで表示する
    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "エラー"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
