import AppUI
import FootballAIAppCore
import SwiftUI

/// The app shell now lives in the AppUI package module (redesign, Oct 2026).
struct RootView: View {
    let compositionRoot: AppCompositionRoot

    var body: some View {
        AppRootView(root: compositionRoot)
    }
}
