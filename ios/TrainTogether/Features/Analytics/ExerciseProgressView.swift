import Charts
import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Number formatting for progress screens.
enum ProgressFormat {
    static func value(_ v: Double, _ metric: ProgressMetric, unit: WeightUnit, tracksReps: Bool) -> String {
        switch metric {
        case .topSet, .e1rm: "\(Format.trimNum((v * 10).rounded() / 10)) \(unit.rawValue)"
        case .volume: "\(Format.volume(v)) \(unit.rawValue)"
        case .bestReps: tracksReps ? "\(Int(v)) reps" : Format.duration(Int(v))
        case .dots: String(format: "%.1f", v)
        }
    }

    static func delta(_ d: Double, _ metric: ProgressMetric, unit: WeightUnit, tracksReps: Bool) -> String {
        let sign = d > 0 ? "+" : d < 0 ? "−" : "±"
        return sign + value(abs(d), metric, unit: unit, tracksReps: tracksReps)
    }

    static func set(weight: Double?, reps: Int?, unit: WeightUnit) -> String {
        [weight.map { "\(Format.trimNum($0)) \(unit.rawValue)" }, reps.map { "× \($0)" }]
            .compactMap { $0 }.joined(separator: " ")
    }

    static func record(_ event: RecordEvent, unit: WeightUnit) -> String {
        let p = event.point
        return switch event.kind {
        case .topSet: "\(set(weight: p.topWeight, reps: p.topWeightReps, unit: unit)) · top set"
        case .e1rm: "e1RM \(value(p.bestE1RM ?? 0, .e1rm, unit: unit, tracksReps: true))"
        case .reps: "\(p.bestReps ?? 0) reps"
        case .duration: "\(Format.duration(p.bestDuration ?? 0)) hold"
        }
    }
}

extension ProgressMetric {
    func label(tracksReps: Bool) -> String {
        switch self {
        case .topSet: "Top set"
        case .e1rm: "Est. 1RM"
        case .volume: "Volume"
        case .bestReps: tracksReps ? "Best reps" : "Longest hold"
        case .dots: "DOTS · e1RM"
        }
    }
}

enum ChartRange: String, CaseIterable, Hashable {
    case oneMonth = "1M", threeMonths = "3M", sixMonths = "6M", all = "ALL"

    var days: Int? {
        switch self {
        case .oneMonth: 30
        case .threeMonths: 91
        case .sixMonths: 182
        case .all: nil
        }
    }

    func includes(_ date: Int64, now: Int64) -> Bool {
        guard let days else { return true }
        return date >= now - Int64(days) * 86_400_000
    }
}

/// One person's plotted values.
private struct Series: Identifiable {
    struct Point: Identifiable {
        let point: SessionPoint
        let value: Double
        let isRecord: Bool
        var id: String { point.id }
        var date: Date { Date(epochMilliseconds: point.date) }
    }
    let person: Person
    let points: [Point]
    var id: String { person.id }
}

/// An exercise's progress: charts per metric, records and every session.
struct ExerciseProgressView: View {
    let exerciseId: String
    var highlightSession: String?
    @Environment(AppModel.self) private var model
    @State private var progress: ExerciseProgress?
    @State private var loaded = false
    @State private var metric: ProgressMetric = .topSet
    @State private var personFilter = "both"
    @State private var range: ChartRange = .all
    @State private var variant: Variant?
    @State private var rawSelection: Date?
    @State private var pinned: String?

    var body: some View {
        Group {
            if let progress {
                content(progress)
            } else if loaded {
                EmptyState(title: "Exercise removed", message: "It's no longer in your library; its sets stay in your workouts.")
                    .padding(18)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                // A real view while loading: an empty Group never appears, so
                // its .task (which loads the data) would never run.
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                for try await value in model.store.observeExerciseProgress(exerciseId: exerciseId) {
                    progress = value
                    loaded = true
                    if pinned == nil, let highlightSession, value?.sessions.contains(where: { $0.sessionId == highlightSession }) == true {
                        pinned = highlightSession
                    }
                }
            } catch {
                model.errorMessage = "COULD NOT LOAD PROGRESS — \(error.localizedDescription)"
            }
        }
    }

