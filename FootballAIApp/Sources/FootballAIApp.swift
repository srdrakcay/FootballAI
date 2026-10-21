import FootballAIAppCore
import SwiftUI

@main
struct FootballAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let compositionRoot: AppCompositionRoot

    init() {
        AppCompositionRoot.bootstrapFirebase()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-mode") {
            // Screenshots and previews run on sample data and skip onboarding
            // (pass -footballai-show-onboarding to capture the onboarding screens).
            let showOnboarding = ProcessInfo.processInfo.arguments.contains("-footballai-show-onboarding")
            UserDefaults.standard.set(!showOnboarding, forKey: "footballai.onboarding.completed.v2")
            compositionRoot = AppCompositionRoot.mock()
        } else {
            compositionRoot = AppCompositionRoot.live()
        }
#else
        compositionRoot = AppCompositionRoot.live()
#endif
    }

    var body: some Scene { WindowGroup { RootView(compositionRoot: compositionRoot) } }
}
