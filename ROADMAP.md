# Roadmap

## Phase 1 — Product specification (tamamlandı)

- [x] Ürün sınırı ve olasılık-temelli değer önerisi
- [x] Yapılandırılmış veri snapshot'ı ve AI output sözleşmesi
- [x] Premium lig, kota, notification ve persona çelişkilerinin çözümü
- [x] TTL/versioning, history retention ve state machine kararları
- [x] TR/EN/ES/FR yerelleştirme kapsamı
- [x] Remote Config ve secrets sorumluluk ayrımı
- [x] Trust/legal/analytics gereksinimleri

## Phase 2 — Architecture & contracts (bu pakette tamamlandı)

- [x] Clean Architecture + MVVM ve DI sınırları
- [x] Feature/core modülleri ve klasör yapısı
- [x] Repository/use-case protokolleri
- [x] Firestore koleksiyonları ve erişim sahipliği
- [x] Remote Config ve localization servisleri
- [x] Secret rotation runbook
- [x] Analysis state machine, idempotency ve single-flight
- [x] Cache/versioning ve hata modeli
- [x] Test stratejisi ve faz çıkış checklist'i

Phase 2 kabul kriterleri: [architecture/10_PHASE2_CHECKLIST.md](architecture/10_PHASE2_CHECKLIST.md)

## Phase 3 — Implementation

1. [x] Xcode uygulama hedefi ve Swift Package modüllerini oluştur. CI kaldı.
2. [ ] Firebase dev/staging/prod projelerini ayır; Auth, Firestore, Functions, App Check ve Remote Config kur.
3. [ ] Fixture ingestion ve normalize edilmiş snapshot pipeline'ını uygula.
4. [ ] Analysis orchestration Function'ını schema doğrulama, idempotency, ledger ve retry ile uygula. İlk güvenli sınır/state-machine iskeleti tamamlandı.
5. [ ] iOS browse/detail/analysis/history/paywall/settings akışlarını geliştir. Browse/detail/analysis mock iskeleti tamamlandı.
6. StoreKit/RevenueCat entitlement webhook senkronizasyonunu kur.
7. Localization QA, accessibility, offline ve failure-path testlerini tamamla.
8. Security rules/emulator, load/cost, observability ve App Store hazırlığını bitir.

## Sonraki kapsam (Phase 3 sonrası)

- Bildirimler (özellik ve izin akışları ayrıca tasarlanacak)
- Favori takım/lig, arama ve gelişmiş filtreler
- Daha fazla lig: yalnızca sağlayıcı lisansı, veri kapsamı ve Remote Config allowlist'i onaylandığında
- Analiz karşılaştırma ve kalibrasyon raporları
- Deep links ve paylaşım
