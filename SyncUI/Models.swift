import SwiftUI

// MARK: - フォントウェイト

/// Textコンポーネントで使用可能なフォントウェイトの列挙型
enum FontWeightType: String, CaseIterable, Codable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }
}

// MARK: - フォント書体

/// .font(.system(..., design:)) の書体
enum FontDesignType: String, CaseIterable, Codable {
    case `default`, serif, rounded, monospaced

    var design: Font.Design {
        switch self {
        case .default:    return .default
        case .serif:      return .serif
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        }
    }
}

// MARK: - テキスト揃え

/// .multilineTextAlignment(...) の揃え
enum TextAlignType: String, CaseIterable, Codable {
    case leading, center, trailing

    var alignment: TextAlignment {
        switch self {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - カラー

/// SwiftUI ColorをCodableにするラッパー（JSON永続化対応）
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        self.red = Double(resolved.red)
        self.green = Double(resolved.green)
        self.blue = Double(resolved.blue)
        self.alpha = Double(resolved.opacity)
    }
}

// MARK: - 構文ノード

/// Textに付与された1つのモディファイア（例：.font(.system(size: 24))）
/// argumentsはカッコ内の生テキストをそのまま保持し，未知のモディファイアも失わない
struct UIModifier: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// カッコ内の引数文字列．nilの場合はカッコ無し（例：.bold）を表す
    var arguments: String?

    // idはJSONに含めない（手書きJSONでも読み込めるように）
    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
}

/// 解析されたTextコンポーネント全体を表すドキュメント（唯一の状態源）
struct DesignDocument: Codable, Equatable {
    var text: String
    var modifiers: [UIModifier]

    /// アプリ起動時の初期状態
    static var `default`: DesignDocument {
        DesignDocument(
            text: "Hello, SwiftUI!",
            modifiers: [
                UIModifier(name: "font", arguments: ".system(size: 32, weight: .semibold)"),
                UIModifier(name: "foregroundColor", arguments: "Color(red: 1.000, green: 1.000, blue: 1.000)"),
                UIModifier(name: "padding", arguments: "16"),
                UIModifier(name: "background", arguments: "Color(red: 0.270, green: 0.420, blue: 0.950)"),
                UIModifier(name: "clipShape", arguments: "RoundedRectangle(cornerRadius: 12)")
            ]
        )
    }
}

// MARK: - 描画仕様

/// キャンバスがプレビュー描画に使う，解釈済みの値一式
struct RenderSpec {
    var text: String
    var fontSize: CGFloat?
    var fontWeight: Font.Weight
    var fontDesign: Font.Design
    var italic: Bool
    var underline: Bool
    var strikethrough: Bool
    var kerning: CGFloat
    var lineSpacing: CGFloat
    var alignment: TextAlignment
    var textColor: Color?
    var opacity: Double
    var padding: CGFloat?
    var backgroundColor: Color?
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var blur: CGFloat
    var rotation: Double
}

// MARK: - インタプリタ（DesignDocument → 値の取得）

extension DesignDocument {

    /// 既定フォントサイズ（font指定が無い場合のフォールバック）
    static let defaultFontSize: CGFloat = 17

    // --- モディファイア操作ヘルパー ---

    func modifier(named name: String) -> UIModifier? {
        modifiers.first { $0.name == name }
    }

    func hasModifier(_ name: String) -> Bool {
        modifiers.contains { $0.name == name }
    }

    /// 指定モディファイアの引数から最初の数値を取り出す
    func numberArgument(of name: String) -> CGFloat? {
        guard let args = modifier(named: name)?.arguments,
              let value = ValueExtractor.number(in: args) else { return nil }
        return CGFloat(value)
    }

    // --- フォント ---

    var fontSizeValue: CGFloat? {
        guard let args = modifier(named: "font")?.arguments else { return nil }
        if let size = ValueExtractor.number(after: "size:", in: args) {
            return CGFloat(size)
        }
        if let preset = ValueExtractor.fontPresetSize(in: args) {
            return preset
        }
        return nil
    }

