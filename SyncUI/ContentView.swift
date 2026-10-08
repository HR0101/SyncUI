import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderBar(
                onSave: viewModel.saveToFile,
                onOpen: viewModel.loadFromFile
            )

            Divider()
                .background(Color.white.opacity(0.08))

            HSplitView {
                VSplitView {
                    CanvasView(viewModel: viewModel)
                        .frame(minWidth: 400, minHeight: 280)

                    CodeView(
                        code: $viewModel.codeString,
                        parseError: viewModel.parseError,
                        onApply: viewModel.parseFromCode
                    )
                    .frame(minHeight: 200)
                }
                .frame(minWidth: 500)

                InspectorView(viewModel: viewModel)
                    .frame(minWidth: 270, maxWidth: 320)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .preferredColorScheme(.dark)
    }
}

struct AppHeaderBar: View {
    var onSave: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.3.layers.3d.top.filled")
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.system(size: 18, weight: .semibold))

            Text("SyncUI")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text("Visual Editor")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.4))

            Spacer()

            // ファイル操作（Phase 2: JSON 永続化）
            HeaderButton(title: "開く", icon: "folder", action: onOpen)
            HeaderButton(title: "保存", icon: "square.and.arrow.down", action: onSave)

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.12))
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.3, green: 0.8, blue: 0.5))
                    .frame(width: 7, height: 7)
                Text("双方向同期  ·  Code ⇄ GUI")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
        }
        // 左側はウィンドウ信号機ボタンと重ならないよう広めに空ける
        .padding(.leading, 80)
        .padding(.trailing, 18)
        .padding(.vertical, 11)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }
}

/// ヘッダー用の小さなボタン
struct HeaderButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
