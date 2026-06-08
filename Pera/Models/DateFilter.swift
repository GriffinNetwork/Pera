import Foundation

enum DateFilter: Equatable {
    case month(Date)
    case quarter
    case sixMonths
    case year
    case custom(start: Date, end: Date)

    var dateRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .month(let date):
            return (date.startOfMonth, date.endOfMonth)
        case .quarter:
            let month = cal.component(.month, from: now)
            let qStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = DateComponents()
            comps.year = cal.component(.year, from: now)
            comps.month = qStartMonth
            comps.day = 1
            let start = cal.date(from: comps)!
            comps.month = qStartMonth + 2
            let qEndMonthStart = cal.date(from: comps)!
            return (start, qEndMonthStart.endOfMonth)
        case .sixMonths:
            return (now.adding(months: -5).startOfMonth, now.endOfMonth)
        case .year:
            var comps = DateComponents()
            comps.year = cal.component(.year, from: now)
            comps.month = 1
            comps.day = 1
            let start = cal.date(from: comps)!
            comps.month = 12
            let decStart = cal.date(from: comps)!
            return (start, decStart.endOfMonth)
        case .custom(let start, let end):
            return (start, end)
        }
    }

    var label: String {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .month(let date):
            return date.displayMonth
        case .quarter:
            let month = cal.component(.month, from: now)
            let q = (month - 1) / 3 + 1
            return "Q\(q) \(cal.component(.year, from: now))"
        case .sixMonths:
            return "Last 6 Months"
        case .year:
            return "This Year"
        case .custom(let start, let end):
            return "\(start.shortDisplay) – \(end.shortDisplay)"
        }
    }
}
