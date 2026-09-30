import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// First launch (no owner yet): restore from the server — how the web app's
/// data comes over — or start fresh.
struct OnboardingView: View {
    enum Step: Hashable { case restore, fresh }
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Palette.paper
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: geo.size.width * 0.35, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.75))
                            p.closeSubpath()
                        }
                        .fill(Palette.red)
                        Path { p in
                            p.move(to: CGPoint(x: geo.size.width * 0.72, y: geo.size.height))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.45))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            p.closeSubpath()
                        }
                        .fill(Palette.ink)
                    }
                    Grain()
                    VStack(alignment: .leading, spacing: 10) {
                        Image("Mark").resizable().frame(width: 72, height: 72).accessibilityHidden(true)
                        Text("Train\ntogether").displayStyle(TypeScale.displayXL, relativeTo: .largeTitle)
                            .lineSpacing(-8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Two people.")
                            Text("One phone.")
                            Text("Stronger together.").foregroundStyle(Palette.redDark)
                        }
                        .font(Typeface.condensed(18))
                        .textCase(.uppercase)
                    }
                    .padding(24)
                }
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    Button("Restore from server") { path.append(.restore) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Start fresh") { path.append(.fresh) }
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(20)
            }
            .paperBackground()
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .restore: RestoreView()
                case .fresh: StartFreshView()
                }
            }
        }
    }
}

private struct RestoreView: View {
    @Environment(AppModel.self) private var model
    @State private var url = ""
    @State private var token = ""
    @State private var working = false
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Restore from server").displayStyle(30)
                TitleRule()
                Text("Your workouts come down from your Train Together server; after that this phone keeps it up to date.")
                    .font(Typeface.body(15))
                    .foregroundStyle(Palette.textSecondary)
                field("Server", text: $url, prompt: "https://gym.example.com", secure: false)
                field("Sync token", text: $token, prompt: "SYNC_TOKEN", secure: true)
                if let failure {
                    Text(failure).font(Typeface.condensed(15)).textCase(.uppercase).foregroundStyle(Palette.redDark)
                }
                Button(working ? "Restoring…" : "Restore") { restore() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(working || SyncSettingsStore.normalizedURL(url) == nil || token.isEmpty)
            }
            .padding(20)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).metaStyle()
            Group {
                // The token isn't a login password: a SecureField makes iOS
                // offer "Save Password?" (the app keeps it in its own Keychain
                // item), so it's a plain field redacted in snapshots.
                if secure {
                    TextField(prompt, text: text).fontDesign(.monospaced).privacySensitive()
                } else {
                    TextField(prompt, text: text).keyboardType(.URL).textContentType(.URL)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(Typeface.body(17))
            .padding(12)
            .card(radius: Radius.sm)
        }
    }

    private func restore() {
        working = true
        failure = nil
        Task {
            defer { working = false }
            do {
                try model.syncSettings.save(serverURL: url, token: token)
                try await model.sync.unlink()
                let report = try await model.sync.restore()
                if report.inserted == 0 || model.snapshot.needsOnboarding {
                    failure = "The server has no workouts yet — start fresh instead."
                }
            } catch let error as SyncError {
                failure = error.message
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

private struct StartFreshView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var name = ""
    @State private var color: PersonColor = .red
    @State private var unit: WeightUnit = .kg
    @State private var partnerName = ""
    @State private var partnerColor: PersonColor = .steel
    @State private var partnerUnit: WeightUnit = .kg
    @State private var addExample = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(step == 0 ? "You" : "Your partner").displayStyle(30)
                TitleRule()
                if step == 0 {
                    PersonForm(name: $name, color: $color, unit: $unit, taken: nil)
                    Button("Next") { step = 1 }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    PersonForm(name: $partnerName, color: $partnerColor, unit: $partnerUnit, taken: previewOwner)
                    Toggle("Add the example Push Day routine", isOn: $addExample)
                        .font(Typeface.body(16))
                        .tint(Palette.green)
                    Button("Save partner") { finish(withPartner: true) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(partnerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Skip for now") { finish(withPartner: false) }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: color) { _, new in if partnerColor == new { partnerColor = new == .steel ? .red : .steel } }
    }

    private var previewOwner: Person {
        Person(id: "preview", name: name, initials: String(name.prefix(1)).uppercased(), color: color.rawValue, unit: unit, isOwner: true)
    }

    private func finish(withPartner: Bool) {
        model.perform("SETTING UP") { engine in
            try engine.createOwner(name: name, color: color, unit: unit)
            if withPartner { try engine.savePartner(name: partnerName, color: partnerColor, unit: partnerUnit) }
            if addExample { try engine.restoreDemoRoutine() }
        }
    }
}
