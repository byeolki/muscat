import SwiftUI

// Lives in MuscatKit (not the app target) so that adding/changing design-system code
// never requires regenerating the .xcodeproj — SPM globs package sources at build
// time, while the XcodeGen project references app-target files explicitly.

// MARK: - Palette

/// Design tokens for the whole app. Dark-only theme (the app forces
/// `.preferredColorScheme(.dark)` at the root).
///
/// The accent is Shine Muscat green because the app is called Muscat. Podo (the
/// server, and 포도 = grape) is the purple one — sibling apps with their own
/// identities, deliberately not a shared palette.
public extension Color {
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
///
/// The style renders its own disabled state. Call sites used to pair
/// `.disabled(...)` with `.opacity(0.5)`, which half-faded the lime against the
/// near-black background into a muddy olive that read as a rendering fault
/// rather than an unavailable button; a disabled button now drops to the surface
/// colour instead, the same treatment as any other inert control.
public struct AccentButtonStyle: ButtonStyle {
    public var fullWidth: Bool

    public init(fullWidth: Bool = false) {
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        AccentButtonBody(configuration: configuration, fullWidth: fullWidth)
    }

    /// `isEnabled` is only readable from a real `View`, not from `makeBody`.
    /// Named away from `Body` so it can't be mistaken for the protocol's own
    /// `associatedtype Body`, which a nested type of that name shadows.
    private struct AccentButtonBody: View {
        let configuration: Configuration
        let fullWidth: Bool

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.black : Color.appTextTertiary)
                .padding(.vertical, 13)
                .padding(.horizontal, 20)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    isEnabled
                        ? Color.appAccent.opacity(configuration.isPressed ? 0.75 : 1)
                        : Color.appSurfaceRaised,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    if !isEnabled {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }
                }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// Dark card button with a hairline border — secondary actions and icon wells.
public struct SurfaceButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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

/// Dark rounded input well for `TextField`/`SecureField`.
public struct ThemedField: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            // Without this the caret and selection handles draw in the system
            // blue, which is the one bit of stock iOS chrome that survives an
            // otherwise fully themed screen.
            .tint(Color.appAccent)
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

/// Placeholder text for a `themedField()` input.
///
/// `Text("…")` takes a `LocalizedStringKey`, and SwiftUI runs those through its
/// markdown parser — which turns a bare `https://…` into a link, drawn in the
/// system link colour and ignoring any `foregroundStyle` applied to the `Text`.
/// That is why the server-address placeholder rendered blue. `verbatim:` opts out
/// of the key lookup and the markdown pass, so a prompt is always plain text.
public func fieldPrompt(_ text: String) -> Text {
    Text(verbatim: text).foregroundStyle(Color.appTextTertiary)
}

// MARK: - Screens & lists

public extension View {
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

    /// Standard row treatment inside a themed `.plain` `List`.
    ///
    /// The row background is deliberately clear. Painting rows in `appSurface`
    /// makes a full-bleed plain list read as a lighter slab laid over the screen,
    /// with a visible step where it starts — right under the navigation title.
    /// Separators carry the row structure instead.
    func themedRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color.appBorder)
    }

    /// Row treatment for a `Form`/grouped list, where the surface fill is the
    /// card and is meant to be visible against the screen behind it.
    func themedCardRow() -> some View {
        self
            .listRowBackground(Color.appSurface)
            .listRowSeparatorTint(Color.appBorder)
    }
}

/// Shared empty-state / error placeholder.
public struct EmptyStateView: View {
    public let systemImage: String
    public let message: String

    public init(systemImage: String, message: String) {
        self.systemImage = systemImage
        self.message = message
    }

