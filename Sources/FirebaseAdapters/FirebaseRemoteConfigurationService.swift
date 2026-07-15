import CoreDomain
import FirebaseRemoteConfig
import Foundation

public actor FirebaseRemoteConfigurationService: RemoteConfigurationService {
    private let remoteConfig: RemoteConfig

    public init() {
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
#if DEBUG
        settings.minimumFetchInterval = 0
#else
        settings.minimumFetchInterval = 3_600
#endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            "feature_analysis_generation_enabled": false as NSNumber,
            "feature_cached_analysis_read_enabled": true as NSNumber,
            "feature_premium_enabled": false as NSNumber,
            "supported_leagues_v1": "[\"PL\",\"PD\",\"SA\",\"BL1\",\"FL1\",\"UCL\"]" as NSString,
            "free_monthly_unique_views": 1 as NSNumber,
            "free_history_days": 30 as NSNumber,
            "premium_history_days": 365 as NSNumber,
            "analysis_credit_cost": 1 as NSNumber,
            "revenuecat_public_sdk_key_ios": "" as NSString,
        ])
    }

    public func bootstrap() -> AppConfiguration { configuration() }

    public func fetchAndActivate() async throws -> AppConfiguration {
        try await remoteConfig.fetchAndActivate()
        return configuration()
    }

    private func configuration() -> AppConfiguration {
        let leagueValue = remoteConfig.configValue(forKey: "supported_leagues_v1")
        let leagueStrings = (try? JSONDecoder().decode([String].self, from: leagueValue.dataValue)) ?? AppConfiguration.safeDefaults.supportedLeagues.map(\.rawValue)
        return AppConfiguration(
            features: .init(
                analysisGenerationEnabled: remoteConfig.configValue(forKey: "feature_analysis_generation_enabled").boolValue,
                cachedAnalysisReadEnabled: remoteConfig.configValue(forKey: "feature_cached_analysis_read_enabled").boolValue,
                premiumEnabled: remoteConfig.configValue(forKey: "feature_premium_enabled").boolValue
            ),
            supportedLeagues: Set(leagueStrings.map(CompetitionID.init(rawValue:))),
            planLimits: .init(
                freeMonthlyUniqueViews: remoteConfig.configValue(forKey: "free_monthly_unique_views").numberValue.intValue,
                freeHistoryDays: remoteConfig.configValue(forKey: "free_history_days").numberValue.intValue,
                premiumHistoryDays: remoteConfig.configValue(forKey: "premium_history_days").numberValue.intValue
            ),
            analysisCreditCost: remoteConfig.configValue(forKey: "analysis_credit_cost").numberValue.intValue,
            revenueCatPublicSDKKeyIOS: remoteConfig.configValue(forKey: "revenuecat_public_sdk_key_ios").stringValue
        )
    }
}
