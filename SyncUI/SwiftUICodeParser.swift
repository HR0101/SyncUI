import Foundation
import SwiftUI

// MARK: - パーサー / シリアライザ

/// SwiftUIコード文字列とDesignDocumentを相互変換する
/// （Text(...) とそれに続くモディファイアチェーンを文字列スキャナで解析する）
enum SwiftUICodeParser {

    // MARK: コード → DesignDocument

    /// コードを解析してDesignDocumentを返す．Text呼び出しが見つからなければnil
    static func parse(_ code: String) -> DesignDocument? {
        let chars = Array(code)

        guard let textIndex = findTextCall(in: chars) else { return nil }

        // "Text" の直後（カッコ）まで進める
        var index = skipWhitespace(chars, textIndex + 4)
        guard index < chars.count, chars[index] == "(" else { return nil }

        // Text(...) の中身を取得し，最初の文字列リテラルをテキストとして抽出
        guard let (argContent, afterText) = readBalancedParens(chars, openIndex: index) else { return nil }
        guard let literal = firstStringLiteral(in: argContent) else { return nil }
        let displayText = unescape(literal)

        // モディファイアチェーンを順に解析
        var modifiers: [UIModifier] = []
        index = afterText

        while true {
            let dotIndex = skipWhitespaceAndNewlines(chars, index)
            guard dotIndex < chars.count, chars[dotIndex] == "." else { break }

            // モディファイア名を読む
            var nameEnd = dotIndex + 1
            var nameChars: [Character] = []
            while nameEnd < chars.count, isIdentifierChar(chars[nameEnd]) {
                nameChars.append(chars[nameEnd])
                nameEnd += 1
            }
            guard !nameChars.isEmpty else { break }
            let name = String(nameChars)

            // カッコの有無を確認
            let parenIndex = skipWhitespace(chars, nameEnd)
            if parenIndex < chars.count, chars[parenIndex] == "(" {
                guard let (args, after) = readBalancedParens(chars, openIndex: parenIndex) else { break }
                let trimmed = args.trimmingCharacters(in: .whitespacesAndNewlines)
                modifiers.append(UIModifier(name: name, arguments: trimmed))
                index = after
            } else {
                // カッコ無しモディファイア（例：.bold）
                modifiers.append(UIModifier(name: name, arguments: nil))
                index = nameEnd
            }
        }

        return DesignDocument(text: displayText, modifiers: modifiers)
    }

    // MARK: DesignDocument → コード

    /// DesignDocumentから整形済みのSwiftUIコードを生成する
    static func serialize(_ document: DesignDocument) -> String {
        var lines: [String] = []
        lines.append("import SwiftUI")
        lines.append("")
        lines.append("struct GeneratedView: View {")
        lines.append("    var body: some View {")
        lines.append("        Text(\"\(escape(document.text))\")")

        for modifier in document.modifiers {
            if let args = modifier.arguments {
                lines.append("            .\(modifier.name)(\(args))")
            } else {
                lines.append("            .\(modifier.name)")
            }
        }

        lines.append("    }")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - スキャナ補助

    /// 単独の "Text(" を探してその先頭インデックスを返す
    private static func findTextCall(in chars: [Character]) -> Int? {
        let count = chars.count
        var i = 0
        while i <= count - 4 {
            if chars[i] == "T", chars[i + 1] == "e", chars[i + 2] == "x", chars[i + 3] == "t" {
                let prevIsBoundary = (i == 0) || !isIdentifierChar(chars[i - 1])
                let parenIndex = skipWhitespace(chars, i + 4)
                if prevIsBoundary, parenIndex < count, chars[parenIndex] == "(" {
                    return i
                }
            }
            i += 1
        }
        return nil
    }

    /// openIndex（'('）から対応する閉じカッコまでを読み，中身と閉じカッコの次の位置を返す
    /// 文字列リテラル内のカッコ・クォートは無視する
    private static func readBalancedParens(_ chars: [Character], openIndex: Int) -> (String, Int)? {
        var depth = 0
        var i = openIndex
        var content: [Character] = []
        var inString = false
        let count = chars.count

        while i < count {
            let c = chars[i]

            if inString {
                content.append(c)
                if c == "\\", i + 1 < count {
                    content.append(chars[i + 1])
                    i += 2
                    continue
                }
                if c == "\"" {
                    inString = false
                }
                i += 1
                continue
            }

            switch c {
            case "\"":
                inString = true
                content.append(c)
            case "(":
                depth += 1
                if depth > 1 { content.append(c) } // 最外カッコは含めない
            case ")":
                depth -= 1
                if depth == 0 {
                    return (String(content), i + 1)
                } else {
                    content.append(c)
                }
            default:
                content.append(c)
            }
            i += 1
        }
        return nil
    }

    /// 文字列中の最初のダブルクォート文字列リテラルの中身（エスケープ込み）を返す
    private static func firstStringLiteral(in source: String) -> String? {
        let chars = Array(source)
        let count = chars.count
        var i = 0
        while i < count {
            if chars[i] == "\"" {
                var j = i + 1
                var literal: [Character] = []
                while j < count {
                    if chars[j] == "\\", j + 1 < count {
                        literal.append(chars[j])
                        literal.append(chars[j + 1])
                        j += 2
                        continue
                    }
                    if chars[j] == "\"" {
                        return String(literal)
                    }
                    literal.append(chars[j])
                    j += 1
                }
                return nil
            }
            i += 1
        }
        return nil
    }

    // MARK: - エスケープ処理

    /// リテラル内のエスケープを実際の文字へ展開する
    private static func unescape(_ source: String) -> String {
        var result = ""
        let chars = Array(source)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count {
                switch chars[i + 1] {
                case "n":  result.append("\n")
                case "t":  result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default:   result.append(chars[i + 1])
                }
                i += 2
            } else {
                result.append(chars[i])
                i += 1
            }
        }
        return result
    }

