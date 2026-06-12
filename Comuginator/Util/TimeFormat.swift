import Foundation

/// Converts server UTC ISO timestamps to text in the device's timezone,
/// using the device locale's date/time formats.
enum TimeFormat {

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseUtc(_ isoString: String?) -> Date? {
        guard let isoString, !isoString.isEmpty else { return nil }
        return isoWithFraction.date(from: isoString) ?? iso.date(from: isoString)
    }

    /// ISO UTC timestamp → localized "date, time" in the device timezone.
    static func dateTime(_ isoString: String?) -> String {
        guard let date = parseUtc(isoString) else { return isoString ?? "" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    /// ISO UTC timestamp → localized time only (for chat bubbles etc.).
    static func time(_ isoString: String?) -> String {
        guard let date = parseUtc(isoString) else { return isoString ?? "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Plain calendar date string (yyyy-MM-dd…) → localized date.
    /// Taken as-is, not shifted through timezones.
    static func date(_ isoDate: String?) -> String {
        guard let isoDate, !isoDate.isEmpty else { return "" }
        let datePart = String(isoDate.prefix(10))
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = parser.date(from: datePart) else { return datePart }
        return parsed.formatted(date: .abbreviated, time: .omitted)
    }
}
