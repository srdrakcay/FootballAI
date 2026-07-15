import FootballAIAppCore
import SwiftUI

@main
struct FootballAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let compositionRoot: AppCompositionRoot

    init() {
        AppCompositionRoot.bootstrapFirebase()
        compositionRoot = AppCompositionRoot.live()
    }

    var body: some Scene { WindowGroup { RootView(compositionRoot: compositionRoot) } }
}
