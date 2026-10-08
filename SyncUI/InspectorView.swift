import SwiftUI

private let inspectorAccent = Color(red: 0.4, green: 0.65, blue: 1.0)

struct InspectorView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                inspectorHeader

                Divider()
                    .background(Color.white.opacity(0.07))

                // CONTENT
                InspectorSection(title: "CONTENT", icon: "text.cursor") {
                    InspectorRow(label: "Text") {
                        TextField("テキストを入力", text: bind(\.textContent))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                sectionDivider

                // TYPOGRAPHY
                InspectorSection(title: "TYPOGRAPHY", icon: "textformat") {
                    InspectorSliderRow(
                        label: "Size",
                        value: bind(\.fontSize),
                        range: 8...120,
                        displayValue: "\(Int(viewModel.fontSize))pt"
                    )

                    InspectorPickerRow(label: "Weight", selection: bind(\.fontWeight)) {
                        ForEach(FontWeightType.allCases, id: \.self) { weight in
                            Text(weight.rawValue.capitalized).tag(weight)
                        }
                    }

                    InspectorPickerRow(label: "Design", selection: bind(\.fontDesign)) {
                        ForEach(FontDesignType.allCases, id: \.self) { design in
                            Text(design.rawValue.capitalized).tag(design)
                        }
                    }

                    InspectorPickerRow(label: "Align", selection: bind(\.textAlign)) {
                        ForEach(TextAlignType.allCases, id: \.self) { align in
                            Text(align.rawValue.capitalized).tag(align)
                        }
                    }

                    InspectorToggleRow(label: "Italic", isOn: bind(\.italic))
                    InspectorToggleRow(label: "Underline", isOn: bind(\.underline))
                    InspectorToggleRow(label: "Strikethrough", isOn: bind(\.strikethrough))

                    InspectorSliderRow(
                        label: "Kerning",
                        value: bind(\.kerning),
                        range: -5...20,
                        displayValue: String(format: "%.1f", viewModel.kerning)
                    )

                    InspectorSliderRow(
                        label: "Line Spacing",
                        value: bind(\.lineSpacing),
                        range: 0...40,
                        displayValue: "\(Int(viewModel.lineSpacing))"
                    )
                }

                sectionDivider

                // COLOR & STYLE
                InspectorSection(title: "COLOR & STYLE", icon: "paintpalette") {
                    InspectorRow(label: "Text Color") {
                        HStack {
                            Spacer()
                            ColorPicker("", selection: bind(\.textColor))
                                .labelsHidden()
                        }
                    }

                    InspectorRow(label: "Background") {
                        HStack {
                            Spacer()
                            ColorPicker("", selection: bind(\.backgroundColor), supportsOpacity: true)
                                .labelsHidden()
                        }
                    }

                    InspectorSliderRow(
                        label: "Opacity",
                        value: bind(\.opacity),
                        range: 0...1,
                        displayValue: "\(Int(viewModel.opacity * 100))%"
                    )
                }

                sectionDivider

                // LAYOUT
                InspectorSection(title: "LAYOUT", icon: "square.dashed") {
                    InspectorSliderRow(
                        label: "Padding",
                        value: bind(\.padding),
                        range: 0...100,
                        displayValue: "\(Int(viewModel.padding))px"
                    )

                    InspectorSliderRow(
                        label: "Corner Radius",
                        value: bind(\.cornerRadius),
                        range: 0...60,
                        displayValue: "\(Int(viewModel.cornerRadius))px"
                    )
                }

                sectionDivider

                // EFFECTS
                InspectorSection(title: "EFFECTS", icon: "sparkles") {
                    InspectorSliderRow(
                        label: "Shadow",
                        value: bind(\.shadowRadius),
                        range: 0...40,
                        displayValue: "\(Int(viewModel.shadowRadius))"
                    )

                    InspectorSliderRow(
                        label: "Blur",
                        value: bind(\.blur),
                        range: 0...30,
                        displayValue: "\(Int(viewModel.blur))"
                    )

                    InspectorSliderRow(
                        label: "Rotation",
                        value: bind(\.rotation),
                        range: -180...180,
                        displayValue: "\(Int(viewModel.rotation))°"
                    )
                }

                Spacer(minLength: 24)
            }
        }
        .frame(width: 290)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }

    // MARK: - バインディング生成

    /// ViewModelの可変プロパティへの双方向バインディングを作る
    private func bind<Value>(_ keyPath: ReferenceWritableKeyPath<EditorViewModel, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - ヘッダーと区切り

    private var inspectorHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.3))

            Text("INSPECTOR")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Color.white.opacity(0.3))

            Spacer()

            Text("Text")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(inspectorAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(inspectorAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sectionDivider: some View {
        Divider()
            .background(Color.white.opacity(0.05))
            .padding(.horizontal, 16)
    }
}

// MARK: - セクションコンテナ

struct InspectorSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.25))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color.white.opacity(0.25))
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            content()

            Spacer(minLength: 8)
        }
    }
}

// MARK: - 汎用行コンポーネント

struct InspectorRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.55))
                .frame(width: 86, alignment: .leading)

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}

// MARK: - スライダー行

struct InspectorSliderRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let displayValue: String

    var body: some View {
        InspectorRow(label: label) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range)
                    .tint(inspectorAccent)

                Text(displayValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(minWidth: 38, alignment: .trailing)
            }
        }
    }
}

// MARK: - トグル行

struct InspectorToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        InspectorRow(label: label) {
            HStack {
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(inspectorAccent)
            }
        }
    }
}

// MARK: - ピッカー行

struct InspectorPickerRow<Selection: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    var body: some View {
        InspectorRow(label: label) {
            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
