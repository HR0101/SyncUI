import Foundation

// MARK: - ソース上の位置情報

/// ソースコード中の1モディファイアの位置（文字オフセット）
struct ModifierMatch {
    let name: String
    /// カッコ内引数の範囲（カッコ無しモディファイアの場合はnil）
    let argsRange: Range<Int>?
    /// ".name(...)" 全体の範囲
    let fullRange: Range<Int>
}

/// 解析されたTextビューのソース上の位置情報
struct ViewMatch {
    /// Text("...") の文字列リテラル中身の範囲
    let textRange: Range<Int>
    let modifiers: [ModifierMatch]
    /// 新規モディファイアを挿入する位置（チェーン末尾）
    let insertionIndex: Int
}

// MARK: - 外科的ソース編集

/// コード文字列を再生成せず，変更箇所だけをピンポイントで書き換えるエディタ
///
/// インスペクタ操作時にコード全体の書式・コメント・未知モディファイアを保持したまま，
/// 対象の値だけを置換・挿入・削除する．
enum SourceEditor {

    // MARK: テキスト内容

    static func setText(_ value: String, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        return String(replace(chars, view.textRange, with: escape(value)))
    }

    // MARK: フォントサイズ

    static func setFontSize(_ size: CGFloat, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let sizeStr = ValueExtractor.format(size)

        guard let font = view.modifiers.first(where: { $0.name == "font" }) else {
            return inserted(chars, view: view, modifier: ".font(.system(size: \(sizeStr)))")
        }
        guard let argsRange = font.argsRange else {
            return String(replace(chars, font.fullRange, with: ".font(.system(size: \(sizeStr)))"))
        }

        let args = Array(chars[argsRange])
        if let numberRange = rangeOfNumber(after: "size:", in: args) {
            let absolute = shift(numberRange, by: argsRange.lowerBound)
            return String(replace(chars, absolute, with: sizeStr))
        } else {
            // size: が無い（プリセット等）場合は .system(...) 形式に正規化
            let weight = ValueExtractor.weight(in: String(args)) ?? .regular
            let newArgs = ".system(size: \(sizeStr), weight: .\(weight.rawValue))"
            return String(replace(chars, argsRange, with: newArgs))
        }
    }

    // MARK: フォントウェイト

    static func setFontWeight(_ weight: FontWeightType, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let weightName = weight.rawValue

        guard let font = view.modifiers.first(where: { $0.name == "font" }) else {
            return inserted(chars, view: view, modifier: ".font(.system(size: 17, weight: .\(weightName)))")
        }
        guard let argsRange = font.argsRange else {
            return String(replace(chars, font.fullRange, with: ".font(.system(size: 17, weight: .\(weightName)))"))
        }

        let args = Array(chars[argsRange])
        if let weightRange = rangeOfWeightValue(in: args) {
            let absolute = shift(weightRange, by: argsRange.lowerBound)
            return String(replace(chars, absolute, with: weightName))
        } else {
            // weight: が無い場合は現在のサイズを維持して .system(...) 形式に正規化
            let sizeStr: String
            if let sizeRange = rangeOfNumber(after: "size:", in: args) {
                sizeStr = String(args[sizeRange])
            } else if let preset = ValueExtractor.fontPresetSize(in: String(args)) {
                sizeStr = ValueExtractor.format(preset)
            } else {
                sizeStr = "17"
            }
            let newArgs = ".system(size: \(sizeStr), weight: .\(weightName))"
            return String(replace(chars, argsRange, with: newArgs))
        }
    }

    // MARK: 文字色

    static func setTextColor(_ color: CodableColor, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let colorCode = ValueExtractor.colorCode(color)

        let target = view.modifiers.first(where: { $0.name == "foregroundColor" })
            ?? view.modifiers.first(where: { $0.name == "foregroundStyle" })

        guard let modifier = target, let argsRange = modifier.argsRange else {
            return inserted(chars, view: view, modifier: ".foregroundColor(\(colorCode))")
        }
        return String(replace(chars, argsRange, with: colorCode))
    }

    // MARK: 背景色

    static func setBackgroundColor(_ color: CodableColor, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let existing = view.modifiers.first { $0.name == "background" }

        // 透明なら背景モディファイアを削除
        if color.alpha <= 0.001 {
            if let modifier = existing {
                return String(removeLine(chars, modifier))
            }
            return code
        }

        let colorCode = ValueExtractor.colorCode(color)
        guard let modifier = existing, let argsRange = modifier.argsRange else {
            return inserted(chars, view: view, modifier: ".background(\(colorCode))")
        }
        return String(replace(chars, argsRange, with: colorCode))
    }

