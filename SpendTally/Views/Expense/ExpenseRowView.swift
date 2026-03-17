import SwiftUI
import SwiftData

struct ExpenseRowView: View {

    let expense: Expense

    var body: some View {
        HStack(spacing: 16) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.note.isEmpty ? "Expense" : expense.note)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Text(expense.date, style: .time)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.amount, format: .currency(code: "USD"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconTint.opacity(0.14))
                .frame(width: 44, height: 44)

            if let data = expense.receiptImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Text(iconEmoji)
                    .font(.system(size: 22))
            }
        }
    }

    /// Maps note keywords to an emoji.
    private var iconEmoji: String {
        let lower = expense.note.lowercased()
        switch true {
        case lower.contains("coffee") || lower.contains("café") || lower.contains("latte") || lower.contains("espresso"):
            return "☕️"
        case lower.contains("restaurant") || lower.contains("dinner") || lower.contains("lunch") || lower.contains("sushi") || lower.contains("pizza"):
            return "🍽️"
        case lower.contains("grocery") || lower.contains("groceries") || lower.contains("whole foods") || lower.contains("market") || lower.contains("supermarket"):
            return "🛒"
        case lower.contains("gas") || lower.contains("fuel") || lower.contains("petrol"):
            return "⛽️"
        case lower.contains("uber") || lower.contains("lyft") || lower.contains("taxi") || lower.contains("transport") || lower.contains("transit"):
            return "🚗"
        case lower.contains("amazon") || lower.contains("shopping") || lower.contains("store") || lower.contains("shop"):
            return "🛍️"
        case lower.contains("movie") || lower.contains("cinema") || lower.contains("netflix") || lower.contains("hulu") || lower.contains("streaming"):
            return "🎬"
        case lower.contains("gym") || lower.contains("fitness") || lower.contains("workout") || lower.contains("yoga"):
            return "💪"
        case lower.contains("pet") || lower.contains("dog") || lower.contains("cat") || lower.contains("treat"):
            return "🐾"
        case lower.contains("gift") || lower.contains("birthday") || lower.contains("present"):
            return "🎁"
        case lower.contains("salary") || lower.contains("income") || lower.contains("paycheck") || lower.contains("wage"):
            return "💼"
        case lower.contains("flight") || lower.contains("hotel") || lower.contains("travel") || lower.contains("airbnb"):
            return "✈️"
        case lower.contains("snack") || lower.contains("chips") || lower.contains("candy"):
            return "🍪"
        case lower.contains("pharmacy") || lower.contains("medicine") || lower.contains("doctor") || lower.contains("health"):
            return "💊"
        case lower.contains("electricity") || lower.contains("water") || lower.contains("internet") || lower.contains("bill") || lower.contains("utility"):
            return "🧾"
        default:
            return "💳"
        }
    }

    /// Matching tint color for the icon background.
    private var iconTint: Color {
        switch iconEmoji {
        case "☕️":  return .brown
        case "🍽️":  return .orange
        case "🛒":  return .green
        case "⛽️":  return .yellow
        case "🚗":  return .blue
        case "🛍️":  return .purple
        case "🎬":  return .red
        case "💪":  return .blue
        case "🐾":  return .brown
        case "🎁":  return .pink
        case "💼":  return .indigo
        case "✈️":  return .cyan
        case "🍪":  return .orange
        case "💊":  return .mint
        case "🧾":  return .gray
        default:     return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    do {
        let schema = Schema([Budget.self, Expense.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        let samples: [(Double, String)] = [
            (3.35,  "Pet treats"),
            (1.70,  "Snacks"),
            (4.50,  "Coffee"),
            (12.99, "Lunch"),
            (39.75, "Jeff's birthday gift"),
            (89.00, "Grocery run"),
        ]

        return List {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, item in
                let e = Expense(amount: item.0, note: item.1)
                ExpenseRowView(expense: e)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
