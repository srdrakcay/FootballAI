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

        // Simülatörde debug provider, fiziksel cihazlarda her zaman App Attest kullan.
        // Böylece her cihaz için ayrı debug token eklemeye gerek kalmaz.
#if DEBUG
        print("🔧 [AppCheck] Geliştirme (DEBUG) — Debug Provider kullanılıyor")
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
        print("🚀 [AppCheck] Canlı (RELEASE) — App Attest Provider kullanılıyor")
        AppCheck.setAppCheckProviderFactory(FootballAIAppCheckProviderFactory())
#endif

#if DEBUG
        print("🟡 [Build] DEBUG mode")
#else
        print("🟢 [Build] RELEASE mode")
#endif

        FirebaseApp.configure()
        didConfigure = true
        return true
    }
}

// MARK: - Custom App Check Provider Factory (Physical devices)

/// Fiziksel cihazlarda App Attest kullanır (iOS 14+),
/// desteklemeyenlerde DeviceCheck'e fallback yapar.
#if !targetEnvironment(simulator)
final class FootballAIAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
    }
}
#endif


