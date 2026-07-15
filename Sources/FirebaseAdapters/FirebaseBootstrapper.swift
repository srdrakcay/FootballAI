import FirebaseAppCheck
import FirebaseCore
import Foundation

public enum FirebaseBootstrapper {
    @MainActor private static var didConfigure = false

    @MainActor
    @discardableResult
    public static func configure(bundle: Bundle = .main) -> Bool {
        // Firebase registry access itself emits I-COR000005 before first setup.
        // Keep process-local idempotency without touching Firebase until configure().
        guard !didConfigure else { return true }
        guard bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return false }
#if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
#endif
        FirebaseApp.configure()
        didConfigure = true
        return true
    }
}
