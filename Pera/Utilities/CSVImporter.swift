import Foundation

struct CSVFile: Identifiable {
    let id = UUID()
    let headers: [String]
    let rows: [[String]]
}

struct ColumnMapping {
    var dateCol: Int? = nil
    var descCol: Int? = nil
    var amountCol: Int? = nil
    var debitCol: Int? = nil
    var creditCol: Int? = nil
    var typeCol: Int? = nil
    var useSplitAmount: Bool = false
}

struct ParsedTransaction: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let type: TransactionType
    let memo: String
}

struct CSVImporter {

    // MARK: - Load raw CSV

    static func load(_ text: String) -> CSVFile? {
        let cleaned = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        let headers = splitLine(lines[0]).map { $0.trimmingCharacters(in: .init(charactersIn: " \"")) }
        guard !headers.isEmpty else { return nil }
        let rows = Array(lines.dropFirst()).map { splitLine($0) }
        return CSVFile(headers: headers, rows: rows)
    }

    // MARK: - Auto-detect column mapping

    static func autoDetect(_ file: CSVFile) -> ColumnMapping {
        let h = file.headers.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        var m = ColumnMapping()
        m.dateCol   = firstIndex(in: h, matching: ["posted date", "posting date", "transaction date", "trans date", "value date", "date"])
        m.amountCol = firstIndex(in: h, matching: ["transaction amount", "amount"])
        m.debitCol  = firstIndex(in: h, matching: ["withdrawal", "debit amount", "withdrawals", "debit"])
        m.creditCol = firstIndex(in: h, matching: ["deposit", "credit amount", "deposits", "credit"])
        m.typeCol   = firstIndex(in: h, matching: ["transaction type", "trans type", "type"])
        m.descCol   = firstIndex(in: h, matching: [
            "transaction description", "description", "memo", "merchant",
            "payee", "narrative", "details", "particulars", "reference", "name"
        ])
        // If separate debit/credit columns found, prefer split mode
        if m.debitCol != nil || m.creditCol != nil { m.useSplitAmount = true }
        return m
    }

    // MARK: - Parse with mapping

    static func parse(_ file: CSVFile, mapping: ColumnMapping) -> [ParsedTransaction] {
        file.rows.compactMap { parseRow($0, mapping: mapping) }
    }

    // MARK: - Private helpers

    private static func parseRow(_ fields: [String], mapping: ColumnMapping) -> ParsedTransaction? {
        func field(_ idx: Int?) -> String {
            guard let i = idx, i < fields.count else { return "" }
            return fields[i].trimmingCharacters(in: .init(charactersIn: " \""))
        }

        guard let date = parseDate(field(mapping.dateCol)) else { return nil }
        let memo = field(mapping.descCol)
        let amount: Double
        let txType: TransactionType

        if mapping.useSplitAmount {
            let debit  = parseAmount(field(mapping.debitCol))  ?? 0
            let credit = parseAmount(field(mapping.creditCol)) ?? 0
            if debit > 0 {
                amount = debit;  txType = .expense
            } else if credit > 0 {
                amount = credit; txType = .income
            } else { return nil }
        } else if let col = mapping.amountCol {
            guard let raw = parseAmount(field(col)), raw != 0 else { return nil }
            if let typeCol = mapping.typeCol {
                let t = field(typeCol).lowercased()
                let incomeWords = ["credit", "deposit", "income", "refund", "return", "payment received"]
                txType = incomeWords.contains(where: { t.contains($0) }) ? .income : .expense
                amount = abs(raw)
            } else {
                txType = raw < 0 ? .expense : .income
                amount = abs(raw)
            }
        } else { return nil }

        return ParsedTransaction(date: date, amount: amount, type: txType, memo: memo)
    }

    private static func firstIndex(in headers: [String], matching aliases: [String]) -> Int? {
        for alias in aliases {
            if let i = headers.firstIndex(where: { $0 == alias || $0.contains(alias) }) { return i }
        }
        return nil
    }

    static func splitLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { fields.append(current); current = "" }
            else { current.append(ch) }
        }
        fields.append(current)
        return fields
    }

    private static func parseAmount(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let negative = s.hasPrefix("(") && s.hasSuffix(")")
        if negative { s = String(s.dropFirst().dropLast()) }
        s = s.replacingOccurrences(of: "[^0-9.\\-]", with: "", options: .regularExpression)
        guard let val = Double(s) else { return nil }
        return negative ? -abs(val) : val
    }

    private static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let formats = [
            "MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
            "yyyy-MM-dd", "yyyy/MM/dd",
            "dd/MM/yyyy", "dd-MM-yyyy",
            "MMM dd, yyyy", "MMM d, yyyy", "dd MMM yyyy", "MMMM d, yyyy"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
