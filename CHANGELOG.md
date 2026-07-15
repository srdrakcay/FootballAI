# Changelog

## Unreleased — Phase 3 foundation

### Added

- Swift 6 modular package, iOS 17 SwiftUI app target and constructor-injected composition root.
- Typed fixture/analysis domain models, probability invariants, repository/use-case contracts and in-memory implementations.
- Fixture list/detail and analysis state/result UI scaffolds with TR/EN/ES/FR String Catalog foundations.
- Firebase adapter boundaries and a fail-closed Cloud Functions TypeScript skeleton with Auth/App Check request guards.
- Versioned AnalysisInputSnapshot/AnalysisResult JSON Schemas, Firestore rules/indexes and validated Remote Config defaults.
- Swift unit tests, implementation audit, run instructions and progress checklist.
- Deterministic AI output validator covering schema, identity, probability totals, evidence availability, temporal validity and prohibited claims.
- Transactional quota/single-flight reference model with separate reservations, immutable usage commits, lease epochs, recovery and 100-caller concurrency tests.
- Snapshot freshness/prompt projection, allowlisted model gateway and Secret Manager binding boundaries.
- iOS eligibility policy plus locale-aware, TTL-enforced, file-protected offline analysis cache.
- Product integration defaults: bundle ID `com.footballai.predictions.com`, Free quota 1/month, RevenueCat, Gemini 3.5 Flash server alias and football-data.org API v4 Free development provider.
- Added a server-only football-data.org client with `X-Auth-Token`, bounded retry/timeout and response-header-aware throttling.
- Recorded Firebase provisioning as user-complete; deferred live Gemini and RevenueCat setup until Apple Developer account provisioning without blocking the free core flow.
- Replaced the system-default prototype UI with a purple-neon SwiftUI design system, three-page onboarding, custom match dashboard/detail, persistent bottom navigation, analysis history and profile/settings surfaces.
- Firebase Apple SDK 12.14.0, project alias, bundled Google service configuration and Debug/Release App Check bootstrap.

## 2.0.0 — 2026-07-15

### Changed

- AI girdisi, backend tarafından üretilen yapılandırılmış `AnalysisInputSnapshot` ile sınırlandı.
- Kesin skor/sonuç dili kaldırıldı; tüm tahminler yüzdelik olasılık ve sınırlılıklarla tanımlandı.
- Cache “bir kez ve sonsuza kadar” yerine TTL + version tuple + stale/version history modeline geçirildi.
- Ücretsiz paket “ayda 1 cache miss” yerine cache'den bağımsız görüntüleme hakkı olarak netleştirildi.
- Premium lig çelişkisi çözüldü: v1 çekirdek ligleri tüm kullanıcılara açık; Premium sınırsız görüntüleme ve uzun history sunar. Ek ligler kapalı feature flag ile sonraki kapsamdadır.
- Notification settings Phase 1 UI'ından çıkarıldı; notification özelliği varsayılan kapalı gelecek kapsam oldu.
- Champions League persona çelişkisi kaldırıldı; dönüşüm tetikleyicisi görüntüleme kotası ve history oldu.
- Free history 30 gün, Premium history abonelik süresince + 365 gün görünürlük olarak tanımlandı.

### Added

- TR/EN/ES/FR localization gereksinimleri ve fallback mimarisi.
- AI schema metadata, kaynak izi, confidence, limitations, validation ve failure alanları.
- Analiz durum makinesi, idempotency, single-flight, lock lease ve quota ledger kuralları.
- Remote Config katalogu: feature flags, ligler, kota, metin varyantları, TTL, prompt/model/schema sürümleri.
- Secret Manager tabanlı secret rotasyon runbook'u; API key'lerin Remote Config'e konmayacağı açık kuralı.
- Firestore schema, security ownership, repository/use-case protokolleri, hata modeli ve test matrisi.
- Privacy, subscription, account deletion, AI disclosure ve analytics kalite gereksinimleri.
- Finder'da doğrudan erişim için `.adk/docs` ve `.adk/architecture` içeriklerinin görünür `docs/` ve `architecture/` kopyaları.

### Source limitation

- İstekte anılan `/mnt/data` bu ortamda mevcut değildi; özgün ekler doğrudan diff edilemedi. Bu sürüm, paylaşılan konuşmadaki Phase 1 kararlarını kapsayan yeniden oluşturulmuş canonical pakettir.