    /// 表示用文字列をリテラル用にエスケープする
    private static func escape(_ source: String) -> String {
        var result = ""
        for c in source {
            switch c {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            default:   result.append(c)
            }
        }
        return result
    }

    // MARK: - 文字種判定

    private static func isIdentifierChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }

    private static func skipWhitespace(_ chars: [Character], _ index: Int) -> Int {
        var i = index
        while i < chars.count, chars[i] == " " || chars[i] == "\t" {
            i += 1
        }
        return i
    }

    private static func skipWhitespaceAndNewlines(_ chars: [Character], _ index: Int) -> Int {
        var i = index
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                i += 1
            } else {
                break
            }
        }
        return i
    }
}

// MARK: - 値抽出ユーティリティ

/// モディファイアの引数文字列から数値・色・ウェイトなどを取り出す
enum ValueExtractor {

    // MARK: 数値

    /// 引数中の最初の数値を返す
    static func number(in text: String) -> Double? {
        firstMatch(pattern: #"(-?\d+(?:\.\d+)?)"#, in: text).flatMap(Double.init)
    }

    /// 指定ラベル（例："size:"）の直後の数値を返す
    static func number(after label: String, in text: String) -> Double? {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        let pattern = escaped + #"\s*(-?\d+(?:\.\d+)?)"#
        return firstMatch(pattern: pattern, in: text).flatMap(Double.init)
    }

    // MARK: フォントウェイト

    static func weight(in text: String) -> FontWeightType? {
        guard let raw = firstMatch(pattern: #"weight:\s*\.([a-zA-Z]+)"#, in: text) else { return nil }
        return FontWeightType(rawValue: raw)
    }

    // MARK: 列挙ケース

    /// 指定ラベル（例："design:"）の直後の .case 名を返す
    static func enumCase(after label: String, in text: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        return firstMatch(pattern: escaped + #"\s*\.([a-zA-Z0-9_]+)"#, in: text)
    }

    /// 引数中の最初の .case 名を返す（例：".center" → "center"）
    static func firstCase(in text: String) -> String? {
        firstMatch(pattern: #"\.([a-zA-Z][a-zA-Z0-9_]*)"#, in: text)
    }

    // MARK: フォントプリセット

    /// .title などのプリセットフォントを近似サイズに変換する
    static func fontPresetSize(in text: String) -> CGFloat? {
        let presets: [(String, CGFloat)] = [
            ("largeTitle", 34), ("title2", 22), ("title3", 20), ("title", 28),
            ("headline", 17), ("subheadline", 15), ("body", 17),
            ("callout", 16), ("footnote", 13), ("caption2", 11), ("caption", 12)
        ]
        for (name, size) in presets where text.contains(".\(name)") {
            return size
        }
        return nil
    }

    // MARK: 色

    /// 引数文字列から色を解析する（RGB形式・名前付きカラー両対応）
    static func color(in text: String) -> CodableColor? {
        if let rgb = rgbColor(in: text) { return rgb }
        return namedColor(in: text)
    }

    /// Color(red:, green:, blue:[, opacity:]) 形式を解析する
    private static func rgbColor(in text: String) -> CodableColor? {
        let pattern = #"red:\s*([0-9.]+),\s*green:\s*([0-9.]+),\s*blue:\s*([0-9.]+)(?:,\s*opacity:\s*([0-9.]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: text, range: range) else { return nil }

        let r = Double(nsString.substring(with: result.range(at: 1))) ?? 0
        let g = Double(nsString.substring(with: result.range(at: 2))) ?? 0
        let b = Double(nsString.substring(with: result.range(at: 3))) ?? 0
        let a = result.range(at: 4).location != NSNotFound
            ? (Double(nsString.substring(with: result.range(at: 4))) ?? 1.0)
            : 1.0
        return CodableColor(red: r, green: g, blue: b, alpha: a)
    }

    /// .blue や Color.white のような名前付きカラーを解析する
    private static func namedColor(in text: String) -> CodableColor? {
        let pattern = #"(?:Color\s*\.|\.)\s*([a-zA-Z]+)"#
        guard let raw = firstMatch(pattern: pattern, in: text) else { return nil }
        return namedColors[raw]
    }

    /// SwiftUI標準カラーのRGB近似値
    private static let namedColors: [String: CodableColor] = [
        "white":     CodableColor(red: 1,    green: 1,    blue: 1,    alpha: 1),
        "black":     CodableColor(red: 0,    green: 0,    blue: 0,    alpha: 1),
        "primary":   CodableColor(red: 1,    green: 1,    blue: 1,    alpha: 1),
        "secondary": CodableColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1),
        "red":       CodableColor(red: 1,    green: 0.27, blue: 0.23, alpha: 1),
        "orange":    CodableColor(red: 1,    green: 0.62, blue: 0,    alpha: 1),
        "yellow":    CodableColor(red: 1,    green: 0.84, blue: 0,    alpha: 1),
        "green":     CodableColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1),
        "mint":      CodableColor(red: 0.39, green: 0.9,  blue: 0.89, alpha: 1),
        "teal":      CodableColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1),
        "cyan":      CodableColor(red: 0.39, green: 0.82, blue: 1,    alpha: 1),
        "blue":      CodableColor(red: 0.25, green: 0.56, blue: 1,    alpha: 1),
        "indigo":    CodableColor(red: 0.37, green: 0.36, blue: 0.9,  alpha: 1),
        "purple":    CodableColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1),
        "pink":      CodableColor(red: 1,    green: 0.22, blue: 0.37, alpha: 1),
        "brown":     CodableColor(red: 0.67, green: 0.56, blue: 0.41, alpha: 1),
        "gray":      CodableColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1),
        "clear":     CodableColor(red: 0,    green: 0,    blue: 0,    alpha: 0)
    ]

    // MARK: コード生成

    /// CodableColorをColor(...)コード文字列に変換する
    static func colorCode(_ color: CodableColor) -> String {
        let r = String(format: "%.3f", color.red)
        let g = String(format: "%.3f", color.green)
        let b = String(format: "%.3f", color.blue)
        if color.alpha >= 0.999 {
            return "Color(red: \(r), green: \(g), blue: \(b))"
        } else {
            let a = String(format: "%.3f", color.alpha)
            return "Color(red: \(r), green: \(g), blue: \(b), opacity: \(a))"
        }
    }

    /// 数値を整数なら整数表記，そうでなければ小数1桁で文字列化する
    static func format(_ value: CGFloat) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    // MARK: 内部ヘルパー

    /// パターンの最初のキャプチャグループ（group 1）を返す
    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: text, range: range),
              result.numberOfRanges > 1 else { return nil }
        return nsString.substring(with: result.range(at: 1))
    }
}
