import Foundation

// Display formatting, ported from frontend/src/lib/format.js and useNow.js so
// numbers read exactly as they did in the PWA ("80 kg × 8", "00:42", "SET 03").

public enum Format {
    /// Drops a trailing ".0": 80.0 → "80", 77.5 → "77.5"; at most 2 decimals.
    public static func trimNum(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int64(rounded))
        }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// Seconds → "m:ss".
    public static func duration(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        return "\(s / 60):\(pad2(s % 60))"
    }

    /// Seconds → "00:42", fixed width so a countdown's digits never reflow.
    public static func clock(_ totalSeconds: Double) -> String {
        let s = max(0, Int(totalSeconds.rounded()))
        return "\(pad2(s / 60)):\(pad2(s % 60))"
    }

    /// Elapsed milliseconds → "1:12" (h:mm), or "m:ss" under an hour.
    public static func elapsed(_ ms: Int64) -> String {
        let totalMinutes = max(0, ms) / 60_000
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours):\(pad2(Int(minutes)))" }
        let seconds = (max(0, ms) / 1000) % 60
        return "\(minutes):\(pad2(Int(seconds)))"
    }

    /// Epoch ms → "Mon, Jun 23".
    public static func date(_ ms: Int64, locale: Locale = .current) -> String {
        Date(epochMilliseconds: ms).formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(locale)
        )
    }

    /// Epoch ms → "Mon", used to label "Last time · Mon".
    public static func weekday(_ ms: Int64, locale: Locale = .current) -> String {
        Date(epochMilliseconds: ms).formatted(.dateTime.weekday(.abbreviated).locale(locale))
    }

    /// 3 → "03" for set ordinals.
    public static func ordinal(_ n: Int) -> String { pad2(n) }

    /// Volume with grouping: 8450 → "8,450".
    public static func volume(_ value: Double, locale: Locale = .current) -> String {
        Int64(value.rounded()).formatted(.number.locale(locale))
    }

    /// "80 kg × 8 1:30" — only the fields the exercise tracks. When the
    /// exercise is gone from the library (history keeps its sets), show
    /// whatever the set recorded so the numbers don't look lost.
    public static func setSummary(_ set: SetEntry, exercise: Exercise?, unit: WeightUnit) -> String {
        let tracksWeight = exercise?.tracksWeight ?? true
        let tracksReps = exercise?.tracksReps ?? true
        let tracksDuration = exercise?.tracksDuration ?? true
        var parts: [String] = []
        if tracksWeight, let w = set.weight { parts.append("\(trimNum(w)) \(unit.rawValue)") }
        if tracksReps, let r = set.reps { parts.append("× \(r)") }
        if tracksDuration, let d = set.duration { parts.append(duration(d)) }
        return parts.joined(separator: " ")
    }

    private static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
    private static func pad2(_ n: Int64) -> String { pad2(Int(n)) }
}

extension Date {
    public init(epochMilliseconds ms: Int64) {
        self.init(timeIntervalSince1970: Double(ms) / 1000)
    }

    public var epochMilliseconds: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
}

/// A rest timer's display state (frontend/src/lib/useNow.js `timerState`).
public enum RestPhase: Hashable, Sendable {
    /// Counting down.
    case resting(remaining: Double)
    /// Rest is over, for up to `readyWindow` seconds.
    case ready
    /// Rest ended more than `readyWindow` seconds ago; the clock counts up.
    case overdue(over: Double)

    public static let readyWindow: Double = 30

    public init(startedAt: Int64, durationSeconds: Int, now: Int64) {
        let elapsed = Double(now - startedAt) / 1000
        let remaining = Double(durationSeconds) - elapsed
        if remaining > 0 {
            self = .resting(remaining: remaining)
        } else if remaining > -RestPhase.readyWindow {
            self = .ready
        } else {
            self = .overdue(over: -remaining)
        }
    }

    /// "RESTING" / "READY" / "OVERDUE".
    public var label: String {
        switch self {
        case .resting: "Resting"
        case .ready: "Ready"
        case .overdue: "Overdue"
        }
    }

    /// The clock to show: remaining while resting, overtime once overdue.
    public var clockSeconds: Double {
        switch self {
        case .resting(let remaining): remaining
        case .ready: 0
        case .overdue(let over): over
        }
    }
}
