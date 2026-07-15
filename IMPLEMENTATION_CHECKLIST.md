# İlk İterasyon Checklist

## Tamamlanan

- [x] Tüm görünür ürün ve mimari Markdown dokümanları okundu.
- [x] Implementation audit, gap analizi, varsayımlar ve blokajlar yazıldı.
- [x] iOS 17+ Xcode uygulama hedefi ve Swift 6 package modülleri oluşturuldu.
- [x] CoreDomain modelleri, typed ID'ler, typed error ve probability invariant'ları eklendi.
- [x] Fixture/Analysis repository ve use case protokolleri oluşturuldu.
- [x] Fixture list/detail ve analysis loading/state/result UI iskeleti eklendi.
- [x] Constructor injection tabanlı `AppCompositionRoot` oluşturuldu.
- [x] In-memory fixture/analysis/config/locale implementasyonları eklendi.
- [x] TR/EN/ES/FR String Catalog temeli oluşturuldu.
- [x] Firebase adapter sınır protokolleri oluşturuldu.
- [x] Cloud Functions TypeScript iskeleti, request guard ve state machine eklendi.
- [x] AnalysisInputSnapshot ve AnalysisResult JSON Schema eklendi.
- [x] Firestore rules ve indexes taslağı eklendi.
- [x] Remote Config typed defaults/schema ve backend validator eklendi.
- [x] Swift unit testleri çalıştırıldı: 7/7 geçti.
- [x] TypeScript strict build ve backend unit testleri çalıştırıldı: 6/6 geçti (bundled Node 24).
- [x] iOS Simulator build çalıştırıldı: başarılı.
- [x] JSON artifact'ların sözdizimi doğrulandı.
- [x] Deterministic AnalysisResult validator eklendi: schema, tuple, yüzde toplamı, scoreline, evidence, temporal ve prohibited-claim kontrolleri.
- [x] Transaction referans modeli eklendi: deterministic request/reservation ID, immutable commit ledger, lease epoch, recovery ve late-worker koruması.
- [x] 100 eşzamanlı isteğin tek work request/lease'e birleştiği contract testi eklendi.
- [x] Provider bağımsız model gateway, server allowlist resolver ve Secret Manager binding sınırı eklendi.
- [x] Snapshot freshness normalizasyonu ve yalnızca available section'ların prompt projection'ı eklendi.
- [x] iOS generation eligibility policy eklendi: config, competition, status, kickoff, connectivity, snapshot freshness ve quota.
- [x] Locale-aware, TTL kontrollü ve file-protected analysis disk cache eklendi.
- [x] Offline yeni generation reddi ve geçerli cached analysis read-only erişimi repository seviyesinde uygulandı.
- [x] Güncel test sonucu: Swift 13/13, TypeScript 24/24; iOS Simulator build başarılı.
- [x] Bundle ID `com.footballai.predictions.com` olarak ayarlandı.
- [x] Free aylık unique analysis hakkı 1 olarak ayarlandı.
- [x] Development provider kararları kaydedildi: Gemini 3.5 Flash, football-data.org API v4 Free ve RevenueCat.
- [x] football-data.org server-only HTTP adapter'ı eklendi: `X-Auth-Token`, timeout, sınırlı transient retry ve response-header tabanlı throttling.
- [x] Firebase Apple SDK 12.14.0 eklendi ve project alias `footballai-40789` olarak bağlandı.
- [x] `GoogleService-Info.plist` bundle ID doğrulandı, iOS target resource'una eklendi ve Firebase/App Check bootstrap uygulandı.
- [x] Firestore `eur3` için Cloud Functions ve iOS callable region `europe-west1` olarak yapılandırıldı.
- [x] Firebase anonymous-auth ve callable transport live adapter'ları eklendi.
- [x] Firebase Console ürünleri, billing/runtime, App Check ve Secret Manager hazırlığı kullanıcı tarafından tamamlandı.
- [x] Canlı composition root; Anonymous Auth, server-side user/quota bootstrap, Firestore fixture/analysis read adapterları, Functions transport ve Remote Config bağlandı.
- [x] Gemini canlı gateway ve RevenueCat, Apple Developer hesabı açılana kadar bilinçli olarak ertelendi; ücretsiz temel akıştan ayrıştırıldı.

## Kalan

- [ ] Firebase SDK bootstrap tamamlandı; Auth/Firestore/Functions/Remote Config live repository composition wiring kaldı.
- [ ] Transaction referans modelini gerçek Firestore transaction adapter'ına bağla ve Rules/Functions emulator testlerini çalıştır.
- [ ] football-data.org response'larını domain fixture/snapshot modellerine normalize et ve section-specific complete snapshot data şemalarını ekle.
- [ ] Onaylanan AI provider için HTTP gateway implementasyonu, timeout/retry ve Secret Manager IAM/deployment yapılandırmasını tamamla.
- [ ] History, subscription, settings, account lifecycle ve feedback features.
- [ ] Fixture disk cache ve cache size/eviction politikasını ekle; analysis read-only cache tamamlandı.
- [ ] Backend build/testi production ile aynı Node 22 runtime'ında ve Firebase Emulator içinde tekrarla.
- [ ] CI, lint/format, secret/dependency scan ve snapshot/accessibility testleri.
- [ ] Ürün, provider ve legal onayları; Gemini/RevenueCat production kurulumu Apple Developer hesabından sonra tamamlanacak.
