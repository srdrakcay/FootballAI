# Phase 1 — Product Scope

## Amaç

Kullanıcıya yaklaşan futbol maçları için, sağlanan güncel ve yapılandırılmış veriye dayalı, açıklanabilir olasılık analizi sunmak. Ürün bahis kuponu, kazanç vaadi veya kesin sonuç servisi değildir.

## V1 kapsamı

- iOS 17+ SwiftUI uygulaması.
- Anonymous Auth; Apple ile bağlama/geri yükleme.
- Yaklaşan maçları lig ve tarihe göre listeleme.
- Maç detayındaki doğrulanmış veri snapshot'ını görüntüleme.
- 1X2, alt/üst, karşılıklı gol ve en olası skor dağılımları.
- Her market için veri dayanakları, confidence ve limitations.
- Ortak, versiyonlu analysis cache.
- Free/Premium entitlement, kullanım ledger'ı ve history.
- TR, EN, ES, FR.
- Firebase Auth, Firestore, Cloud Functions, App Check, Remote Config; RevenueCat/StoreKit.

## Lig kararı

V1 çekirdek ligleri: Premier League, La Liga, Serie A, Bundesliga, Ligue 1 ve UEFA Champions League. Bunlar hem Free hem Premium için listelenebilir. Premium farkı ek lig değil; daha yüksek/sınırsız adil kullanım limiti ve uzun history'dir. Ek ligler gelecekte `supported_leagues_v1` allowlist'i ve `feature_extended_leagues_enabled` ile açılır; provider coverage/lisans kontrolü olmadan yayınlanmaz.

## V1 dışı

- Push notification ve notification preferences.
- Canlı maç/in-play tahmini.
- Bahis oranı karşılaştırma, bookmaker yönlendirmesi veya kupon.
- Kullanıcının serbest metinle doğrulanmamış veri eklemesi.
- AI'ın internetten veri toplaması veya eksik alanları varsayması.
- Sosyal akış, yorum ve paylaşım.

## Ürün ilkeleri

- **Evidence bounded:** Model yalnızca input snapshot'taki alanları kullanır.
- **Probabilistic:** Sonuçlar olasılıktır; kesin dil yasaktır.
- **Traceable:** Her çıktı fixture/snapshot/schema/prompt/model sürümüne bağlıdır.
- **Localized:** UI metni uygulamada; dinamik AI metni istenen locale'de ve aynı sayısal sonuçlarla üretilir.
- **Secure by default:** Secret istemcide ve Remote Config'te bulunmaz.
- **Fail closed:** Eksik/kadük veri veya geçersiz model çıktısında analiz yayınlanmaz.
