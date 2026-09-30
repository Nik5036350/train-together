import Charts
import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// History → Exercises: the training overview, then every trained exercise
/// with its trend.
struct AnalyticsListView: View {
    @Environment(AppModel.self) private var model
    @State private var snapshot: AnalyticsSnapshot?

    var body: some View {
        let people = model.catalog.pair
        List {
            if let snapshot {
                Section {
                    OverviewCard(overview: snapshot.overview, people: people, catalog: model.catalog)
                        .listRowBackground(Palette.canvas)
                }
                Section {
                    if snapshot.exercises.isEmpty {
                        EmptyState(title: "No lifts yet", message: "Finish a workout and each exercise's progress shows up here.")
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    ForEach(snapshot.exercises) { summary in
                        NavigationLink(value: HistoryRoute.exercise(summary.id)) {
                            ExerciseSummaryRow(summary: summary, people: people)
                        }
                        .listRowBackground(Palette.canvas)
                        .accessibilityIdentifier("exercise-\(summary.id)")
                    }
                } header: {
                    SectionLabel("Exercises")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperBackground()
        // Only while the tab is on screen (logging a set would otherwise
        // recompute analytics), and again when the day rolls over so "last 30
        // days" moves.
        .task(id: ObservationKey(
            visible: model.selectedTab == .history && model.workoutCover == nil,
            day: Calendar.current.startOfDay(for: .now)
        )) {
            guard model.selectedTab == .history, model.workoutCover == nil else { return }
            do {
                for try await value in model.store.observeAnalytics() { snapshot = value }
            } catch {
                model.errorMessage = "COULD NOT LOAD PROGRESS — \(error.localizedDescription)"
            }
        }
    }
}

private struct ObservationKey: Hashable {
    let visible: Bool
    let day: Date
}

// MARK: - Overview

private struct OverviewCard: View {
    let overview: TrainingOverview
    let people: [Person]
    let catalog: CatalogSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if overview.workouts30 > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 30 days").metaStyle()
                    HStack(spacing: 12) {
                        StatBlock(value: "\(overview.workouts30)", label: overview.workouts30 == 1 ? "Workout" : "Workouts")
                        StatBlock(value: "\(overview.sets30)", label: "Sets")
                        StatBlock(value: "\(overview.records30)", label: overview.records30 == 1 ? "Record" : "Records", tone: overview.records30 > 0 ? .accent : .light)
                    }
                }
            } else if let last = overview.lastWorkout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last workout").metaStyle()
                    Text(Format.dayMonth(last)).displayStyle(30)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Workouts per week")
                WeeklyBars(weeks: overview.weeks)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "Weekly volume") {
                    Legend(people: people)
                }
                if Set(people.map(\.unit)).count > 1 {
                    ForEach(people) { person in
                        WeeklyVolume(weeks: overview.weeks, people: [person])
                    }
                } else {
                    WeeklyVolume(weeks: overview.weeks, people: people)
                }
            }

            if !overview.recentRecords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("Recent records")
                    ForEach(overview.recentRecords) { record in
                        RecordRow(record: record, catalog: catalog)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// Short week labels for category axes ("24 Aug").
private func weekLabel(_ start: Int64) -> String { Format.dayMonth(start) }

/// Every fourth week gets an axis label so twelve don't crowd.
private func labelledWeeks(_ weeks: [WeekBucket]) -> [String] {
    weeks.enumerated().filter { ($0.offset - weeks.count + 1) % 4 == 0 }.map { weekLabel($0.element.start) }
}

private struct WeeklyBars: View {
    let weeks: [WeekBucket]

    var body: some View {
        Chart(weeks) { week in
            BarMark(x: .value("Week", weekLabel(week.start)), y: .value("Workouts", week.workouts), width: .ratio(0.6))
                .foregroundStyle(Palette.ink)
        }
        .chartXAxis {
            AxisMarks { value in
                if let label = value.as(String.self), labelledWeeks(weeks).contains(label) {
                    AxisValueLabel(centered: true).font(Typeface.condensed(11)).foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.ruleSoft.opacity(0.5))
                AxisValueLabel().font(Typeface.condensed(11)).foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(height: 110)
        .accessibilityLabel("Workouts per week, last 12 weeks")
    }
}

private struct WeeklyVolume: View {
    let weeks: [WeekBucket]
    let people: [Person]

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                ForEach(people) { person in
                    BarMark(x: .value("Week", weekLabel(week.start)), y: .value("Volume", week.volumeByPerson[person.id] ?? 0))
                        .foregroundStyle(by: .value("Person", person.id))
                        .position(by: .value("Person", person.id))
                }
            }
        }
        .chartForegroundStyleScale(domain: people.map(\.id), range: people.map(\.style.accent))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { value in
                if let label = value.as(String.self), labelledWeeks(weeks).contains(label) {
                    AxisValueLabel(centered: true).font(Typeface.condensed(11)).foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Palette.ruleSoft.opacity(0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(compact(v)) }
                }
                .font(Typeface.condensed(11))
                .foregroundStyle(Palette.textSecondary)
            }
        }
        .chartYAxisLabel(people.first?.unit.rawValue.uppercased() ?? "", position: .topLeading)
        .frame(height: 130)
        .accessibilityLabel("Weekly volume per person, last 12 weeks")
    }

