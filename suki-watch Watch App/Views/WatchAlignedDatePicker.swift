import SwiftUI

/// watchOS graphical `DatePicker` misaligns Day/Month/Year labels in a `List`; use aligned columns instead.
struct WatchAlignedDatePicker: View {
    @Binding var date: Date
    let range: ClosedRange<Date>

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            pickerColumn(title: "Day", component: .day, values: dayValues)
            pickerColumn(title: "Month", component: .month, values: Array(1...12))
            pickerColumn(title: "Year", component: .year, values: yearValues)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func pickerColumn(title: String, component: Calendar.Component, values: [Int]) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
            Picker(title, selection: componentBinding(component)) {
                ForEach(values, id: \.self) { value in
                    Text(displayLabel(for: component, value: value))
                        .tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private var dayValues: [Int] {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return Array(1...31)
        }
        return Array(dayRange)
    }

    private var yearValues: [Int] {
        let startYear = calendar.component(.year, from: range.lowerBound)
        let endYear = calendar.component(.year, from: range.upperBound)
        return Array(startYear...endYear)
    }

    private func displayLabel(for component: Calendar.Component, value: Int) -> String {
        "\(value)"
    }

    private func componentBinding(_ component: Calendar.Component) -> Binding<Int> {
        Binding(
            get: { calendar.component(component, from: date) },
            set: { newValue in
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                switch component {
                case .day:
                    components.day = newValue
                case .month:
                    components.month = newValue
                    let maxDay = dayValues.last ?? 28
                    if let day = components.day, day > maxDay {
                        components.day = maxDay
                    }
                case .year:
                    components.year = newValue
                default:
                    break
                }
                guard let candidate = calendar.date(from: components) else { return }
                date = clamp(candidate)
            }
        )
    }

    private func clamp(_ candidate: Date) -> Date {
        if candidate < range.lowerBound { return range.lowerBound }
        if candidate > range.upperBound { return range.upperBound }
        return candidate
    }
}
