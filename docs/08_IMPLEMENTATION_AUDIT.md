# Phase 3 — İlk İterasyon Implementation Audit

Tarih: 2026-07-15

## Başlangıç durumu

Repository inceleme başlangıcında yalnızca `README.md`, `ROADMAP.md`, `CHANGELOG.md`, `docs/`, `architecture/` ve bunların `.adk/` kopyaları vardı. Swift/Xcode projesi, backend kodu, şemalar, Firebase kuralları ve test altyapısı yoktu. Repository bir Git worktree değildi; bu nedenle diff/status tabanlı değişiklik sahipliği kontrolü yapılamadı.

## Doküman uyumu ve kararlar

- Görünür `docs/` ve `architecture/` canonical kaynak olarak kullanıldı; `.adk/` kopyaları değiştirilmedi.
- Clean Architecture sınırı Swift Package target'larıyla kuruldu. ViewModel'ler yalnızca use case protokollerine bağımlıdır.
- Canlı SDK kurulumu yerine Firebase sınır protokolleri ve güvenli in-memory implementasyonlar eklendi. Firebase ortamları sağlanana kadar Functions callable fail-closed `CONFIG_UNAVAILABLE` döndürür.
- Canonical numeric analysis locale'den bağımsız modellenmiştir; locale yalnızca artifact erişiminde taşınır.
- Locale fallback için ayrıntılı dokümandaki exact locale → base language → English kararı uygulandı.
- Remote Config defaults'ta generation kapalıdır. Model adı provider modeline değil, server allowlist'indeki alias'a karşılık gelir.
- Üretim disclaimer çevirileri placeholder değildir ancak doküman gereği hukuki/lokalizasyon onayı bekler.

## Başlangıç gap analizi

| Alan | Başlangıç gap'i | İlk iterasyon sonucu |
|---|---|---|
| iOS build | Proje yok | iOS 17 SwiftUI app target + Swift 6 package modülleri |
| Domain | Model/protokol yok | Typed ID, fixture, analysis, probability invariant, error ve config modelleri |
| Features | Akış yok | Fixture list/detail ve analysis state/result iskeleti |
| DI | Yok | Constructor injection kullanan `AppCompositionRoot` |
| Localization | Yok | TR/EN/ES/FR String Catalog ve locale resolver |
| Data/Firebase | Yok | Dar adapter protokolleri ve in-memory repository'ler |
| Backend | Yok | TypeScript Functions sınırı, guard, state machine, version hash ve config validator iskeleti |
| Contracts | Yok | Input/output JSON Schema dosyaları |
| Firestore | Yok | Deny-by-default rules ve başlangıç indexleri |
| Tests | Yok | Swift unit testleri ve backend state-machine test iskeleti |

## Belirsizlikler ve dış blokajlar

- Free aylık hak 1 olarak ve bundle ID `com.footballai.predictions.com` olarak ürün sahibi tarafından onaylandı.
- Firebase project `footballai-40789`, Apple SDK ve `GoogleService-Info.plist` bağlandı. Firestore `eur3`, Functions `europe-west1`; Firebase Console ürünleri, billing/runtime, App Check ve Secret Manager hazırlığı kullanıcı tarafından tamamlandı. Emulator/deploy smoke testi kod tarafında ayrıca yapılacaktır.
- Development için Gemini `gemini-3.5-flash` ve football-data.org API v4 Free seçildi. Gemini canlı gateway/secret kurulumu Apple hesabı açılana kadar ürün sahibi kararıyla ertelendi; production lisans, kapasite ve bölgesel veri işleme onayı bekliyor.
- RevenueCat seçildi; Apple Developer hesabı açılana kadar entegrasyon ertelendi. Entitlement/offering/product kimlikleri ve public SDK key henüz sağlanmadı.
- Hukuki metinler, yaş derecelendirmesi ve dört dil çevirileri profesyonel onay bekliyor.
- Sistem PATH'inde Node.js/npm yoktu; Codex bundled Node 24 + pnpm runtime'ı ile TypeScript strict build ve 6 backend testi çalıştırıldı. Production runtime hedefi Node 22 olduğundan CI/emulator turu Node 22 üzerinde ayrıca yapılmalıdır.

## Sonraki uygulama sırası

1. Firebase emulator ve environment yapılandırmasını kur; Auth/App Check doğrulamalarını integration test et.
2. Firestore transaction tabanlı request/lease/single-flight ve immutable quota ledger'ı uygula.
3. Snapshot ingestion/normalization/freshness pipeline'ını provider sandbox ile bağla.
4. AJV schema + cross-field/evidence/prohibited-language validator ve model gateway'i uygula.
5. SDK-backed iOS repositories, local read-only cache ve offline davranışını ekle.
6. History, entitlement/paywall, account ve settings feature'larını geliştir.
7. Rules emulator, concurrency/load, localization snapshot ve accessibility testlerini CI'a bağla.

## İkinci iterasyon ilerlemesi

- AnalysisResult JSON Schema doğrulamasının üzerine cross-field probability, duplicate scoreline, canonical identity, evidence availability, kickoff validity ve locale-aware prohibited-claim kontrolleri eklendi.
- Quota reservation ile immutable `usageLedger` ayrıldı. Başarılı teslimatta deterministic commit kaydı oluşturuluyor; permanent failure ve maksimum-attempt lease timeout reservation'ı serbest bırakıyor.
- 100 eşzamanlı caller'ın tek deterministic request ve tek lease owner üretmesi test edildi. Lease epoch compare-and-set eski worker'ın yeni sonucu ezmesini engelliyor.
- `quotaReservations` Firestore taslağına ve deny-by-default rules/index kataloguna eklendi.
- Snapshot section freshness normalizasyonu ve model gateway'e yalnızca `available` section projection'ı uygulandı.
- Provider/model seçimi server allowlist arkasına alındı; Secret Manager binding adları tanımlandı, secret değeri eklenmedi.
- iOS'ta server kararının UX hint karşılığı olan eligibility policy eklendi. Offline yeni generation reddedilir; süresi dolmamış localized analysis file-protected disk cache'den okunabilir.
- football-data.org için server-only v4 client eklendi. Token yalnızca `X-Auth-Token` başlığında kullanılır; kota/reset başlıkları otomatik throttling'e beslenir, timeout ve sınırlı transient retry uygulanır.
- Doğrulama: Swift 13/13, backend 19/19 test ve iOS Simulator build başarılı.
