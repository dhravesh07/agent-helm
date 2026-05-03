import SwiftUI

/// Centralized macOS-26 Liquid Glass adoption with backward-compatible
/// fallbacks. Per the liquid-glass skill, glass goes on navigation/controls
/// (toolbars, primary buttons, floating overlays) — **never on content**
/// (lists, tables, file viewers, transcripts).
///
/// The `#available(macOS 26.0, *)` gates let us compile + run cleanly on
/// the older deployment target; on macOS 26+ we get real glass.

extension View {
    /// Apply a glass button style on macOS 26+; bordered fallback otherwise.
    /// Use for secondary toolbar / form actions.
    @ViewBuilder
    func rookeryGlassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Glass-prominent on macOS 26+; bordered-prominent fallback. Use for
    /// the single most important action in a context (Save, Install crontab,
    /// Run query). Avoid stacking these — having more than one prominent
    /// button on screen is a HIG anti-pattern.
    @ViewBuilder
    func rookeryGlassButtonProminent() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Subtle glass surface for floating overlays (zoom controls, etc.).
    /// Falls back to ultraThinMaterial on older systems.
    @ViewBuilder
    func rookeryGlassSurface(cornerRadius: CGFloat = 8) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Spacing rhythm. SwiftUI doesn't ship a token system; centralizing the
/// values we use makes density consistent across the app.
enum RookerySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}