    public var body: some View {
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
public struct ErrorBanner: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
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

// MARK: - Formatting

/// `mm:ss` for a duration in seconds. Lives here (rather than on a row view) so
/// list rows, the album sheet and Now Playing all render time identically.
///
/// Non-finite input is a real case, not defensive padding: `AVPlayer` reports an
/// indefinite `CMTime` before an item is ready, which arrives here as `NaN`, and
/// `Int(Double.nan)` is a trap — it would take the app down rather than briefly
/// showing a wrong time.
public func formattedDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Badges

/// Small uppercase chip used for inline markers (ADMIN, etc).
public struct BadgeLabel: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - Artist / cover line

/// Renders "Artist" or, for a cover, "Original Artist · covered by Performers",
/// with the cover marker in the accent colour. Same wording as the Podo web
/// dashboard, so a track reads identically on both.
///
/// The order matters and it isn't the obvious one: the lead is the artist of the
/// *original* song (see `TrackDisplayable.displayArtist`), and the people who
/// performed this particular version follow. "covered by" rather than "cover of"
/// because with this ordering "cover of" would assert the reverse — that the
/// original artist covered the people who actually covered them.
///
/// `performers` is `nil` where the model has no override data (`AlbumTrackEntry`)
/// or where they'd merely repeat the lead; the row then carries a plain "cover"
/// tag.
public func artistLineText(
    artist: String,
    isCover: Bool,
    performers: String?,
    textColor: Color = .appTextSecondary,
    dimColor: Color = .appTextTertiary
) -> Text {
    guard isCover else {
        return Text(artist.isEmpty ? "Unknown Artist" : artist).foregroundColor(textColor)
    }

    // A cover whose original is unknown has nothing to lead with; naming the
    // performer there would credit them with the song.
    guard !artist.isEmpty else {
        guard let performers, !performers.isEmpty else {
            return Text("Cover").foregroundColor(.appAccent)
        }
        return Text("Cover by").foregroundColor(.appAccent)
            + Text(" \(performers)").foregroundColor(textColor)
    }

    let base = Text(artist).foregroundColor(textColor)
    let separator = Text(" · ").foregroundColor(dimColor)
    if let performers, !performers.isEmpty {
        return base + separator
            + Text("covered by").foregroundColor(.appAccent)
            + Text(" \(performers)").foregroundColor(textColor)
    }
    return base + separator + Text("cover").foregroundColor(.appAccent)
}

// MARK: - Now playing indicator

/// Three bouncing bars, drawn over the artwork of whichever row is currently
/// playing. The Podo web dashboard marks the playing row the same way; before
/// this, a list gave no indication at all of which of its rows the mini player
/// was actually playing.
public struct NowPlayingBars: View {
    public var color: Color
    public var height: CGFloat
    /// Paused rows keep the bars (the row is still "the current one") but hold
    /// them still.
    public var isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var raised = false

    /// Heights the bars rest at when they aren't animating, so a paused or
    /// reduce-motion row still reads as an equaliser rather than a solid block.
    private static let restingRatios: [CGFloat] = [0.45, 1.0, 0.65]

    public init(color: Color = .appAccent, height: CGFloat = 13, isAnimating: Bool = true) {
        self.color = color
        self.height = height
        self.isAnimating = isAnimating
    }

    private var motionEnabled: Bool { isAnimating && !reduceMotion }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(Array(Self.restingRatios.enumerated()), id: \.offset) { index, resting in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: barHeight(index: index, resting: resting))
                    .animation(
                        motionEnabled
                            ? .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18)
                            : .easeOut(duration: 0.2),
                        value: raised
                    )
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear { raised = true }
        .accessibilityHidden(true)
    }

    private func barHeight(index: Int, resting: CGFloat) -> CGFloat {
        guard motionEnabled else { return height * resting }
        return raised ? height : height * 0.3
    }
}

// MARK: - Disclosure

/// The trailing chevron that opens a track's detail page from a list row.
///
/// It is a button in its own right — tapping the row plays the track instead —
/// so it needs a real accessibility label (VoiceOver was announcing the bare
/// glyph as "Forward") and a tap target tall enough to hit reliably without
/// catching the row underneath it.
public struct DetailDisclosureButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextTertiary)
                .frame(width: 30, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Track details")
    }
}
