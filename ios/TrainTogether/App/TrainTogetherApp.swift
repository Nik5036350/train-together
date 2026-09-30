import SwiftUI
import UIKit

@main
struct TrainTogetherApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.device)
                .tint(Palette.ink)
                .preferredColorScheme(.light)
                .task { model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.sceneBecameActive()
            case .background: model.sceneEnteredBackground()
            default: break
            }
        }
    }

    /// System bars keep their iOS behavior and material; only the titles take
    /// the brand's condensed type (scaled with Dynamic Type).
    private static func styleNavigationBars() {
        let metrics = UIFontMetrics(forTextStyle: .headline)
        let largeMetrics = UIFontMetrics(forTextStyle: .largeTitle)
        let ink = UIColor(Palette.ink)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        if let title = UIFont(name: "RobotoCondensed-Bold", size: 18) {
            appearance.titleTextAttributes = [.font: metrics.scaledFont(for: title), .foregroundColor: ink]
        }
        if let large = UIFont(name: "RobotoCondensed-ExtraBold", size: 38) {
            appearance.largeTitleTextAttributes = [.font: largeMetrics.scaledFont(for: large), .foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
