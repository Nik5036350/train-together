import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Settings — the least decorative screens (§36).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(DeviceSettings.self) private var device

    var body: some View {
        @Bindable var device = device
        let catalog = model.catalog
        Form {
            if BuildExpiry.isSoon(), let date = BuildExpiry.date {
                Section {
                    Text("This build stops opening \(date.formatted(.relative(presentation: .named))). Reinstall it from Xcode.")
                        .font(Typeface.body(15))
                        .foregroundStyle(Palette.onDark)
                        .listRowBackground(Palette.mustard.opacity(0.9))
                }
            }

            Section("People") {
                if let owner = catalog.owner {
                    NavigationLink(value: SettingsRoute.person(owner.id)) {
                        PersonRow(person: owner, caption: "You")
                    }
                }
                if let partner = catalog.partner {
                    NavigationLink(value: SettingsRoute.person(partner.id)) {
                        PersonRow(person: partner, caption: "Partner")
                    }
                } else {
                    NavigationLink(value: SettingsRoute.addPartner) {
                        Label("Add a partner", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("Library") {
                NavigationLink(value: SettingsRoute.exercises) {
                    LabeledContent("Exercises", value: "\(catalog.exercises.count)")
                }
            }

            Section {
                if let owner = catalog.owner, let partner = catalog.partner {
                    Picker("Who's training", selection: Binding(
                        get: { catalog.settings.defaultParticipants },
                        set: { value in model.perform("SAVING SETTINGS") { try $0.updateSettings(defaultParticipants: value) } }
                    )) {
                        Text("\(owner.name) + \(partner.name)").tag(Participants.both)
                        Text("\(owner.name) only").tag(Participants.owner)
                        Text("\(partner.name) only").tag(Participants.partner)
                    }
                }
                Picker("Logging style", selection: Binding(
                    get: { catalog.settings.defaultLoggingStyle },
                    set: { value in model.perform("SAVING SETTINGS") { try $0.updateSettings(defaultLoggingStyle: value) } }
                )) {
                    ForEach(LoggingMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            } header: {
                Text("New workouts")
            } footer: {
                Text("Starting a routine uses the routine's own logging style.")
            }

            Section("This phone") {
                Toggle("Keep screen awake during a workout", isOn: $device.keepScreenAwake)
                Toggle("Rest-over alerts", isOn: $device.restAlertsEnabled)
                Toggle("Rest timer on Lock Screen", isOn: $device.liveActivityEnabled)
            }

            Section("Sync & data") {
                NavigationLink(value: SettingsRoute.sync) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Server sync")
                        Text(model.syncSnapshot.statusLine)
                            .font(Typeface.condensed(13))
                            .foregroundStyle(model.syncSnapshot.statusColor)
                    }
                }
                NavigationLink("Data on this phone", value: SettingsRoute.data)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.versionString)
                if let date = BuildExpiry.date {
                    LabeledContent("Build expires", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("SETTINGS")
    }
}

private struct PersonRow: View {
    let person: Person
    let caption: String

    var body: some View {
        HStack(spacing: 12) {
            Avatar(person: person, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.name).font(Typeface.condensed(17)).textCase(.uppercase)
                Text("\(caption) · \(person.unit.rawValue)").font(Typeface.body(13)).foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

extension SyncSnapshot {
    /// "SYNCED · 14:02", "4 CHANGES PENDING", "OFFLINE", …
    var statusLine: String {
        let pendingText = pending == 1 ? "1 CHANGE PENDING" : "\(pending) CHANGES PENDING"
        switch status {
        case .notConfigured: return "NOT SET UP"
        case .notLinked: return "NOT CONNECTED"
        case .syncing: return pending > 0 ? "SYNCING · \(pendingText)" : "SYNCING"
        case .synced(let at):
            if pending > 0 { return pendingText }
            return "SYNCED · \(Date(epochMilliseconds: at).formatted(date: .omitted, time: .shortened))"
        case .offline: return pending > 0 ? "OFFLINE · \(pendingText)" : "OFFLINE"
        case .failed(let error): return error.message
        case .serverReset: return "SERVER RESET — RE-UPLOADING"
        }
    }

    var statusColor: Color {
        switch status {
        case .synced where pending == 0: Palette.green
        case .failed, .serverReset: Palette.redDark
        case .offline: Palette.mustard
        default: Palette.textSecondary
        }
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
