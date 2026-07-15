# Phase 1 — Requirements

## Functional requirements

### Fixtures and input data

- FR-01 Backend, sağlayıcı verisini normalize ederek immutable `AnalysisInputSnapshot` üretmelidir.
- FR-02 Snapshot; fixture, teams, recent form, head-to-head, standings, squad availability, expected/confirmed lineups ve weather alanlarını `available | unavailable | stale` durumu ve `observedAt` ile taşımalıdır.
- FR-03 Model çağrısına yalnızca snapshot içindeki mevcut alanlar gönderilmelidir; unavailable alanlar için iddia üretilmemelidir.
- FR-04 `scheduled/timed/postponed` maçlar listelenebilir; sadece veri freshness eşiğini geçen ve başlamamış maçlar analiz edilebilir. `suspended/cancelled/in_progress/finished/awarded` yeni analiz kabul etmez.

### Analysis

- FR-05 Çıktı 1X2, O/U 2.5, BTTS ve top scorelines olasılıklarını tam sayı yüzde olarak sağlamalıdır.
- FR-06 1X2, O/U ve BTTS marketlerinin her biri 100 toplamına sahip olmalıdır.
- FR-07 Top scorelines toplamının 100 olması gerekmez; kalan yüzde `otherScoresPct` olmalıdır ve birlikte 100 etmelidir.
- FR-08 Gerekçe, kullanılan snapshot alanlarına `evidenceRefs` ile bağlanmalıdır.
- FR-09 UI “garanti/kesin/kazanır” dili kullanmamalı; generated time, data snapshot time, confidence ve limitations göstermelidir.
- FR-10 Invalid JSON, schema uyuşmazlığı, unsupported claim veya yüzde hatasında sonuç `ready` yapılmamalıdır.

### Plans, history and entitlement

- FR-11 Free kullanıcı ayda 1 analysis view hakkına sahiptir; Remote Config bunu güvenli sınırlar içinde değiştirebilir.
- FR-12 Bir analysis'i ilk kez açmak kullanıcı hakkını 1 azaltır; aynı analysis version'ını tekrar açmak aynı kullanıcı için yeniden tüketmez. Cache hit/miss bunu değiştirmez.
- FR-13 Premium kullanıcı için normal kullanımda analysis view sınırsızdır; backend abuse rate limit'i her planda geçerlidir.
- FR-14 Free history 30 gün, Premium history abonelik sürerken ve sonrasında en fazla 365 gün görünürdür. Hesap silme, kullanıcı-history bağlantısını 30 gün içinde siler; ortak anonim analysis cache ürün retention politikasına göre tutulabilir.
- FR-15 Entitlement'ın authoritative kaynağı RevenueCat webhook/backend kaydıdır; cihaz cache'i yalnızca geçici UX içindir.

### Localization and configuration

- FR-16 `tr`, `en`, `es`, `fr` desteklenmeli; fallback sırası requested locale → English olmalıdır.
- FR-17 Sayısal analysis aynı analysis version için locale'den bağımsız olmalıdır; localized rationale ayrı artifact olabilir.
- FR-18 Feature flags, supported leagues, plan limits, TTL, localized text variant IDs ve prompt/model/schema version Remote Config'ten okunabilir.
- FR-19 Remote Config değerleri typed defaults, allowlist, min/max clamp ve last-known-good ile doğrulanmalıdır.
- FR-20 API anahtarı, token, webhook secret veya private endpoint credential Remote Config/Firestore/bundle içinde tutulmamalıdır.

## Non-functional requirements

- NFR-01 Analysis request idempotent ve single-flight olmalıdır.
- NFR-02 p95 cached read < 1 s; cache miss async kabul < 2 s; AI tamamlanma hedefi p95 < 30 s.
- NFR-03 App Check, auth, per-user/device/IP rate limit ve server-side authorization uygulanmalıdır.
- NFR-04 Audit: state transition, usage ledger, model invocation metadata ve secret rotation kayıtları izlenebilir olmalıdır; promptta kişisel veri bulunmamalıdır.
- NFR-05 VoiceOver, Dynamic Type, color-independent probability presentation ve locale formatları desteklenmelidir.
- NFR-06 Offline durumda son indirilen fixture/ready analysis read-only gösterilir; yeni generation kuyruğa alınmaz.

## Acceptance summary

- Model inputta olmayan sakatlık, form, H2H veya hava iddiası oluşturamaz.
- Sayısal olasılıklar locale değişince değişmez.
- İki eşzamanlı istek tek model invocation üretir.
- Başarısız generation kullanıcı kotasını kalıcı tüketmez.
- Remote Config/Firestore istemciden secret açığa çıkarmaz.
