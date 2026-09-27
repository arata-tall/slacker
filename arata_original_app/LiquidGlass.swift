import SwiftUI

/// iOS 17 以降でも使える、リキッドグラス調の共通スタイル。
/// 半透明のマテリアルと淡いハイライトで、画面ごとの見た目を統一する。
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.95, blue: 1.0),
                         Color(red: 0.97, green: 0.94, blue: 1.0),
                         Color(red: 0.91, green: 0.98, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: -130, y: -280)

            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 46)
                .offset(x: 150, y: 310)
        }
        .ignoresSafeArea()
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 7)
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// ナビゲーションバーも含めたメイン画面の半透明背景。
    func liquidGlassScreen() -> some View {
        background(LiquidGlassBackground())
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// List / Form 用。システムの不透明な背景を外してグラス背景を見せる。
    func liquidGlassForm() -> some View {
        scrollContentBackground(.hidden)
            .background(LiquidGlassBackground())
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// どのメイン画面からでもチャットを開ける、右端から少しせり出すSlackerボタン。
struct SlackerFloatingButton: View {
    @Environment(SlackerNavigationStore.self) private var navigation

    /// このボタンがあるタブ。別のタブへ移った時だけ、その画面を閉じる。
    let tab: Int

    var body: some View {
        NavigationLink(isActive: Binding(
            get: { navigation.originTab == tab },
            set: { isActive in navigation.originTab = isActive ? tab : nil }
        )) {
            SlackerView()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 54, height: 108)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                }
                .shadow(color: Color.accentColor.opacity(0.2), radius: 14, x: 0, y: 7)
        }
        .accessibilityLabel("Slackerを開く")
    }
}
