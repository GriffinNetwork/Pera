# Pera — iOS Budgeting App Specification

## Overview
Pera is a native iOS budgeting app focused on privacy, beautiful design, and smart automation. It follows Apple's Human Interface Guidelines and integrates deeply with the iOS ecosystem.

---

## Authentication & Backend

- **Login/Auth**: Firebase Authentication (email/password)
- **Data storage**: Firebase Firestore — all user data stored in Firestore under `users/{userId}/`
- **Single backend**: Firebase handles both auth and data — no iCloud/CloudKit

---

## Core Budgeting & Tracking

### Transaction Entry
- Quick-add with camera receipt scanning
- Voice input via Siri
- Manual entry forms
- AI-powered auto-categorization

### Categories
- Custom categories and subcategories (user-defined)
- Rollover options between budget periods
- Savings goals tied to categories
- Hierarchical organization

### Income & Expense Tracking
- Recurring transactions
- Split transactions
- Multi-currency support
- Tags for additional organization

### Budgeting Method
- Zero-based budgeting and/or envelope system
- Digital "envelopes" for allocating every dollar
- Clear visual allocation tools showing what's assigned vs. unassigned

---

## Insights & Reporting

### Visualizations
- Interactive charts: pie, bar, line
- Spending trends over time
- Net worth tracking (manual inputs)

### AI-Powered Insights
- Personalized alerts (e.g., "You spent 23% more on dining this month")
- Predictive spending forecasts
- Anomaly detection for unusual transactions

### Reports
- Exportable PDFs and CSV files
- Weekly and monthly summaries
- Goal progress trackers
- Budget vs. actual comparisons with color-coded warnings
- Easy-to-read dashboard

---

## iOS-Optimized UX

### Design
- Native iOS design following Human Interface Guidelines
- Dark mode support
- Dynamic Island support
- Live Activities for real-time budget status

### Widgets
- Home Screen and Lock Screen widgets
- Widget content: remaining budget, today's spending, quick-add button

### Navigation & Performance
- Tab bar + gesture-based navigation
- Searchable transaction history
- Customizable home dashboard
- Offline-first: full functionality without internet
- Optional cloud sync (iCloud) for backup
- Fast loading, low battery usage

---

## Security & Privacy

- Face ID / Touch ID login with optional passcode
- Biometric approval for sensitive actions
- End-to-end encryption
- On-device processing for personal financial data
- Transparent privacy policy — no unnecessary data collection
- Audit log of all changes
- Full user ownership of exported data

---

## Automation & Smart Features

### Rules & Automation
- Auto-categorize by merchant, amount, keywords, or user-defined patterns
- Bill reminders and due date tracking with customizable notifications

### Goals & Savings
- Visual progress bars for savings goals
- Round-up savings tools
- Debt payoff planners
- Motivational trackers and savings challenges

### Apple Ecosystem Integration
- Apple Pay manual import support
- Shortcuts app actions
- Siri shortcuts for quick transaction logging

---

## Additional Features

| Feature | Details |
|---|---|
| Receipt storage | Photo attachments linked directly to transactions |
| Tax support | Category tagging + yearly summaries for tax prep |
| Gamification (optional) | Streaks, badges, progress rewards, financial tips |
| Accessibility | Full VoiceOver, Dynamic Type, high contrast, color-blind friendly charts |
| Export & backup | CSV/OFX export, iCloud or manual backup |
| In-app education | Built-in tips, tutorials, and financial literacy resources |

---

## Tech Stack

| Layer | Choice |
|---|---|
| Platform | iOS (native Swift / SwiftUI) |
| Auth | Firebase Authentication |
| Data sync/backup | Firebase Firestore |
| AI features | On-device ML (Core ML) + optional cloud model calls |
| Charts | Swift Charts (native) |
| Notifications | UserNotifications framework |
| Widgets | WidgetKit |
| Live Activities | ActivityKit |
| Siri / Shortcuts | App Intents framework |

---

## Design Principles

1. **Privacy-first** — financial data stays on device or in the user's own iCloud account
2. **Offline-first** — the app works completely without a network connection
3. **Native feel** — no cross-platform compromises; use Apple frameworks wherever possible
4. **Speed** — transaction entry should take under 10 seconds
5. **Clarity** — the user should always know exactly where their money is going
