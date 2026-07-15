# FootballAI — Kalan İşler ve Devam Notu

Son güncelleme: 16 Temmuz 2026

Bu belge, projeye daha sonra devam ederken yapılacak işlemleri ve güvenlik sınırlarını özetler. Gerçek API anahtarları veya webhook doğrulama değerleri bu dosyaya yazılmamalıdır.

## Mevcut durum

- Firebase Auth anonim kullanıcı, Firestore profil/cüzdan/favori/geçmiş ve App Check akışları hazır.
- Kullanıcıya ilk kurulumda 1 ücretsiz kredi veren kalıcı Firestore cüzdanı hazır.
- Analiz maliyeti `analysis_credit_cost` ile Firebase Remote Config üzerinden yönetiliyor; başlangıç değeri 1.
- Maç analizi aynı maç için daha önce hazırlandıysa tekrar üretilmiyor ve geçmişte açılmış aynı maçtan tekrar kredi kesilmiyor.
- football-data.org erişimi Cloud Functions ve Secret Manager üzerinden yapılıyor.
- Gizli servis anahtarları `versions/latest` ve kısa önbellek ile okunuyor; yeni Secret Manager sürümü deploy gerektirmeden devreye girebiliyor.
- RevenueCat iOS SDK ve test istemci anahtarı Remote Config üzerinden yapılandırıldı.
- Firebase anonim UID, RevenueCat `appUserID` olarak kullanılıyor.
- Profilde tek seferlik consumable kredi paketlerini RevenueCat Offering üzerinden listeleyen ve satın alan kredi mağazası hazır.
- Abonelik modeli bulunmuyor.
- iOS build, Swift testleri ve backend testleri başarılı.

## 1. RevenueCat panel kurulumu

RevenueCat panelinde aşağıdakiler tamamlanmalı:

1. `CRD` kodlu `Credits` Virtual Currency oluştur.
2. Test Store üzerinde consumable kredi ürünlerini oluştur. Önerilen ürünler:
   - 5 kredi
   - 15 kredi
   - 40 kredi
3. Her ürünü vereceği `CRD` miktarıyla ilişkilendir.
4. Ürünleri aktif Offering içine package olarak ekle.
5. Uygulamayı açıp Profil → Kredi Satın Al ekranında paket ve lokal fiyatların geldiğini doğrula.

App Store Connect açıldığında aynı ürünler Consumable In-App Purchase olarak oluşturulmalı ve RevenueCat ürün kataloğuna bağlanmalıdır. Uygulamanın bundle identifier değeri `com.footballai.predictions.com` olmalıdır.

## 2. RevenueCat webhook ve Firebase kredi eşitleme

Bu bölüm henüz tamamlanmadı. İstemcinin Firestore bakiyesine doğrudan yazmasına kesinlikle izin verilmemelidir.

Yapılacaklar:

1. Güçlü ve rastgele bir webhook authorization değeri oluştur.
2. Değeri Google Secret Manager'a `REVENUECAT_WEBHOOK_AUTH` adıyla kaydet.
3. Firebase Functions içinde `revenueCatWebhook` HTTP fonksiyonunu oluştur.
4. Fonksiyon yalnızca doğru Authorization header taşıyan istekleri kabul etmeli.
5. Yalnızca `VIRTUAL_CURRENCY_TRANSACTION` olaylarını işlemeli.
6. `event.id` ile idempotency kaydı tutmalı; aynı olay ikinci kez kredi değiştirmemeli.
7. `app_user_id` değerini Firebase UID olarak kullanmalı.
8. Pozitif ve negatif `CRD` düzeltmelerini Firestore wallet transaction ile uygulamalı; bakiye negatife inmemeli.
9. `lifetimePurchased` ve iade/adjustment audit alanlarını güncellemeli.
10. Fonksiyonu deploy et ve Sandbox event ile test et.

Deploy sonrasında beklenen URL:

```text
https://europe-west1-footballai-40789.cloudfunctions.net/revenueCatWebhook
```

RevenueCat Dashboard → Integrations → Webhooks alanında:

- URL: Yukarıdaki aktif Firebase Functions URL'si
- Authorization header: Secret Manager'a kaydedilen değer
- Environment: Önce Sandbox, üretim öncesinde Production da etkinleştirilecek
- Event: `VIRTUAL_CURRENCY_TRANSACTION`

Not: RevenueCat webhook özelliği seçili plana göre ücretli plan gerektirebilir.

## 3. Uçtan uca kredi satın alma testi

Webhook tamamlandıktan sonra şu senaryo doğrulanmalı:

1. Yeni anonim kullanıcı oluşturulur ve Firestore bakiyesi 1 görülür.
2. RevenueCat test paketinden kredi satın alınır.
3. RevenueCat satın alımı doğrular.
4. Webhook yalnızca bir kez işlenir.
5. Firestore `users/{uid}/private/wallet` bakiyesi doğru miktarda artar.
6. Uygulama yeniden açıldığında güncel bakiye görünür.
7. Aynı webhook tekrar gönderildiğinde bakiye ikinci kez artmaz.
8. İade/negatif adjustment senaryosu güvenli biçimde işlenir.

## 4. Gemini analiz entegrasyonu

Apple/ürün işlemlerinden bağımsız olarak daha sonra tamamlanacak:

1. Uygun Gemini modelini ve maliyet limitlerini belirle.
2. Gemini API anahtarını Secret Manager'a kaydet; Remote Config'e veya iOS uygulamasına koyma.
3. Model alias, özellik bayrağı ve analiz maliyeti gibi gizli olmayan değerleri Remote Config'te tut.
4. Analiz üretim fonksiyonunu şema doğrulaması, timeout, retry, rate limit ve güvenli hata mesajlarıyla bağla.
5. Hazır analiz reuse/dedup kontrolünü koru.
6. Kredi kesimini analiz üretimi başlamadan önce transaction ile rezerve et; kalıcı hatada iade et.
7. Başarılı sonucu Firestore analyses/history koleksiyonlarına yaz ve UI'da göster.
8. Sandbox/test kullanıcılarıyla maliyet ve concurrency testlerini çalıştır.

## 5. Yayın öncesi işler

- Apple Developer hesabı ve doğru Development Team'i Xcode projesine tanımla.
- App Store Connect uygulamasını ve consumable ürünlerini oluştur.
- RevenueCat test anahtarını üretim public iOS SDK anahtarıyla Remote Config üzerinden değiştir.
- RevenueCat webhook'u Production eventleri için etkinleştir.
- Privacy Policy, Terms ve App Store Privacy Nutrition Labels alanlarını son servis kullanımına göre tekrar gözden geçir.
- Gerçek cihazda App Check, anonymous auth, satın alma, kredi eşitleme, analiz ve hesap silme akışlarını test et.
- Firebase bütçe uyarıları, Cloud Logging alarmı ve RevenueCat webhook hata takibi oluştur.
- Release build, archive ve TestFlight testi yap.

## Güvenlik kuralları

- Gemini, football-data.org ve RevenueCat secret/developer API anahtarları Remote Config'e yazılmaz.
- Remote Config yalnızca istemciden görülmesinde sakınca olmayan değerler içindir.
- RevenueCat public iOS SDK anahtarı gizli değildir ancak hızlı değiştirme için Remote Config'te tutulur.
- Firestore kredi bakiyesi yalnızca güvenilir backend transaction'larıyla değişir.
- Webhook olayları authorization ve idempotency kontrolü olmadan işlenmez.
- Secret değerleri kaynak koda, Markdown dosyalarına, Git geçmişine veya uygulama loglarına yazılmaz.
