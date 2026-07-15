# Integration Setup Decisions

Tarih: 2026-07-15

## Onaylanan ürün kararları

- iOS bundle ID: `com.footballai.predictions.com`
- Free quota: ayda 1 benzersiz analysis version
- Subscription: RevenueCat
- AI development model: server alias `gemini-flash-default` → `gemini-3.5-flash`
- Football development provider: `football-data.org API v4` Free

Model ve provider seçimi server registry'dedir. iOS istemcisi gerçek model adını, endpoint'i, API key'i veya provider seçimini gönderemez.

## Firebase'den gerekenler

1. [Tamamlandı] Firebase Console'da bundle ID ile Apple app kaydı: `com.footballai.predictions.com`.
2. [Tamamlandı] `GoogleService-Info.plist` iOS target'a bağlandı ve bundle ID doğrulandı.
3. [Tamamlandı] Firebase project ID `footballai-40789`, Firestore location `eur3`; en yakın Cloud Functions region `europe-west1` olarak sabitlendi.
4. [Kullanıcı tarafından tamamlandı] Authentication altında Anonymous provider açıldı. Apple Sign-In, Apple Developer hesabı/capability kurulunca açılacaktır.
5. [Kullanıcı tarafından tamamlandı] Firestore, Functions, Remote Config ve App Check etkinleştirildi. Simulator geliştirmesinde App Check debug token; production'da App Attest kullanılacaktır.
6. [Kullanıcı tarafından tamamlandı] Cloud Functions dış ağ ve Secret Manager için gerekli Firebase billing/runtime ayarları hazırlandı.

Service-account JSON, Firebase login cookie veya özel anahtar paylaşılmamalıdır. Deployment, yerel `firebase login` ya da CI workload identity ile yapılmalıdır.

## Secret Manager'a kullanıcı tarafından girilecek değerler

Değerler sohbete veya source code'a yapıştırılmamalı; terminalde interaktif olarak girilmelidir:

```bash
firebase functions:secrets:set AI_PROVIDER_API_KEY
firebase functions:secrets:set FOOTBALL_DATA_API_TOKEN
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
```

Bir token sohbet, issue veya log içinde açıklandıysa önce football-data.org panelinden yenilenmeli; yalnızca yeni token interaktif komutla Secret Manager'a girilmelidir.

## Anonim kullanıcı ve quota kimliği

- Uygulama başlangıcında Firebase Anonymous Auth oturumu açılır ve `bootstrapUser` callable'ı `users/{uid}` ile `users/{uid}/private/quota` belgelerini server tarafında oluşturur.
- Free aylık limit 1'dir. İstemci quota alanlarını yazamaz; `used/remaining` yalnızca başarılı ve benzersiz analysis version tesliminde backend transaction/ledger ile güncellenir. Başarısız veya ertelenmiş Gemini isteği hak düşürmez.
- iOS Firebase Auth oturumu normal uygulama yeniden kurulumlarında aynı yerel credential mevcutsa aynı UID ile devam eder. Cihaz/Keychain temizliği veya anonim hesap silinmesi sonrasında güvenli hesap kurtarma garanti edilemez. Apple Developer hesabı açıldığında anonim kullanıcı Sign in with Apple credential'ına **link** edilerek kalıcı hale getirilecektir.

- `AI_PROVIDER_API_KEY`: Google AI Studio'da Firebase/Google Cloud projesi için oluşturulan Gemini API key.
- `FOOTBALL_DATA_API_TOKEN`: football-data.org hesap tokenı. İsteklerde yalnızca server tarafından `X-Auth-Token` başlığına yazılır.
- `REVENUECAT_SECRET_API_KEY`: Yalnızca backend REST entitlement doğrulaması gerekiyorsa RevenueCat secret key.
- `REVENUECAT_WEBHOOK_AUTH`: RevenueCat webhook Authorization header için rastgele güçlü secret. Webhook kullanılmıyorsa henüz gerekmez.

## RevenueCat'ten gerekenler

Durum: Apple Developer hesabı açılana kadar bilinçli olarak ertelendi; ücretsiz temel akışı bloke etmez.

- RevenueCat Apple app bundle ID: `com.footballai.predictions.com`
- App-specific public iOS SDK key
- Entitlement identifier; önerilen: `premium`
- Current Offering identifier; önerilen: `default`
- App Store Connect subscription product ID'leri; önerilen başlangıç: `footballai_premium_monthly`, `footballai_premium_yearly`
- RevenueCat plan bilgisi. Webhook özelliği mevcut planda yoksa backend entitlement doğrulaması RevenueCat REST API üzerinden yapılır.

Public iOS SDK key uygulama binary'sinde bulunmak üzere tasarlanmıştır; RevenueCat secret API key ve webhook authorization değeri yalnızca Secret Manager'da kalır.

## Free-tier sınırları

- Gemini canlı gateway ve anahtarı Apple hesabı açılana kadar ürün sahibi kararıyla ertelenmiştir. Bu sürede analiz callable'ı fail-closed kalır; sahte AI sonucu üretilmez.
- Gemini free tier geliştirme ve düşük hacimli test içindir. Rate limit ve veri kullanım koşulları production öncesi tekrar değerlendirilmelidir.
- football-data.org Free kapsamı ve hız limiti production öncesi hesabın güncel planıyla yeniden doğrulanmalıdır. Adapter `X-Requests-Available-Minute`, `X-RequestCounter-Reset` ve `Retry-After` başlıklarını okuyarak otomatik bekleme uygular.
- FootballAI yalnızca sağlayıcının izin verdiği match, standings ve benzeri doğrulanabilir girdileri normalize eder; free planda bulunmayan veri bölümleri uydurulmaz ve `unavailable` kalır.
