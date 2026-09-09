import SwiftUI

/// The playback position bar.
///
/// A stock `Slider` was doing this job, and its thumb is a large white circle
/// that reads as a switch rather than a playhead. This is the shape the platform
/// music apps use instead: a thin capsule that thickens under your finger, with
/// no thumb at rest.
public struct ScrubBar: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let onEditingChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false

    private static let restHeight: CGFloat = 6
    private static let activeHeight: CGFloat = 11

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        _value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    public var body: some View {
        GeometryReader { geometry in
            let height = isDragging ? Self.activeHeight : Self.restHeight
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: height)
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: geometry.size.width * fraction, height: height)
            }
            .frame(maxHeight: .infinity)
            // The row stays a comfortable target height while the bar itself is
            // thin, so the gesture doesn't demand precision the visual invites.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = position(at: gesture.location.x, width: geometry.size.width)
                    }
                    .onEnded { gesture in
                        value = position(at: gesture.location.x, width: geometry.size.width)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isDragging)
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(formattedDuration(value))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            onEditingChanged(true)
            value = min(max(value + (direction == .increment ? step : -step), range.lowerBound), range.upperBound)
            onEditingChanged(false)
        }
    }

    private func position(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return range.lowerBound }
        let ratio = min(max(Double(x / width), 0), 1)
        return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
    }
}
