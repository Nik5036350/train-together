import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Who's training and how turns work, then go. The style is preselected from
/// the routine's own mode (or the default style for a quick workout).
struct StartWorkoutSheet: View {
    let templateId: String?
    /// Called with the new workout's id; the presenter opens it once the
    /// sheet has gone (a cover can't present over a dismissing sheet).
    let onStarted: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var participants: Participants = .both
    @State private var style: LoggingMode = .alternate

    var body: some View {
        let catalog = model.catalog
        let routine = catalog.routine(templateId)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(routine == nil ? "Empty workout" : "Start workout").metaStyle(Palette.redDark)
                Text(routine?.template.name ?? "Quick workout").displayStyle(30)
                TitleRule(height: Stroke.width)
            }

            if let partner = catalog.partner, let owner = catalog.owner {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Who's training")
                    Segmented(options: [
                        (Participants.owner, "\(owner.name) only"),
                        (.partner, "\(partner.name) only"),
                        (.both, "\(owner.name) + \(partner.name)"),
                    ], selection: $participants, variant: .cards)
                }
                if participants == .both {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Logging style")
                        Segmented(options: LoggingMode.allCases.map { ($0, $0.label) }, selection: $style)
                        Text(style.explanation)
                            .font(Typeface.body(14))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
            Button("Start workout") { start() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("start-workout-confirm")
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.paper)
        .presentationCornerRadius(Radius.lg)
        .onAppear {
            participants = catalog.partner == nil ? .owner : catalog.settings.defaultParticipants
            style = routine?.template.defaultMode ?? catalog.settings.defaultLoggingStyle
        }
    }

    private func start() {
        let ids = model.catalog.participantIds(for: participants)
        var sessionId: String?
        let ok = model.perform("STARTING THE WORKOUT") {
            sessionId = try $0.startSession(templateId: templateId, participantIds: ids, loggingStyle: style)
        }
        if ok, let sessionId {
            onStarted(sessionId)
            dismiss()
        }
    }
}

extension LoggingMode {
    var explanation: String {
        switch self {
        case .alternate: "Both of you log freely; the turn passes after each set."
        case .turns: "One of you logs while the other rests; each set passes the phone."
        case .independent: "Both columns stay open; nobody's turn."
        }
    }
}
