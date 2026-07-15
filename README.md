# FootballAI ADK — Updated

FootballAI, iOS üzerinde yaklaşan futbol maçları için **kesin sonuç iddiasında bulunmadan**, yalnızca backend tarafından sağlanan yapılandırılmış veri anlık görüntüsünü yorumlayarak yüzdelik olasılıklar ve gerekçeli analiz sunar.

Bu paket iki fazı kapsar:

- **Phase 1 — Product specification:** kapsam, gereksinimler, AI sözleşmesi, plan/kota/history, kullanıcı akışları, yerelleştirme, Remote Config, güven ve ölçüm kararları.
- **Phase 2 — Architecture:** Clean Architecture + MVVM, modüller, protokoller, Firestore, Remote Config, localization, güvenlik, analiz pipeline'ı, single-flight/cache, hata ve test yaklaşımı.

> Kaynak notu: İstekte belirtilen `/mnt/data` mount'u bu çalışma ortamında bulunamadı ve ekli özgün Markdown dosyaları erişilebilir değildi. Bu nedenle paket, aktarılan konuşmadaki mevcut Phase 1 içeriği ve kullanıcının yeni gereksinimleri temel alınarak yeniden oluşturulmuş canonical sürümdür.

## Temel ürün kararları

1. Model internete veya örtük bilgisine dayanmaz; yalnızca doğrulanmış `AnalysisInputSnapshot` içeriğini kullanır.
2. Çıktılar olasılıktır, kesin tahmin değildir; toplamları ve aralıkları backend'de doğrulanır.
3. TR/EN/ES/FR ilk sürümden itibaren desteklenir.
4. Firebase Remote Config yalnızca gizli olmayan çalışma zamanı ayarları içindir. API anahtarları Google Secret Manager / Cloud Functions secrets içinde tutulur.
5. Ortak cache maliyet optimizasyonudur; kullanıcı görüntüleme kotası cache hit/miss'ten bağımsızdır.
6. Analizler snapshot, fixture, prompt, model ve schema versiyonuna bağlıdır; TTL sonunda veya kaynak değişiminde `stale` olur.

## Doküman haritası

### Phase 1 — görünür `docs/` klasörü

- [docs/00_PRODUCT_SCOPE.md](docs/00_PRODUCT_SCOPE.md)
- [docs/01_REQUIREMENTS.md](docs/01_REQUIREMENTS.md)
- [docs/02_AI_ANALYSIS_CONTRACT.md](docs/02_AI_ANALYSIS_CONTRACT.md)
- [docs/03_PLANS_QUOTAS_HISTORY.md](docs/03_PLANS_QUOTAS_HISTORY.md)
- [docs/04_USER_FLOWS_PERSONAS.md](docs/04_USER_FLOWS_PERSONAS.md)
- [docs/05_LOCALIZATION_CONTENT.md](docs/05_LOCALIZATION_CONTENT.md)
- [docs/06_TRUST_LEGAL_ANALYTICS.md](docs/06_TRUST_LEGAL_ANALYTICS.md)
- [docs/07_REMOTE_CONFIG_CATALOG.md](docs/07_REMOTE_CONFIG_CATALOG.md)

### Phase 2 — görünür `architecture/` klasörü

- [architecture/README.md](architecture/README.md)
- [architecture/01_OVERVIEW.md](architecture/01_OVERVIEW.md)
- [architecture/02_MODULES_AND_FOLDERS.md](architecture/02_MODULES_AND_FOLDERS.md)
- [architecture/03_DOMAIN_CONTRACTS.md](architecture/03_DOMAIN_CONTRACTS.md)
- [architecture/04_FIRESTORE_SCHEMA.md](architecture/04_FIRESTORE_SCHEMA.md)
- [architecture/05_REMOTE_CONFIG_AND_LOCALIZATION.md](architecture/05_REMOTE_CONFIG_AND_LOCALIZATION.md)
- [architecture/06_SECURITY_AND_SECRETS.md](architecture/06_SECURITY_AND_SECRETS.md)
- [architecture/07_ANALYSIS_PIPELINE.md](architecture/07_ANALYSIS_PIPELINE.md)
- [architecture/08_CACHING_AND_CONCURRENCY.md](architecture/08_CACHING_AND_CONCURRENCY.md)
- [architecture/09_ERRORS_AND_TESTING.md](architecture/09_ERRORS_AND_TESTING.md)
- [architecture/10_PHASE2_CHECKLIST.md](architecture/10_PHASE2_CHECKLIST.md)

`.adk/` altındaki aynı yapı araç uyumluluğu için ayrıca korunmaktadır; Finder gizli klasörleri varsayılan olarak göstermez.

Bkz. [ROADMAP.md](ROADMAP.md) ve [CHANGELOG.md](CHANGELOG.md).

## Implementation scaffold

İlk Phase 3 iterasyonu aşağıdaki çalıştırılabilir temeli ekler:

- `FootballAIApp/FootballAIApp.xcodeproj`: iOS 17+ SwiftUI uygulama hedefi.
- `Package.swift` ve `Sources/`: Swift 6 domain, localization, fixtures, analysis, Firebase adapter ve composition-root modülleri.
- `Tests/`: probability/config/use-case unit testleri.
- `functions/`: Auth + App Check sınırıyla fail-closed TypeScript Cloud Functions iskeleti.
- `schemas/`: versioned AI input/output JSON Schema kontratları.
- `firestore/`: deny-by-default rules ve index taslakları.
- `remote-config/`: secret içermeyen safe defaults ve JSON Schema.

Backend çekirdeği ayrıca deterministic output validation, quota reservation/immutable usage ledger, single-flight lease epoch/recovery, snapshot freshness ve provider-independent model gateway kontratlarını içerir. iOS analysis cache'i locale ve `validUntil` değerine bağlıdır; offline durumda yeni generation başlatılmaz.

Detaylı durum için [implementation audit](docs/08_IMPLEMENTATION_AUDIT.md) ve [implementation checklist](IMPLEMENTATION_CHECKLIST.md) dosyalarına bakın.
Firebase/provider/RevenueCat kurulumu için [integration setup](docs/09_INTEGRATION_SETUP.md) dokümanına bakın.

## Çalıştırma

Gereksinimler: Xcode 26 veya Swift 6.1+; uygulama deployment target'ı iOS 17'dir.

Xcode'da `FootballAIApp/FootballAIApp.xcodeproj` dosyasını açın, `FootballAI` scheme'ini ve bir iOS Simulator seçip çalıştırın. Uygulama ilk iterasyonda yalnızca mock composition kullanır; Firebase credential gerektirmez.

Komut satırında Swift testleri:

```bash
swift test
```

iOS Simulator build:

```bash
xcodebuild \
  -project FootballAIApp/FootballAIApp.xcodeproj \
  -scheme FootballAI \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Backend için Node.js 22 ve npm gerekir:

```bash
cd functions
npm install
npm test
```

Repository'de reproducible dependency resolution için `functions/pnpm-lock.yaml` da bulunur; pnpm kullanan CI `pnpm install --frozen-lockfile && pnpm test` çalıştırabilir.

`GoogleService-Info.plist`, `.env`, local xcconfig ve gerçek secret'lar source control'a eklenmemelidir. Canlı Function şu aşamada bilinçli olarak `CONFIG_UNAVAILABLE` ile fail closed davranır; Firebase ortamı ve server-authoritative persistence bağlanmadan generation açılmamalıdır.
