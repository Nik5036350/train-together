import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.loaded {
                // Matches the launch screen while the first snapshot loads.
                Image("LaunchMark").frame(maxWidth: .infinity, maxHeight: .infinity).paperBackground()
            } else if model.snapshot.needsOnboarding {
                OnboardingView()
            } else {
                MainTabs()
            }
        }
        .overlay(alignment: .top) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) { model.errorMessage = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.standard, value: model.errorMessage)
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Workout", systemImage: "dumbbell.fill", value: AppTab.workout) {
                NavigationStack(path: $model.workoutPath) {
                    WorkoutHomeView()
                        .navigationDestination(for: WorkoutRoute.self) { route in
                            switch route {
                            case .routine(let id): RoutineBuilderView(templateId: id)
                            }
                        }
                }
            }
            Tab("History", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.history) {
                NavigationStack(path: $model.historyPath) {
                    HistoryListView()
                        .navigationDestination(for: HistoryRoute.self) { route in
                            switch route {
                            case .workout(let id): WorkoutDetailView(sessionId: id)
                            case .exercise(let id, let session): ExerciseProgressView(exerciseId: id, highlightSession: session)
                            }
                        }
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack(path: $model.settingsPath) {
                    SettingsView()
                        .navigationDestination(for: SettingsRoute.self) { route in
                            switch route {
                            case .person(let id): PersonEditView(personId: id)
                            case .addPartner: PersonEditView(personId: nil)
                            case .exercises: ExerciseLibraryView()
                            case .exercise(let id): ExerciseEditorView(exerciseId: id)
                            case .sync: SyncSettingsView()
                            case .data: DataView()
                            }
                        }
                }
            }
        }
        .modifier(InProgressAccessory())
        .fullScreenCover(isPresented: Binding(
            get: { model.workoutCover != nil },
            set: { if !$0 { model.workoutCover = nil } }
        )) {
            WorkoutCoverView()
                .environment(model)
                .environment(model.device)
        }
    }
}

/// The in-progress bar above the tab bar while the workout is minimized.
/// `isEnabled` needs iOS 26.1; on 26.0 the Resume card covers it. The
/// modifier is always applied so the TabView keeps its identity.
private struct InProgressAccessory: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: model.active != nil && model.workoutCover == nil) {
                InProgressBar()
            }
        } else {
            content
        }
    }
}

struct InProgressBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let active = model.active {
            Button { model.resumeWorkout() } label: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 10) {
                        Rectangle().fill(Palette.red).frame(width: 5, height: 24)
                        Text(active.session.displayName)
                            .font(Typeface.condensed(15))
                            .textCase(.uppercase)
                            .lineLimit(1)
                        Text(Format.elapsed(context.date.epochMilliseconds - active.session.startTime))
                            .font(Typeface.condensed(15))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textSecondary)
                        Spacer(minLength: 4)
                        if let turn = currentTurn(active) {
                            Text("\(turn.name)'s turn")
                                .font(Typeface.condensed(13))
                                .textCase(.uppercase)
                                .foregroundStyle(turn.style.text)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume \(active.session.displayName)")
        }
    }

    private func currentTurn(_ active: ActiveSessionSnapshot) -> Person? {
        guard active.participantIds.count > 1,
              let card = active.card(active.currentCardID) else { return nil }
        return model.catalog.person(card.exercise.activePersonId)
    }
}