    var fontSize: CGFloat { fontSizeValue ?? Self.defaultFontSize }

    var fontWeight: FontWeightType {
        guard let args = modifier(named: "font")?.arguments,
              let weight = ValueExtractor.weight(in: args) else { return .regular }
        return weight
    }

    var fontDesign: FontDesignType {
        guard let args = modifier(named: "font")?.arguments,
              let raw = ValueExtractor.enumCase(after: "design:", in: args),
              let design = FontDesignType(rawValue: raw) else { return .default }
        return design
    }

    // --- 装飾 ---

    var italic: Bool { hasModifier("italic") }
    var underline: Bool { hasModifier("underline") }
    var strikethrough: Bool { hasModifier("strikethrough") }
    var kerning: CGFloat { numberArgument(of: "kerning") ?? 0 }
    var lineSpacing: CGFloat { numberArgument(of: "lineSpacing") ?? 0 }

    var textAlign: TextAlignType {
        guard let args = modifier(named: "multilineTextAlignment")?.arguments,
              let raw = ValueExtractor.firstCase(in: args),
              let align = TextAlignType(rawValue: raw) else { return .leading }
        return align
    }

    // --- 色 ---

    var textColor: CodableColor? {
        if let args = modifier(named: "foregroundColor")?.arguments {
            return ValueExtractor.color(in: args)
        }
        if let args = modifier(named: "foregroundStyle")?.arguments {
            return ValueExtractor.color(in: args)
        }
        return nil
    }

    var backgroundColor: CodableColor? {
        guard let args = modifier(named: "background")?.arguments else { return nil }
        return ValueExtractor.color(in: args)
    }

    var opacityValue: Double {
        guard let args = modifier(named: "opacity")?.arguments,
              let value = ValueExtractor.number(in: args) else { return 1.0 }
        return value
    }

    // --- レイアウト ---

    var paddingValue: CGFloat? {
        guard let modifier = modifier(named: "padding") else { return nil }
        guard let args = modifier.arguments, !args.isEmpty else { return 16 }
        if let value = ValueExtractor.number(in: args) { return CGFloat(value) }
        return 16
    }

    var padding: CGFloat { paddingValue ?? 0 }

    var cornerRadius: CGFloat {
        if let args = modifier(named: "cornerRadius")?.arguments,
           let value = ValueExtractor.number(in: args) {
            return CGFloat(value)
        }
        if let args = modifier(named: "clipShape")?.arguments,
           let value = ValueExtractor.number(after: "cornerRadius:", in: args) {
            return CGFloat(value)
        }
        return 0
    }

    // --- エフェクト ---

    var shadowRadiusValue: CGFloat {
        guard let args = modifier(named: "shadow")?.arguments else { return 0 }
        if let value = ValueExtractor.number(after: "radius:", in: args) {
            return CGFloat(value)
        }
        return 0
    }

    var blurValue: CGFloat {
        guard let args = modifier(named: "blur")?.arguments else { return 0 }
        if let value = ValueExtractor.number(after: "radius:", in: args) {
            return CGFloat(value)
        }
        if let value = ValueExtractor.number(in: args) {
            return CGFloat(value)
        }
        return 0
    }

    var rotationValue: CGFloat {
        guard let args = modifier(named: "rotationEffect")?.arguments,
              let value = ValueExtractor.number(in: args) else { return 0 }
        return CGFloat(value)
    }

    // --- 描画仕様の生成 ---

    var renderSpec: RenderSpec {
        RenderSpec(
            text: text,
            fontSize: fontSizeValue,
            fontWeight: fontWeight.weight,
            fontDesign: fontDesign.design,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough,
            kerning: kerning,
            lineSpacing: lineSpacing,
            alignment: textAlign.alignment,
            textColor: textColor?.color,
            opacity: opacityValue,
            padding: paddingValue,
            backgroundColor: backgroundColor?.color,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadiusValue,
            blur: blurValue,
            rotation: Double(rotationValue)
        )
    }
}
