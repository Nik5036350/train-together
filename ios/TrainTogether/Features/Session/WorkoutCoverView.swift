import SwiftUI
import TrainTogetherCore
import TrainTogetherKit
import UIKit

/// The full-screen workout flow. One presentation that switches from the live
/// workout to its summary, so finishing never stacks two covers.
struct WorkoutCoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(DeviceSettings.self) private var device
    @State private var path: [String] = []

    var body: some View {
        Group {
            switch model.workoutCover {
            case .live(let sessionId)?:
                NavigationStack(path: $path) {
                    LiveOverviewView(sessionId: sessionId, path: $path)
                        .navigationDestination(for: String.self) { cardId in
                            LoggingCardView(cardId: cardId, path: $path)
                        }
                }
                .onAppear { keepAwake(device.keepScreenAwake) }
                .onDisappear { keepAwake(false) }
                .onChange(of: device.keepScreenAwake) { _, on in keepAwake(on) }
            case .summary(let sessionId)?:
                SummaryView(sessionId: sessionId)
                    .onAppear { keepAwake(false) }
            case nil:
                Color.clear
            }
        }
        .sensoryFeedback(.success, trigger: model.readyTick)
    }

    private func keepAwake(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
    }
}
