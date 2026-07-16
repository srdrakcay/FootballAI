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
