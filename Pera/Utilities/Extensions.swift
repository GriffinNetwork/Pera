import Foundation
import SwiftUI

extension Date {
    var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: self)
    }

    var displayMonth: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }

    var shortDisplay: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self)!
    }
}

extension String {
    func monthDateRange() -> (start: Date, end: Date) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let date = f.date(from: self) ?? Date()
        return (date.startOfMonth, date.endOfMonth)
    }
}

extension Double {
    var currencyString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var compactCurrencyString: String {
        if abs(self) >= 1_000 {
            return String(format: "$%.1fK", self / 1_000)
        }
        return currencyString
    }
}

// MARK: - Pera semantic colors

extension Color {
    /// Resolves to different colors in light vs dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    /// Warm cream (light) / near-black (dark) — page backgrounds
    static let peraBackground = Color(light: Color(hex: "#F0EAE0"), dark: Color(hex: "#0D0D0F"))
    /// Warm white (light) / elevated charcoal (dark) — cards and list rows
    static let peraSurface    = Color(light: Color(hex: "#FAF6EF"), dark: Color(hex: "#1C1C21"))
    /// Deeper cream (light) / slightly lighter dark (dark) — chips, tertiary fills
    static let peraSecondary  = Color(light: Color(hex: "#E8E0D0"), dark: Color(hex: "#26262D"))
    /// Sage green (light) / amber gold (dark) — primary accent / tint
    static let peraAccent     = Color(light: Color(hex: "#6B9B71"), dark: Color(hex: "#C79A3A"))
    /// Income — sage green (light) / teal (dark)
    static let peraIncome     = Color(light: Color(hex: "#6B9B71"), dark: Color(hex: "#4E8E8E"))
    /// Expense — muted terracotta (both modes)
    static let peraExpense    = Color(light: Color(hex: "#C4684F"), dark: Color(hex: "#C05A45"))
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension String {
    /// True when the string starts with a Unicode emoji rather than an SF Symbol name.
    var isEmojiIcon: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.value > 0x2000
    }
}

// MARK: - Shared category icon renderer

struct CategoryIconView: View {
    let icon: String
    let size: CGFloat
    let color: Color

    var body: some View {
        if icon.isEmojiIcon {
            Text(icon).font(.system(size: size))
        } else {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(color)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.peraSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