    // MARK: パディング

    static func setPadding(_ value: CGFloat, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let existing = view.modifiers.first { $0.name == "padding" }

        if value <= 0 {
            if let modifier = existing {
                return String(removeLine(chars, modifier))
            }
            return code
        }

        let valueStr = ValueExtractor.format(value)
        guard let modifier = existing else {
            return inserted(chars, view: view, modifier: ".padding(\(valueStr))")
        }
        guard let argsRange = modifier.argsRange else {
            return String(replace(chars, modifier.fullRange, with: ".padding(\(valueStr))"))
        }

        let args = Array(chars[argsRange])
        if let numberRange = rangeOfFirstNumber(in: args) {
            let absolute = shift(numberRange, by: argsRange.lowerBound)
            return String(replace(chars, absolute, with: valueStr))
        } else {
            // .padding() のような空引数 → .padding(value)
            return String(replace(chars, argsRange, with: valueStr))
        }
    }

    // MARK: 角丸

    static func setCornerRadius(_ value: CGFloat, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let valueStr = ValueExtractor.format(value)

        // .cornerRadius(...) 形式が優先
        if let modifier = view.modifiers.first(where: { $0.name == "cornerRadius" }) {
            if value <= 0 {
                return String(removeLine(chars, modifier))
            }
            if let argsRange = modifier.argsRange,
               let numberRange = rangeOfFirstNumber(in: Array(chars[argsRange])) {
                let absolute = shift(numberRange, by: argsRange.lowerBound)
                return String(replace(chars, absolute, with: valueStr))
            }
            return String(replace(chars, modifier.fullRange, with: ".cornerRadius(\(valueStr))"))
        }

        // .clipShape(RoundedRectangle(cornerRadius: ...)) 形式
        if let modifier = view.modifiers.first(where: { $0.name == "clipShape" }),
           let argsRange = modifier.argsRange {
            if value <= 0 {
                return String(removeLine(chars, modifier))
            }
            let args = Array(chars[argsRange])
            if let numberRange = rangeOfNumber(after: "cornerRadius:", in: args) {
                let absolute = shift(numberRange, by: argsRange.lowerBound)
                return String(replace(chars, absolute, with: valueStr))
            }
            // RoundedRectangle以外のclipShapeは編集しない
            return code
        }

        if value <= 0 { return code }
        return inserted(chars, view: view, modifier: ".clipShape(RoundedRectangle(cornerRadius: \(valueStr)))")
    }

    // MARK: フォント書体

