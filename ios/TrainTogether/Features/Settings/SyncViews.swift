import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Server URL and token, sync status, and the restore/re-upload tools.
struct SyncSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var url = ""
    @State private var token = ""
    @State private var working = false
    @State private var serverHasData: Int?
    @State private var confirmRestore = false
    @State private var confirmReupload = false
    @State private var notice: String?

    var body: some View {
        Form {
            Section {
                TextField("https://gym.example.com", text: $url)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                // Not a SecureField: iOS would offer to save it as a login password.
                TextField("Sync token", text: $token)
                    .fontDesign(.monospaced)
                    .privacySensitive()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(working ? "Connecting…" : "Connect", action: connect)
                    .disabled(working || SyncSettingsStore.normalizedURL(url) == nil || token.isEmpty)
            } header: {
                Text("Server")
            } footer: {
                Text("The token is the server's SYNC_TOKEN. It's kept in this phone's Keychain.")
            }

            Section("Status") {
                Text(model.syncSnapshot.statusLine)
                    .font(Typeface.condensed(16))
                    .foregroundStyle(model.syncSnapshot.statusColor)
                if let notice {
                    Text(notice).font(Typeface.body(14)).foregroundStyle(Palette.textSecondary)
                }
                Button("Sync now") { Task { await model.sync.syncNow() } }
                    .disabled(model.syncSettings.configuration() == nil)
            }

            Section {
                Button("Re-upload all data") { confirmReupload = true }
                Button("Restore from server", role: .destructive) { confirmRestore = true }
            } header: {
                Text("Recovery")
            } footer: {
                Text("Restore replaces everything on this phone with the server's copy.")
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("SYNC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            url = model.syncSettings.serverURL
            token = model.syncSettings.token
        }
        .alert("Server already has data", isPresented: Binding(get: { serverHasData != nil }, set: { if !$0 { serverHasData = nil } })) {
            Button("Restore from server", role: .destructive) { restore() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It holds \(serverHasData ?? 0) records this phone never synced. Restore replaces this phone's data with them; the two can't be merged.")
        }
        .confirmationDialog("Replace this phone's data?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore from server", role: .destructive) { restore() }
        } message: {
            Text("Everything on this phone is replaced with the server's copy.")
        }
        .confirmationDialog("Upload everything again?", isPresented: $confirmReupload, titleVisibility: .visible) {
            Button("Re-upload all data") {
                Task {
                    do { try await model.sync.reuploadAll() } catch { model.errorMessage = "RE-UPLOAD FAILED — \(error.localizedDescription)" }
                }
            }
        }
    }

    private func connect() {
        working = true
        notice = nil
        Task {
            defer { working = false }
            do {
                let changedServer = SyncSettingsStore.normalizedURL(url) != SyncSettingsStore.normalizedURL(model.syncSettings.serverURL)
                try model.syncSettings.save(serverURL: url, token: token)
                if changedServer { try await model.sync.unlink() }
                switch try await model.sync.connect() {
                case .linked: notice = "Connected."
                case .serverHasData(let records): serverHasData = records
                }
            } catch let error as SyncError {
                model.errorMessage = error.message
            } catch {
                model.errorMessage = "CONNECTING FAILED — \(error.localizedDescription)"
            }
        }
    }

    private func restore() {
        working = true
        Task {
            defer { working = false }
            do {
                let report = try await model.sync.restore()
                notice = report.summary
            } catch let error as SyncError {
                model.errorMessage = "RESTORE FAILED — \(error.message)"
            } catch {
                model.errorMessage = "RESTORE FAILED — \(error.localizedDescription)"
            }
        }
    }
}

extension RestoreReport {
    var summary: String {
        var text = "Restored \(inserted) records."
        if orphansDropped > 0 { text += " \(orphansDropped) without a parent were skipped." }
        if undecodable > 0 { text += " \(undecodable) couldn't be read." }
        return text
    }
}

/// Record counts on the phone and the server, side by side — how the cutover
/// from the web app is checked.
struct DataView: View {
    @Environment(AppModel.self) private var model
    @State private var local: [String: Int] = [:]
    @State private var server: ServerStatus?
    @State private var serverError: String?

    private static let labels: [(String, String)] = [
        ("person", "People"), ("exercise", "Exercises"), ("person_exercise_profile", "Personal exercise settings"),
        ("template", "Routines"), ("template_exercise", "Routine exercises"), ("workout_session", "Workouts"),
        ("session_participant", "Workout participants"), ("session_exercise", "Workout exercises"),
        ("session_exercise_person", "Per-person exercise states"), ("set_entry", "Sets"), ("settings", "Settings"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(Self.labels, id: \.0) { entity, label in
                    HStack {
                        Text(label)
                        Spacer()
                        Text("\(local[entity] ?? 0)").monospacedDigit()
                        if let server {
                            let remote = server.countsByEntity[entity] ?? 0
                            Text("\(remote)")
                                .monospacedDigit()
                                .foregroundStyle(remote == (local[entity] ?? 0) ? Palette.green : Palette.redDark)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }
                    .font(Typeface.body(15))
                }
            } header: {
                HStack {
                    Text("Records")
                    Spacer()
                    Text(server == nil ? "Phone" : "Phone · Server")
                }
            } footer: {
                if let serverError { Text(serverError) }
                else { Text("\(model.syncSnapshot.pending) changes waiting to upload.") }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("DATA")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        local = (try? model.store.recordCounts()) ?? [:]
        do {
            server = try await model.sync.serverStatus()
            serverError = nil
        } catch let error as SyncError {
            serverError = error == .missingConfiguration ? "Connect a server to compare." : error.message
        } catch {
            serverError = error.localizedDescription
        }
    }
}