    // MARK: Content

    private func content(_ progress: ExerciseProgress) -> some View {
        let exercise = progress.exercise
        let tracksReps = exercise.tracksReps
        let variant = variant ?? progress.variants.first ?? .normal
        let people = model.catalog.pair.filter { !progress.series(variant: variant, personId: $0.id).isEmpty }
        let shown = people.filter { personFilter == "both" || $0.id == personFilter }
        let metrics = availableMetrics(exercise)
        let now = Date().epochMilliseconds
        let series = shown.map { person in makeSeries(progress, variant: variant, person: person, now: now, tracksReps: tracksReps) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).displayStyle(34, relativeTo: .largeTitle)
                    TitleRule()
                    let meta = [exercise.category, exercise.equipment].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !meta.isEmpty { Text(meta).metaStyle() }
                }

                if people.count > 1 {
                    Segmented(
                        options: [("both", "Both")] + people.map { ($0.id, $0.name) },
                        selection: $personFilter
                    )
                }
                if progress.variants.count > 1 {
                    Segmented(options: progress.variants.map { ($0, $0.label) }, selection: Binding(
                        get: { variant }, set: { self.variant = $0; pinned = nil }
                    ))
                }

                metricChips(metrics, progress: progress, variant: variant, people: people, shown: shown)
                rangeChips(series: series, allSeries: people.map { makeSeries(progress, variant: variant, person: $0, now: now, tracksReps: tracksReps, range: .all) }, now: now)

