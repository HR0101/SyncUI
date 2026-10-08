import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.18)

            DotGridBackground()

            renderedText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 5) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 9))
                Text("CANVAS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
            }
            .foregroundColor(Color.white.opacity(0.2))
            .padding(10)
        }
    }

    /// RenderSpecに基づいてTextを組み立てる
    /// Textを返すモディファイア（font/italic/underline/色）を先に適用し，
    /// その後にViewを返すモディファイア（padding/background等）を適用する
    private var renderedText: some View {
        let spec = viewModel.renderSpec

        // Textを返すモディファイア（font/装飾/色/字間）を先に適用
        var text = Text(spec.text)
            .font(.system(size: spec.fontSize ?? 17, weight: spec.fontWeight, design: spec.fontDesign))

        if spec.italic {
            text = text.italic()
        }
        if spec.underline {
            text = text.underline()
        }
        if spec.strikethrough {
            text = text.strikethrough()
        }
        if let color = spec.textColor {
            text = text.foregroundColor(color)
        }
        text = text.kerning(spec.kerning)

        // Viewを返すモディファイア（揃え/行間/余白/背景/エフェクト）を後から適用
        return text
            .multilineTextAlignment(spec.alignment)
            .lineSpacing(spec.lineSpacing)
            .padding(spec.padding ?? 0)
            .background(spec.backgroundColor ?? Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: spec.cornerRadius))
            .opacity(spec.opacity)
            .blur(radius: spec.blur)
            .rotationEffect(.degrees(spec.rotation))
            .shadow(
                color: .black.opacity(spec.shadowRadius > 0 ? 0.45 : 0),
                radius: spec.shadowRadius
            )
    }
}

struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            let dotRadius: CGFloat = 0.9

            var x: CGFloat = spacing
            while x < size.width {
                var y: CGFloat = spacing
                while y < size.height {
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(0.1))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
    }
}