    private func compact(_ value: Double) -> String {
        value >= 1000 ? "\(Format.trimNum((value / 100).rounded() / 10))K" : Format.trimNum(value)
    }
}

/// The people's colors with their names — identity never by color alone.
struct Legend: View {
    let people: [Person]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(people) { person in
                HStack(spacing: 4) {
                    Rectangle().fill(person.style.accent).frame(width: 10, height: 10)
                    Text(person.name).metaStyle(person.style.text, size: 10)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RecordRow: View {
    let record: RecordEvent
    let catalog: CatalogSnapshot

    var body: some View {
        let person = catalog.person(record.point.personId)
        let exercise = catalog.exercise(record.point.exerciseId)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Rectangle().fill(person?.style.accent ?? Palette.ink).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Format.dayMonth(record.point.date)) · \(person?.name ?? "") · \(exercise?.name ?? "")")
                    .metaStyle(size: 11)
                    .lineLimit(1)
                Text(ProgressFormat.record(record, unit: person?.unit ?? .kg))
                    .font(Typeface.condensed(17))
                    .textCase(.uppercase)
                    .monospacedDigit()
            }
            Spacer()
            Tag(text: "PR", fill: Palette.red)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise rows

private struct ExerciseSummaryRow: View {
    let summary: ExerciseSummary
    let people: [Person]

    var body: some View {
        HStack(spacing: 12) {
            ExerciseTile(summary.exercise.resolvedIcon)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(summary.exercise.name).font(Typeface.condensed(18)).textCase(.uppercase).lineLimit(1)
                    if summary.recordLastTime { Tag(text: "PR", fill: Palette.red) }
                }
                Text("\(summary.sessionCount) \(summary.sessionCount == 1 ? "session" : "sessions") · \(Format.dayMonth(summary.lastDate))")
                    .metaStyle(size: 11)
                HStack(spacing: 10) {
                    ForEach(people) { person in
                        if let best = summary.bestTopWeight[person.id] {
                            Text("\(person.initials) \(Format.trimNum(best)) \(person.unit.rawValue)")
                                .font(Typeface.condensed(13))
                                .textCase(.uppercase)
                                .monospacedDigit()
                                .foregroundStyle(person.style.text)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Sparkline(series: people.compactMap { person in
                summary.sparkline[person.id].map { (person.style.accent, $0) }
            })
            .frame(width: 84, height: 34)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows progress charts")
    }
}

/// A tiny trend line per person, drawn as paths (cheap in long lists).
struct Sparkline: View {
    let series: [(Color, [Double])]

    var body: some View {
        Canvas { context, size in
            let values = series.flatMap(\.1)
            guard let low = values.min(), let high = values.max() else { return }
            let span = max(high - low, 1)
            for (color, points) in series {
                guard points.count > 0 else { continue }
                let step = points.count > 1 ? size.width / CGFloat(points.count - 1) : 0
                func position(_ index: Int, _ value: Double) -> CGPoint {
                    CGPoint(
                        x: points.count > 1 ? CGFloat(index) * step : size.width / 2,
                        y: size.height - 3 - CGFloat((value - low) / span) * (size.height - 6)
                    )
                }
                var path = Path()
                for (index, value) in points.enumerated() {
                    let point = position(index, value)
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                if let last = points.last {
                    let end = position(points.count - 1, last)
                    context.fill(Path(CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