                heroNumbers(series, progress: progress, variant: variant, tracksReps: tracksReps)
                chartCard(series, tracksReps: tracksReps)
                if metric == .dots {
                    Text("Single-lift score from estimated 1RM at current bodyweight — compares you two on this lift, not a meet total.")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.textSecondary)
                }

                records(progress, variant: variant, people: people)
                sessionsLedger(progress, people: people)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .onChange(of: metric) { _, _ in pinned = nil }
        .onChange(of: range) { _, _ in pinned = nil }
        .onChange(of: personFilter) { _, _ in pinned = nil }
        .onChange(of: people.map(\.id)) { _, ids in
            if personFilter != "both" && !ids.contains(personFilter) { personFilter = "both" }
        }
    }

    private func availableMetrics(_ exercise: Exercise) -> [ProgressMetric] {
        if exercise.tracksWeight {
            return [.topSet, .e1rm, .volume] + (exercise.tracksReps ? [.bestReps] : []) + [.dots]
        }
        return [.bestReps]
    }

    private func makeSeries(_ progress: ExerciseProgress, variant: Variant, person: Person, now: Int64,
                            tracksReps: Bool, range: ChartRange? = nil) -> Series {
        let all = progress.series(variant: variant, personId: person.id)
        let records = Analytics.recordSessions(all, metric: metric, tracksReps: tracksReps)
        let points = all.compactMap { point -> Series.Point? in
            guard (range ?? self.range).includes(point.date, now: now),
                  let value = point.value(metric, tracksReps: tracksReps) else { return nil }
            return Series.Point(point: point, value: value, isRecord: records.contains(point.sessionId))
        }
        return Series(person: person, points: points)
    }

    // MARK: Pickers

    private func metricChips(_ metrics: [ProgressMetric], progress: ExerciseProgress, variant: Variant,
                             people: [Person], shown: [Person]) -> some View {
        let tracksReps = progress.exercise.tracksReps
        let unitsDiffer = Set(people.map(\.unit)).count > 1
        let missingProfile = shown.first { $0.sex == nil || $0.bodyweight == nil }
        let hasE1RM = shown.contains { person in
            progress.series(variant: variant, personId: person.id).contains { $0.bestE1RM != nil }
        }
        return VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(metrics, id: \.self) { option in
                        let disabled = (option == .e1rm && !hasE1RM) || (option == .dots && missingProfile != nil)
                        Button {
                            metric = option
                            if option.isWeight && unitsDiffer && personFilter == "both" { personFilter = people.first?.id ?? "both" }
                        } label: {
                            Chip(text: option.label(tracksReps: tracksReps), tint: disabled ? Palette.concrete : Palette.ink, filled: metric == option)
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                        .accessibilityAddTraits(metric == option ? .isSelected : [])
                    }
                }
            }
            if !hasE1RM && metrics.contains(.e1rm) {
                Text("Est. 1RM needs sets of 1–10 reps").metaStyle(size: 10)
            }
            if let missing = missingProfile, metrics.contains(.dots) {
                Button { model.editPerson(missing.id) } label: {
                    HStack(spacing: 4) {
                        Text("Set \(missing.name)'s sex & bodyweight for DOTS")
                        Icon(.arrowRight, size: 10)
                    }
                    .metaStyle(Palette.redDark, size: 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rangeChips(series: [Series], allSeries: [Series], now: Int64) -> some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases, id: \.self) { option in
                // A range needs at least two sessions to show a trend.
                let sessions = Set(allSeries.flatMap { $0.points.filter { option.includes($0.point.date, now: now) }.map(\.point.sessionId) })
                let usable = option == .all || sessions.count >= 2
                Button { range = option } label: {
                    Text(option.rawValue)
                        .labelStyle(13)
                        .foregroundStyle(range == option ? Palette.onDark : usable ? Palette.ink : Palette.concrete)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(range == option ? Palette.ink : Color.clear)
                }
                .buttonStyle(.plain)
                .disabled(!usable)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Palette.rule, lineWidth: Stroke.width))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    // MARK: Numbers

    private func heroNumbers(_ series: [Series], progress: ExerciseProgress, variant: Variant, tracksReps: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(series) { s in
                let unit = s.person.unit
                let all = progress.series(variant: variant, personId: s.person.id).compactMap { $0.value(metric, tracksReps: tracksReps) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.person.name).metaStyle(s.person.style.text)
                    if let latest = s.points.last {
                        Text(ProgressFormat.value(latest.value, metric, unit: unit, tracksReps: tracksReps))
                            .font(Typeface.display(30))
                            .textCase(.uppercase)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let first = s.points.first, s.points.count > 1 {
                            let change = latest.value - first.value
                            HStack(spacing: 4) {
                                if abs(change) > Analytics.recordEpsilon { Icon(change > 0 ? .arrowUp : .arrowDown, size: 10) }
                                Text(ProgressFormat.delta(change, metric, unit: unit, tracksReps: tracksReps) + " since \(Format.dayMonth(first.point.date))")
                            }
                            .font(Typeface.condensed(13))
                            .textCase(.uppercase)
                            .foregroundStyle(change > Analytics.recordEpsilon ? Palette.green : change < -Analytics.recordEpsilon ? Palette.redDark : Palette.textSecondary)
                        }
                        if let best = all.max() {
                            Text("Best " + ProgressFormat.value(best, metric, unit: unit, tracksReps: tracksReps)).metaStyle(size: 10)
                        }
                    } else {
                        Text("—").font(Typeface.display(30))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Chart

    private func chartCard(_ series: [Series], tracksReps: Bool) -> some View {
        let people = series.map(\.person)
        let allPoints = series.flatMap(\.points)
        let dense = allPoints.count > 40
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                readout(series, tracksReps: tracksReps)
                Spacer(minLength: 8)
                Legend(people: people)
            }
            if allPoints.isEmpty {
                Text("No sessions in this range").metaStyle()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(series) { s in
                        ForEach(s.points) { p in
                            LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Person", s.person.id))
                                .foregroundStyle(by: .value("Person", s.person.id))
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .square, lineJoin: .miter))
                                .interpolationMethod(.linear)
                            if p.isRecord {
                                PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                                    .symbol(.square)
                                    .symbolSize(170)
                                    .foregroundStyle(Palette.ink)
                            }
                            if p.isRecord || !dense {
                                PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                                    .symbol(.square)
                                    .symbolSize(p.isRecord ? 70 : 45)
                                    .foregroundStyle(by: .value("Person", s.person.id))
                            }
                        }
                    }
                    if let date = pinnedDate(series) {
                        RuleMark(x: .value("Selected", date))
                            .foregroundStyle(Palette.ink)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartForegroundStyleScale(domain: people.map(\.id), range: people.map(\.style.accent))
                .chartLegend(.hidden)
                .chartYScale(domain: yDomain(allPoints.map(\.value)))
                .chartXScale(domain: xDomain(allPoints.map(\.date)))
                .chartXSelection(value: $rawSelection)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Palette.ruleSoft.opacity(0.5))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(Typeface.condensed(11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Palette.ruleSoft.opacity(0.5))
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(axisLabel(v)) }
                        }
                        .font(Typeface.condensed(11))
                        .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(height: 240)
                .onChange(of: rawSelection) { _, date in
                    guard let date else { return }
                    // Snap to the nearest session; keep it after the finger lifts.
                    pinned = allPoints.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.point.sessionId
                }
                if allPoints.count == 1 || Set(allPoints.map(\.point.sessionId)).count == 1 {
                    Text("One session so far").metaStyle(size: 10)
                }
            }
        }
        .padding(14)
        .card()
    }

    private func readout(_ series: [Series], tracksReps: Bool) -> some View {
        Group {
            if let pinned, let date = pinnedDate(series) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.dayMonth(date.epochMilliseconds)).metaStyle(Palette.ink)
                    ForEach(series) { s in
                        if let p = s.points.first(where: { $0.point.sessionId == pinned }) {
                            Text("\(s.person.name) " + detail(p, unit: s.person.unit, tracksReps: tracksReps))
                                .font(Typeface.condensed(15))
                                .textCase(.uppercase)
                                .monospacedDigit()
                                .foregroundStyle(s.person.style.text)
                        }
                    }
                }
            } else {
                Text(metric.label(tracksReps: tracksReps) + " · tap the chart").metaStyle()
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The pinned session's value, with the set behind it where that helps.
    private func detail(_ p: Series.Point, unit: WeightUnit, tracksReps: Bool) -> String {
        let value = ProgressFormat.value(p.value, metric, unit: unit, tracksReps: tracksReps)
        switch metric {
        case .topSet: return ProgressFormat.set(weight: p.point.topWeight, reps: p.point.topWeightReps, unit: unit) + (p.isRecord ? " · PR" : "")
        case .e1rm: return value + " (" + ProgressFormat.set(weight: p.point.e1rmWeight, reps: p.point.e1rmReps, unit: unit) + ")" + (p.isRecord ? " · PR" : "")
        default: return value + (p.isRecord ? " · PR" : "")
        }
    }

    private func pinnedDate(_ series: [Series]) -> Date? {
        guard let pinned else { return nil }
        return series.lazy.flatMap(\.points).first { $0.point.sessionId == pinned }?.date
    }

    private func yDomain(_ values: [Double]) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        switch metric {
        case .volume, .bestReps: return 0...max(high * 1.1, 1)
        default:
            let pad = max((high - low) * 0.1, 2.5)
            return max(0, low - pad)...(high + pad)
        }
    }

    private func xDomain(_ dates: [Date]) -> ClosedRange<Date> {
        guard let first = dates.min(), let last = dates.max() else { return Date()...Date() }
        let pad: TimeInterval = first == last ? 3 * 86_400 : max(last.timeIntervalSince(first) * 0.04, 43_200)
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    private func axisLabel(_ v: Double) -> String {
        if metric == .volume, v >= 1000 { return "\(Format.trimNum((v / 100).rounded() / 10))K" }
        return Format.trimNum(v)
    }

    // MARK: Records & sessions

    private func records(_ progress: ExerciseProgress, variant: Variant, people: [Person]) -> some View {
        let exercise = progress.exercise
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Records")
            ForEach(people) { person in
                let r = Analytics.records(progress.series(variant: variant, personId: person.id))
                VStack(alignment: .leading, spacing: 8) {
                    Text(person.name).font(Typeface.display(18)).textCase(.uppercase).foregroundStyle(person.style.text)
                    if exercise.tracksWeight {
                        recordLine("Heaviest set", r.heaviest.map { (ProgressFormat.set(weight: $0.topWeight, reps: $0.topWeightReps, unit: person.unit), $0.date) })
                        recordLine("Best est. 1RM · \(OneRepMax.formulaName(for: person.sex))", r.bestE1RM.map { (ProgressFormat.value($0.bestE1RM ?? 0, .e1rm, unit: person.unit, tracksReps: true), $0.date) })
                        recordLine("Best session volume", r.bestVolume.map { (ProgressFormat.value($0.volume ?? 0, .volume, unit: person.unit, tracksReps: true), $0.date) })
                        if person.sex != nil && person.bodyweight != nil {
                            recordLine("Best DOTS", r.bestDOTS.map { (ProgressFormat.value($0.dots ?? 0, .dots, unit: person.unit, tracksReps: true), $0.date) })
                        }
                    } else if exercise.tracksReps {
                        recordLine("Most reps", r.bestReps.map { ("\($0.bestReps ?? 0) reps", $0.date) })
                    } else {
                        recordLine("Longest hold", r.bestDuration.map { (Format.duration($0.bestDuration ?? 0), $0.date) })
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.canvas)
                .overlay(alignment: .leading) { Rectangle().fill(person.style.accent).frame(width: 6) }
                .overlay(Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: 1))
            }
        }
    }

    private func recordLine(_ label: String, _ value: (String, Int64)?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).metaStyle(size: 11)
            Spacer()
            if let (text, date) = value {
                Text(text).font(Typeface.condensed(16)).textCase(.uppercase).monospacedDigit()
                Text(Format.dayMonth(date)).metaStyle(size: 10)
            } else {
                Text("—").font(Typeface.condensed(16))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sessionsLedger(_ progress: ExerciseProgress, people: [Person]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Sessions")
            ForEach(progress.sessions) { session in
                Button { model.historyPath.append(.workout(session.sessionId)) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.dayMonth(session.date)).font(Typeface.condensed(16)).textCase(.uppercase)
                            Text(session.name).metaStyle(size: 10)
                        }
                        .frame(width: 96, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(people) { person in
                                let points = session.byPerson[person.id] ?? []
                                let top = points.max { ($0.topWeight ?? 0) < ($1.topWeight ?? 0) }
                                let sets = points.reduce(0) { $0 + $1.setCount }
                                HStack(spacing: 6) {
                                    Rectangle().fill(person.style.accent).frame(width: 8, height: 8)
                                    Text(top?.topWeight != nil
                                         ? ProgressFormat.set(weight: top?.topWeight, reps: top?.topWeightReps, unit: person.unit)
                                         : sets > 0 ? "\(top?.bestReps ?? 0) reps" : "—")
                                        .font(Typeface.condensed(14))
                                        .textCase(.uppercase)
                                        .monospacedDigit()
                                    if sets > 0 { Text("\(sets) \(sets == 1 ? "set" : "sets")").metaStyle(size: 10) }
                                }
                            }
                        }
                        Spacer()
                        Icon(.chevronRight, size: 7).foregroundStyle(Palette.ink).padding(.top, 4)
                    }
                    .padding(.vertical, 10)
                    .background(session.sessionId == pinned ? Palette.canvas : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.ruleSoft).frame(height: 1) }
            }
        }
    }
}
