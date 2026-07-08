import SwiftUI

// MARK: - Palette

/// Design tokens for the whole app. Dark-only theme (the app forces
/// `.preferredColorScheme(.dark)` at the root), lime accent matching the
/// Podo web dashboard's aesthetic.
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }

    /// Screen background.
    static let appBackground = Color(hex: 0x0A0A0A)
    /// Cards, list rows, fields.
    static let appSurface = Color(hex: 0x151515)
    /// Elements floating above surfaces (mini player, sheets' cards).
    static let appSurfaceRaised = Color(hex: 0x1D1D1D)
    /// Hairline borders.
    static let appBorder = Color(hex: 0x262626)
    /// Primary accent — buttons, active states, progress.
    static let appAccent = Color(hex: 0xB8D148)
    /// Softer accent for gradients/secondary highlights.
    static let appAccentSoft = Color(hex: 0xC5D86D)
    static let appTextPrimary = Color(hex: 0xF2F2F2)
    static let appTextSecondary = Color(hex: 0xA1A1A1)
    static let appTextTertiary = Color(hex: 0x6B6B6B)
    static let appDanger = Color(hex: 0xE5484D)
}

// MARK: - Buttons

/// Filled lime pill — the one primary action per screen. Black text on the
/// light accent for contrast (Spotify-style).
struct AccentButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Color.appAccent
                    .opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Dark card button with a hairline border — secondary actions and icon wells.
struct SurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.appTextPrimary)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(
                Color.appSurfaceRaised
                    .opacity(configuration.isPressed ? 0.6 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Fields

/// Dark rounded input well. Apply to `TextField`/`SecureField` after
/// `.textFieldStyle(.plain)` is implied by the modifier itself.
struct ThemedField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

// MARK: - Screens & lists

extension View {
    func themedField() -> some View {
        modifier(ThemedField())
    }

    /// Full-bleed dark background for a screen.
    func themedScreen() -> some View {
        self
            .background(Color.appBackground.ignoresSafeArea())
    }

    /// Dark background for `List`/`Form` — hides the system grouped background.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
    }

    /// Standard row treatment inside a themed `List`.
    func themedRow() -> some View {
        self
            .listRowBackground(Color.appSurface)
            .listRowSeparatorTint(Color.appBorder)
    }
}

/// Shared empty-state / error placeholder.
struct EmptyStateView: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.appTextTertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

/// Inline error banner used beneath forms/lists.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(Color.appDanger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appDanger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