    static func setFontDesign(_ design: FontDesignType, size: CGFloat, weight: FontWeightType, in code: String) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }

        let sizeStr = ValueExtractor.format(size)
        var args = ".system(size: \(sizeStr), weight: .\(weight.rawValue)"
        if design != .default { args += ", design: .\(design.rawValue)" }
        args += ")"

        if let font = view.modifiers.first(where: { $0.name == "font" }) {
            if let argsRange = font.argsRange {
                return String(replace(chars, argsRange, with: args))
            }
            return String(replace(chars, font.fullRange, with: ".font(\(args))"))
        }
        return inserted(chars, view: view, modifier: ".font(\(args))")
    }

    // MARK: 汎用：数値モディファイア

    /// 数値1つを持つモディファイアを設定する汎用関数
    /// - argsTemplate: 値文字列から引数文字列を作る（例：{ "radius: \($0)" }）
    /// - numberLabel: 既存args内で数値を探すラベル（nilなら最初の数値）
    /// - removeWhen: この条件を満たす値ならモディファイアごと削除
    static func setNumericModifier(
        _ code: String,
        name: String,
        value: CGFloat,
        argsTemplate: (String) -> String,
        numberLabel: String?,
        removeWhen: (CGFloat) -> Bool
    ) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let existing = view.modifiers.first { $0.name == name }

        if removeWhen(value) {
            if let modifier = existing { return String(removeLine(chars, modifier)) }
            return code
        }

        let valueStr = ValueExtractor.format(value)
        guard let modifier = existing else {
            return inserted(chars, view: view, modifier: ".\(name)(\(argsTemplate(valueStr)))")
        }
        guard let argsRange = modifier.argsRange else {
            return String(replace(chars, modifier.fullRange, with: ".\(name)(\(argsTemplate(valueStr)))"))
        }

        let args = Array(chars[argsRange])
        let numberRange = numberLabel.flatMap { rangeOfNumber(after: $0, in: args) }
            ?? rangeOfFirstNumber(in: args)
        if let numberRange {
            let absolute = shift(numberRange, by: argsRange.lowerBound)
            return String(replace(chars, absolute, with: valueStr))
        }
        return String(replace(chars, argsRange, with: argsTemplate(valueStr)))
    }

    // MARK: 汎用：トグルモディファイア

    /// 引数無しモディファイア（例：.italic()）の有無を切り替える
    static func setToggleModifier(_ code: String, name: String, on: Bool) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let existing = view.modifiers.first { $0.name == name }

        if on {
            if existing != nil { return code }
            return inserted(chars, view: view, modifier: ".\(name)()")
        } else {
            if let modifier = existing { return String(removeLine(chars, modifier)) }
            return code
        }
    }

    // MARK: 汎用：列挙モディファイア

    /// .name(.case) 形式のモディファイアを設定する
    /// - removeWhenCase: このケース名なら削除（既定値の場合に省略する用途）
    static func setEnumModifier(_ code: String, name: String, caseName: String, removeWhenCase: String?) -> String {
        let chars = Array(code)
        guard let view = parse(chars) else { return code }
        let existing = view.modifiers.first { $0.name == name }

        if let removeCase = removeWhenCase, caseName == removeCase {
            if let modifier = existing { return String(removeLine(chars, modifier)) }
            return code
        }

        let args = ".\(caseName)"
        guard let modifier = existing, let argsRange = modifier.argsRange else {
            return inserted(chars, view: view, modifier: ".\(name)(\(args))")
        }
        return String(replace(chars, argsRange, with: args))
    }

    // MARK: - 解析（位置情報付き）

    /// コードをスキャンしてViewMatch（位置情報）を返す
    private static func parse(_ chars: [Character]) -> ViewMatch? {
        guard let textIndex = findTextCall(in: chars) else { return nil }

        var index = skipWhitespace(chars, textIndex + 4)
        guard index < chars.count, chars[index] == "(" else { return nil }
        guard let (innerStart, innerEnd, afterText) = readParens(chars, openIndex: index) else { return nil }
        guard let textRange = firstStringLiteralRange(chars, from: innerStart, to: innerEnd) else { return nil }

        var modifiers: [ModifierMatch] = []
        index = afterText
        var insertionIndex = afterText

        while true {
            let dotIndex = skipWhitespaceAndNewlines(chars, index)
            guard dotIndex < chars.count, chars[dotIndex] == "." else { break }

            var nameEnd = dotIndex + 1
            var nameChars: [Character] = []
            while nameEnd < chars.count, isIdentifierChar(chars[nameEnd]) {
                nameChars.append(chars[nameEnd])
                nameEnd += 1
            }
            guard !nameChars.isEmpty else { break }
            let name = String(nameChars)

            let parenIndex = skipWhitespace(chars, nameEnd)
            if parenIndex < chars.count, chars[parenIndex] == "(" {
                guard let (aStart, aEnd, after) = readParens(chars, openIndex: parenIndex) else { break }
                modifiers.append(ModifierMatch(name: name, argsRange: aStart..<aEnd, fullRange: dotIndex..<after))
                index = after
                insertionIndex = after
            } else {
                modifiers.append(ModifierMatch(name: name, argsRange: nil, fullRange: dotIndex..<nameEnd))
                index = nameEnd
                insertionIndex = nameEnd
            }
        }

        return ViewMatch(textRange: textRange, modifiers: modifiers, insertionIndex: insertionIndex)
    }

    // MARK: - スキャナ補助

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

    /// openIndex（'('）から対応する閉じカッコまでを読み，(中身開始, 中身終了, 閉じ次) を返す
    private static func readParens(_ chars: [Character], openIndex: Int) -> (Int, Int, Int)? {
        var depth = 0
        var i = openIndex
        var inString = false
        let count = chars.count
        let innerStart = openIndex + 1

        while i < count {
            let c = chars[i]
            if inString {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            switch c {
            case "\"":
                inString = true
            case "(":
                depth += 1
            case ")":
                depth -= 1
                if depth == 0 {
                    return (innerStart, i, i + 1)
                }
            default:
                break
            }
            i += 1
        }
        return nil
    }

    /// from..<to の範囲内で最初の文字列リテラルの中身範囲を返す
    private static func firstStringLiteralRange(_ chars: [Character], from: Int, to: Int) -> Range<Int>? {
        var i = from
        while i < to {
            if chars[i] == "\"" {
                var j = i + 1
                while j < to {
                    if chars[j] == "\\" {
                        j += 2
                        continue
                    }
                    if chars[j] == "\"" {
                        return (i + 1)..<j
                    }
                    j += 1
                }
                return nil
            }
            i += 1
        }
        return nil
    }

    // MARK: - 文字列内検索（0始まりのスライス前提）

    private static func rangeOfSubstring(_ needle: [Character], in hay: [Character]) -> Range<Int>? {
        guard !needle.isEmpty, hay.count >= needle.count else { return nil }
        var i = 0
        while i <= hay.count - needle.count {
            var matched = true
            for k in 0..<needle.count where hay[i + k] != needle[k] {
                matched = false
                break
            }
            if matched { return i..<(i + needle.count) }
            i += 1
        }
        return nil
    }

    private static func rangeOfNumber(after label: String, in slice: [Character]) -> Range<Int>? {
        guard let labelRange = rangeOfSubstring(Array(label), in: slice) else { return nil }
        var j = labelRange.upperBound
        while j < slice.count, slice[j] == " " || slice[j] == "\t" { j += 1 }
        let start = j
        if j < slice.count, slice[j] == "-" { j += 1 }
        while j < slice.count, slice[j].isNumber || slice[j] == "." { j += 1 }
        return j > start ? start..<j : nil
    }

    private static func rangeOfFirstNumber(in slice: [Character]) -> Range<Int>? {
        var i = 0
        while i < slice.count {
            if slice[i].isNumber {
                let start = i
                var j = i
                while j < slice.count, slice[j].isNumber || slice[j] == "." { j += 1 }
                return start..<j
            }
            i += 1
        }
        return nil
    }

    private static func rangeOfWeightValue(in slice: [Character]) -> Range<Int>? {
        guard let labelRange = rangeOfSubstring(Array("weight:"), in: slice) else { return nil }
        var j = labelRange.upperBound
        while j < slice.count, slice[j] == " " || slice[j] == "\t" { j += 1 }
        if j < slice.count, slice[j] == "." { j += 1 }
        let start = j
        while j < slice.count, slice[j].isLetter { j += 1 }
        return j > start ? start..<j : nil
    }

    // MARK: - 編集操作

    private static func replace(_ chars: [Character], _ range: Range<Int>, with text: String) -> [Character] {
        var result = chars
        result.replaceSubrange(range, with: Array(text))
        return result
    }

    /// モディファイア行ごと削除する（直前の改行とインデントも含めて除去）
    private static func removeLine(_ chars: [Character], _ modifier: ModifierMatch) -> [Character] {
        var start = modifier.fullRange.lowerBound
        var k = start - 1
        while k >= 0, chars[k] == " " || chars[k] == "\t" { k -= 1 }
        if k >= 0, chars[k] == "\n" { start = k }
        var result = chars
        result.removeSubrange(start..<modifier.fullRange.upperBound)
        return result
    }

    /// チェーン末尾に新しいモディファイアを挿入する
    private static func inserted(_ chars: [Character], view: ViewMatch, modifier: String) -> String {
        let indent = chainIndent(chars, view)
        let insertion = "\n" + indent + modifier
        var result = chars
        result.insert(contentsOf: Array(insertion), at: view.insertionIndex)
        return String(result)
    }

    /// モディファイアチェーンのインデント文字列を推定する
    private static func chainIndent(_ chars: [Character], _ view: ViewMatch) -> String {
        // 既存モディファイアがあればそのインデントに合わせる
        if let first = view.modifiers.first {
            let dot = first.fullRange.lowerBound
            var k = dot - 1
            var whitespace: [Character] = []
            while k >= 0, chars[k] == " " || chars[k] == "\t" {
                whitespace.insert(chars[k], at: 0)
                k += -1
            }
            if k >= 0, chars[k] == "\n" {
                return String(whitespace)
            }
        }
        // 無ければTextの行インデント + 4スペース
        var k = view.textRange.lowerBound
        while k >= 0, chars[k] != "\n" { k -= 1 }
        var whitespace: [Character] = []
        var m = k + 1
        while m < chars.count, chars[m] == " " || chars[m] == "\t" {
            whitespace.append(chars[m])
            m += 1
        }
        return String(whitespace) + "    "
    }

    // MARK: - その他補助

    private static func shift(_ range: Range<Int>, by offset: Int) -> Range<Int> {
        (range.lowerBound + offset)..<(range.upperBound + offset)
    }

    private static func isIdentifierChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }

    private static func skipWhitespace(_ chars: [Character], _ index: Int) -> Int {
        var i = index
        while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
        return i
    }

    private static func skipWhitespaceAndNewlines(_ chars: [Character], _ index: Int) -> Int {
        var i = index
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" { i += 1 } else { break }
        }
        return i
    }

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
}
