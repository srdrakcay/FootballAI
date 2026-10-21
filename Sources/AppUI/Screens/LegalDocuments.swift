#if os(iOS)
import CoreDomain
import SwiftUI

// Legal copy moved unchanged from the previous app shell (TR/EN/DE/FR/ES).

struct LegalSection: Identifiable {
    let id: String
    let title: String
    let paragraphs: [String]
}

enum LegalDocument {
    case privacy, terms

    var title: Text {
        switch self {
        case .privacy: Text("legal.privacy", bundle: .module)
        case .terms: Text("legal.terms", bundle: .module)
        }
    }

    var effectiveDate: String {
        switch SupportedLocale.app.rawValue {
        case "tr": "Yürürlük tarihi: 16 Temmuz 2026"
        case "de": "Gültig ab: 16. Juli 2026"
        case "fr": "Date d’entrée en vigueur : 16 juillet 2026"
        case "es": "Fecha de entrada en vigor: 16 de julio de 2026"
        default: "Effective date: July 16, 2026"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .privacy: privacySections
        case .terms: termsSections
        }
    }

    private var privacySections: [LegalSection] {
        let language = SupportedLocale.app.rawValue
        if language == "tr" {
            return [
                .init(id: "scope", title: "1. Kapsam ve veri sorumlusu", paragraphs: ["Bu politika, com.footballai.predictions.com paket kimliğine sahip NinetyLens iOS uygulamasını kapsar. Geliştirici ve veri sorumlusu Serdar Akçay’dır. Gizlilik ve destek talepleri srdrakcay25@gmail.com adresine iletilebilir."]),
                .init(id: "data", title: "2. İşlediğimiz veriler", paragraphs: ["Uygulama; Firebase tarafından oluşturulan anonim kullanıcı kimliğini, sistem dilini, hesap oluşturma ve son görülme zamanlarını, kredi bakiyesi ve kullanım kayıtlarını, favori maçları, analiz geçmişini ve Apple üzerinden doğrulanan ürün/işlem kayıtlarını işler.", "Firebase ve altyapı sağlayıcıları güvenlik amacıyla IP adresi, uygulama kurulumu veya cihaz bütünlüğü sinyalleri ile teknik günlükleri işleyebilir. Kart numarası veya Apple ödeme bilgileri NinetyLens’e ulaşmaz. Uygulama kesin konuma, kişilere, fotoğraflara, mikrofona veya reklam kimliğine erişmez."]),
                .init(id: "purpose", title: "3. Kullanım amaçları", paragraphs: ["Veriler; anonim oturumu sürdürmek, favorileri ve geçmişi göstermek, kredi satın alımlarını doğrulamak, kredi kullanımını uygulamak, mükerrer analiz ve işlemleri önlemek, fikstürleri sunmak, dolandırıcılık ve kötüye kullanımı azaltmak ve hizmet güvenliğini sağlamak için işlenir. Veriler reklam, profil oluşturma veya üçüncü taraflar arası takip amacıyla kullanılmaz."]),
                .init(id: "providers", title: "4. Hizmet sağlayıcılar", paragraphs: ["Firebase/Google Cloud kimlik doğrulama, veritabanı, sunucu fonksiyonları, uzaktan yapılandırma ve App Check hizmetlerini sağlar. RevenueCat anonim hesap kimliği, ürün kimliği ve işlem durumunu kredi satın alımlarını doğrulamak için işler. Apple ödemeyi işler.", "football-data.org yalnızca sunucu tarafından istenen maç verilerini sağlar ve kullanıcı kimliğini almaz. Google Gemini’ye yalnızca maç ve takım bağlamı ile analiz tercihlerin (favori takım, analiz tarzı ve ilgi alanları) gönderilir; anonim kullanıcı kimliği, satın alma bilgisi veya cihaz verisi gönderilmez."]),
                .init(id: "retention", title: "5. Saklama ve silme", paragraphs: ["Hesaba bağlı profil, kredi, favori ve geçmiş verileri hesap silinene kadar saklanır. Profil > Hesabı sil işlemi anonim Firebase hesabını ve kullanıcıyla bağlantılı verileri siler. Kullanıcı kimliği içermeyen ortak maç analizleri; yeniden üretimi önlemek, hizmet bütünlüğü ve maliyet kontrolü için saklanabilir.", "Çıkış yapmak sunucudaki hesabı silmez, yalnızca cihazdaki oturumu kaldırır. Apple, Google ve RevenueCat güvenlik, işlem ve mevzuat kayıtlarını kendi politikaları kapsamında daha uzun süre saklayabilir."]),
                .init(id: "security", title: "6. Güvenlik ve uluslararası aktarım", paragraphs: ["Veriler aktarım sırasında şifrelenir ve Firebase güvenlik kuralları, App Check ve kimlik doğrulama ile korunur. Google Cloud hizmetlerinin çalışması nedeniyle veriler kullanıcının ülkesi dışındaki altyapılarda işlenebilir. Hiçbir teknik yöntem mutlak güvenlik garantisi vermez."]),
                .init(id: "rights", title: "7. Seçimleriniz ve haklarınız", paragraphs: ["Favorileri kaldırabilir, çıkış yapabilir veya hesabınızı ve ilişkili verileri uygulama içinden kalıcı olarak silebilirsiniz. Erişim, düzeltme, silme, kısıtlama veya itiraz talepleri için srdrakcay25@gmail.com adresine yazabilirsiniz. Satın alma iadeleri Apple’ın iade süreci üzerinden yönetilir."]),
                .init(id: "children", title: "8. Çocuklar ve değişiklikler", paragraphs: ["NinetyLens özellikle çocuklara yönelik değildir ve bilerek ad, e-posta veya doğum tarihi toplamaz. Bu politika veri uygulamalarımız değiştiğinde güncellenebilir; önemli değişiklikler yeni yürürlük tarihiyle uygulamada yayımlanır."])
            ]
        }
        if language == "de" {
            return [
                .init(id: "scope", title: "1. Geltungsbereich und Verantwortlicher", paragraphs: ["Diese Erklärung gilt für die NinetyLens iOS-App mit der Bundle-ID com.footballai.predictions.com. Verantwortlicher Entwickler ist Serdar Akçay. Datenschutz- und Supportanfragen können an srdrakcay25@gmail.com gesendet werden."]),
                .init(id: "data", title: "2. Verarbeitete Daten", paragraphs: ["Die App verarbeitet eine von Firebase erzeugte anonyme Benutzer-ID, Systemsprache, Kontozeiten, Credit-Guthaben und -Nutzung, Favoriten, Analyseverlauf sowie von Apple bestätigte Produkt- und Transaktionsdaten.", "Firebase und Infrastrukturpartner können IP-Adresse, Installations- oder Geräteintegritätssignale und technische Protokolle zur Sicherheit verarbeiten. NinetyLens erhält keine Karten- oder Apple-Zahlungsdaten und greift nicht auf Standort, Kontakte, Fotos, Mikrofon oder Werbe-ID zu."]),
                .init(id: "purpose", title: "3. Zwecke", paragraphs: ["Die Daten werden für Sitzung, Favoriten, Verlauf, Kaufprüfung, Credit-Verwendung, Vermeidung doppelter Analysen, Spielpläne, Betrugsprävention und Sicherheit genutzt. Sie werden nicht für Werbung, Profiling oder Tracking über Dienste hinweg verwendet."]),
                .init(id: "providers", title: "4. Dienstleister", paragraphs: ["Firebase/Google Cloud stellt Authentifizierung, Datenbank, Serverfunktionen, Remote Config und App Check bereit. RevenueCat verarbeitet anonyme Konto-, Produkt- und Transaktionsdaten zur Kaufprüfung; Apple verarbeitet die Zahlung.", "football-data.org liefert serverseitig Spieldaten. An Google Gemini werden nur Spiel- und Teamdaten sowie deine Analyse-Einstellungen (Lieblingsteam, Analysestil, Schwerpunkte) übertragen, keine anonyme Benutzer-ID, Kauf- oder Gerätedaten."]),
                .init(id: "retention", title: "5. Speicherung und Löschung", paragraphs: ["Kontobezogene Daten bleiben bis zur Kontolöschung gespeichert. Profil > Account löschen entfernt das anonyme Firebase-Konto und zugehörige Daten. Geteilte Analysen ohne Benutzer-ID können zur Vermeidung erneuter Generierung und für die Dienstintegrität gespeichert bleiben.", "Abmelden löscht nur die Sitzung auf dem Gerät. Apple, Google und RevenueCat können Sicherheits- und Transaktionsprotokolle nach ihren eigenen Richtlinien aufbewahren."]),
                .init(id: "security", title: "6. Sicherheit und Übermittlung", paragraphs: ["Daten werden bei der Übertragung verschlüsselt und durch Authentifizierung, Firebase Security Rules und App Check geschützt. Cloud-Anbieter können Daten außerhalb Ihres Landes verarbeiten. Absolute Sicherheit kann nicht garantiert werden."]),
                .init(id: "rights", title: "7. Ihre Rechte", paragraphs: ["Sie können Favoriten entfernen, sich abmelden oder Konto und verknüpfte Daten in der App löschen. Für Auskunft, Berichtigung, Löschung, Einschränkung oder Widerspruch schreiben Sie an srdrakcay25@gmail.com. Rückerstattungen werden über Apple abgewickelt."]),
                .init(id: "children", title: "8. Kinder und Änderungen", paragraphs: ["NinetyLens richtet sich nicht speziell an Kinder und erhebt wissentlich keine Namen, E-Mail-Adressen oder Geburtsdaten. Wesentliche Änderungen werden mit einem neuen Gültigkeitsdatum veröffentlicht."])
            ]
        }
        if language == "fr" {
            return [
                .init(id: "scope", title: "1. Champ d’application et responsable", paragraphs: ["Cette politique s’applique à l’app iOS NinetyLens, identifiant com.footballai.predictions.com. Le développeur responsable est Serdar Akçay. Les demandes peuvent être envoyées à srdrakcay25@gmail.com."]),
                .init(id: "data", title: "2. Données traitées", paragraphs: ["L’app traite un identifiant utilisateur anonyme Firebase, la langue système, les dates du compte, le solde et l’utilisation des crédits, les favoris, l’historique d’analyse ainsi que les données de produit et de transaction validées par Apple.", "Firebase et les fournisseurs d’infrastructure peuvent traiter l’adresse IP, des signaux d’installation ou d’intégrité de l’appareil et des journaux techniques à des fins de sécurité. NinetyLens ne reçoit aucune donnée de carte ou de paiement Apple et n’accède pas à la localisation, aux contacts, aux photos, au microphone ni à l’identifiant publicitaire."]),
                .init(id: "purpose", title: "3. Finalités", paragraphs: ["Les données servent à maintenir la session, afficher favoris et historique, valider les achats, appliquer les crédits, éviter les analyses dupliquées, fournir les calendriers, prévenir la fraude et sécuriser le service. Elles ne servent ni à la publicité, ni au profilage, ni au suivi interservices."]),
                .init(id: "providers", title: "4. Prestataires", paragraphs: ["Firebase/Google Cloud fournit l’authentification, la base de données, les fonctions serveur, Remote Config et App Check. RevenueCat traite l’identifiant anonyme, le produit et l’état de transaction pour valider les achats ; Apple traite le paiement.", "football-data.org fournit les données de match côté serveur. Seules les données de match et d’équipe ainsi que vos préférences d’analyse (équipe favorite, style d’analyse, marchés suivis) sont envoyées à Google Gemini, sans identifiant utilisateur, donnée d’achat ou donnée d’appareil."]),
                .init(id: "retention", title: "5. Conservation et suppression", paragraphs: ["Les données liées au compte sont conservées jusqu’à sa suppression. Profil > Supprimer le compte efface le compte Firebase anonyme et les données liées. Les analyses partagées sans identifiant utilisateur peuvent être conservées pour éviter une nouvelle génération et protéger l’intégrité du service.", "La déconnexion retire seulement la session de l’appareil. Apple, Google et RevenueCat peuvent conserver leurs journaux de sécurité et de transaction selon leurs propres politiques."]),
                .init(id: "security", title: "6. Sécurité et transferts", paragraphs: ["Les données sont chiffrées en transit et protégées par l’authentification, les règles Firebase et App Check. Les fournisseurs cloud peuvent traiter des données hors de votre pays. Aucune mesure ne garantit une sécurité absolue."]),
                .init(id: "rights", title: "7. Vos droits", paragraphs: ["Vous pouvez retirer des favoris, vous déconnecter ou supprimer votre compte et ses données dans l’app. Pour l’accès, la rectification, l’effacement, la limitation ou l’opposition, écrivez à srdrakcay25@gmail.com. Les remboursements sont gérés par Apple."]),
                .init(id: "children", title: "8. Enfants et modifications", paragraphs: ["NinetyLens ne cible pas spécifiquement les enfants et ne collecte pas sciemment leur nom, adresse e-mail ou date de naissance. Toute modification importante sera publiée avec une nouvelle date d’entrée en vigueur."])
            ]
        }
        if language == "es" {
            return [
                .init(id: "scope", title: "1. Alcance y responsable", paragraphs: ["Esta política se aplica a la app iOS NinetyLens con identificador com.footballai.predictions.com. El desarrollador responsable es Serdar Akçay. Las solicitudes pueden enviarse a srdrakcay25@gmail.com."]),
                .init(id: "data", title: "2. Datos tratados", paragraphs: ["La app trata un identificador anónimo de Firebase, idioma del sistema, fechas de la cuenta, saldo y uso de créditos, favoritos, historial de análisis y datos de producto y transacción validados por Apple.", "Firebase y los proveedores de infraestructura pueden tratar la dirección IP, señales de instalación o integridad del dispositivo y registros técnicos por seguridad. NinetyLens no recibe datos de tarjeta o pago de Apple ni accede a ubicación, contactos, fotos, micrófono o identificador publicitario."]),
                .init(id: "purpose", title: "3. Finalidades", paragraphs: ["Los datos se usan para mantener la sesión, mostrar favoritos e historial, validar compras, aplicar créditos, evitar análisis duplicados, ofrecer calendarios, prevenir fraude y proteger el servicio. No se usan para publicidad, perfiles ni seguimiento entre servicios."]),
                .init(id: "providers", title: "4. Proveedores", paragraphs: ["Firebase/Google Cloud ofrece autenticación, base de datos, funciones de servidor, Remote Config y App Check. RevenueCat trata el identificador anónimo, producto y estado de transacción para validar compras; Apple procesa el pago.", "football-data.org proporciona datos de partidos desde el servidor. A Google Gemini solo se envían datos del partido y los equipos y tus preferencias de análisis (equipo favorito, estilo de análisis y mercados de interés), sin identificador de usuario, compras ni datos del dispositivo."]),
                .init(id: "retention", title: "5. Conservación y eliminación", paragraphs: ["Los datos vinculados a la cuenta se conservan hasta su eliminación. Perfil > Eliminar cuenta borra la cuenta anónima de Firebase y sus datos. Los análisis compartidos sin identificador pueden conservarse para evitar regeneraciones y proteger la integridad del servicio.", "Cerrar sesión solo elimina la sesión del dispositivo. Apple, Google y RevenueCat pueden conservar registros de seguridad y transacciones según sus políticas."]),
                .init(id: "security", title: "6. Seguridad y transferencias", paragraphs: ["Los datos se cifran en tránsito y se protegen con autenticación, reglas de Firebase y App Check. Los proveedores cloud pueden tratar datos fuera de tu país. Ninguna medida garantiza seguridad absoluta."]),
                .init(id: "rights", title: "7. Tus derechos", paragraphs: ["Puedes quitar favoritos, cerrar sesión o eliminar la cuenta y sus datos desde la app. Para acceso, rectificación, eliminación, limitación u oposición, escribe a srdrakcay25@gmail.com. Los reembolsos se gestionan mediante Apple."]),
                .init(id: "children", title: "8. Menores y cambios", paragraphs: ["NinetyLens no está dirigida específicamente a menores y no recopila conscientemente nombres, correos o fechas de nacimiento. Los cambios importantes se publicarán con una nueva fecha de entrada en vigor."])
            ]
        }
        return [
            .init(id: "scope", title: "1. Scope and controller", paragraphs: ["This policy applies to the NinetyLens iOS app with bundle identifier com.footballai.predictions.com. The responsible developer is Serdar Akçay. Privacy and support requests can be sent to srdrakcay25@gmail.com."]),
            .init(id: "data", title: "2. Data we process", paragraphs: ["The app processes a Firebase-generated anonymous user identifier, system language, account timestamps, credit balance and usage records, favorite matches, analysis history, and Apple-validated product and transaction records.", "Firebase and infrastructure providers may process IP address, app-installation or device-integrity signals, and technical logs for security. NinetyLens never receives card details or Apple payment credentials and does not access precise location, contacts, photos, microphone, or advertising identifiers."]),
            .init(id: "purpose", title: "3. Purposes", paragraphs: ["Data is used to maintain the anonymous session, display favorites and history, validate purchases, enforce credit usage, prevent duplicate analyses and transactions, provide fixtures, reduce fraud and abuse, and secure the service. It is not used for advertising, profiling, or cross-service tracking."]),
            .init(id: "providers", title: "4. Service providers", paragraphs: ["Firebase/Google Cloud provides authentication, database, server functions, Remote Config, and App Check. RevenueCat processes the anonymous account identifier, product identifier, and transaction status to validate credit purchases; Apple processes the payment.", "football-data.org supplies match data through server-side requests and does not receive the user identifier. Only match and team context and your analysis preferences (favorite team, analysis style, and focus markets) are sent to Google Gemini; the anonymous user identifier, purchase information, and device data are not sent to Gemini."]),
            .init(id: "retention", title: "5. Retention and deletion", paragraphs: ["Account-linked profile, credit, favorite, and history data is retained until account deletion. Profile > Delete Account removes the anonymous Firebase account and user-linked data. Shared match analyses containing no user identifier may be retained to prevent duplicate generation, control cost, and protect service integrity.", "Signing out removes only the session from the device. Apple, Google, and RevenueCat may retain security, transaction, and compliance records under their own policies."]),
            .init(id: "security", title: "6. Security and transfers", paragraphs: ["Data is encrypted in transit and protected with Firebase Security Rules, App Check, and authentication. Google Cloud may process data outside the user’s country. No technical measure can guarantee absolute security."]),
            .init(id: "rights", title: "7. Your choices and rights", paragraphs: ["You can remove favorites, sign out, or permanently delete your account and associated data in the app. For access, correction, deletion, restriction, or objection requests, email srdrakcay25@gmail.com. Purchase refunds are handled through Apple’s refund process."]),
            .init(id: "children", title: "8. Children and changes", paragraphs: ["NinetyLens is not specifically directed to children and does not knowingly collect names, email addresses, or birth dates. This policy may be updated as data practices change; material changes will be shown with a new effective date."])
        ]
    }

    private var termsSections: [LegalSection] {
        if SupportedLocale.app.rawValue == "tr" {
            return [
                .init(id: "acceptance", title: "1. Koşulların kabulü", paragraphs: ["NinetyLens’i kullanarak bu Kullanım Koşullarını kabul edersiniz. Kabul etmiyorsanız uygulamayı kullanmayın. Anonim hesabınızı dilediğiniz zaman profil ekranından silebilirsiniz."]),
                .init(id: "service", title: "2. Hizmetin kapsamı", paragraphs: ["NinetyLens maç fikstürlerini, favorileri, analiz geçmişini ve yapay zekâ destekli olasılık analizlerini sunar. Özellikler, lig kapsamı, kredi maliyeti ve ücretsiz haklar zaman içinde değişebilir."]),
                .init(id: "disclaimer", title: "3. Tahmin ve bahis uyarısı", paragraphs: ["Tüm analizler yalnızca bilgilendirme ve eğlence amaçlı olasılık tahminleridir. Kesin sonuç, finansal tavsiye veya bahis tavsiyesi değildir. Veriler eksik, gecikmeli ya da hatalı olabilir. Kararlarınızdan ve kayıplarınızdan siz sorumlusunuz."]),
                .init(id: "account", title: "4. Hesap ve ücretsiz kullanım", paragraphs: ["Uygulama varsayılan olarak anonim Firebase hesabı oluşturur. Hesabın ve cihazın güvenliğinden siz sorumlusunuz. Yeni hesaplara bir defaya mahsus 1 hoş geldin kredisi tanımlanır. Daha önce açtığın bir maç analizini yeniden açmak ek kredi gerektirmez."]),
                .init(id: "purchases", title: "5. Krediler ve satın almalar", paragraphs: ["Krediler Apple’ın uygulama içi satın alma sistemiyle sunulan tüketilebilir dijital ürünlerdir. Satın alınan kredilerin süresi dolmaz. Apple tarafından onaylanan bir iade, ilgili kullanılmamış kredilerin bakiyeden kaldırılmasına neden olabilir. Ödemeler ve iadeler Apple tarafından işlenir."]),
                .init(id: "acceptable", title: "6. Kabul edilebilir kullanım", paragraphs: ["Hizmeti tersine mühendislik, otomatik toplu istek, kota veya güvenlik mekanizmalarını aşma, API verilerini izinsiz yeniden dağıtma ya da hukuka aykırı amaçlarla kullanamazsınız. Kötüye kullanımda erişim sınırlandırılabilir."]),
                .init(id: "thirdparty", title: "7. Üçüncü taraf hizmetleri", paragraphs: ["Maç verileri football-data.org, altyapı Firebase/Google Cloud, yapay zekâ analizi Google Gemini ve tek seferlik kredi satın alma doğrulaması RevenueCat tarafından sağlanır. Bu hizmetlerdeki kesinti, gecikme veya veri değişiklikleri NinetyLens’in kontrolü dışında olabilir."]),
                .init(id: "ip", title: "8. Fikri mülkiyet", paragraphs: ["NinetyLens adı, tasarımı ve uygulama kodu ilgili hak sahiplerine aittir. Takım, lig ve sağlayıcı adları kendi sahiplerinin markaları olabilir. Uygulama size kişisel ve devredilemez sınırlı kullanım hakkı verir."]),
                .init(id: "availability", title: "9. Kullanılabilirlik ve sorumluluk", paragraphs: ["Hizmet olduğu gibi sunulur; kesintisiz, hatasız veya belirli bir sonuca uygun olacağı garanti edilmez. Zorunlu hukuk kuralları saklı kalmak üzere NinetyLens, uygulama kullanımından doğan dolaylı zarar veya kayıplardan sorumlu değildir."]),
                .init(id: "changes", title: "10. Değişiklikler ve sona erme", paragraphs: ["Hizmet veya bu koşullar güncellenebilir. Önemli değişiklikler yeni yürürlük tarihiyle uygulamada gösterilir. Koşulların ihlali halinde erişim durdurulabilir; kullanıcı hesabını silerek kullanımı her zaman sona erdirebilir. Uyuşmazlıklarda kullanıcının bulunduğu yerdeki zorunlu tüketici hakları korunur."])
            ]
        }
        if SupportedLocale.app.rawValue == "de" {
            return [
                .init(id: "acceptance", title: "1. Annahme und Dienst", paragraphs: ["Mit der Nutzung von NinetyLens akzeptieren Sie diese Bedingungen. Die App bietet Spielpläne, Favoriten, Verlauf und KI-gestützte Wahrscheinlichkeitsanalysen."]),
                .init(id: "disclaimer", title: "2. Analysehinweis", paragraphs: ["Analysen sind nur Information und Unterhaltung. Sie garantieren kein Ergebnis und sind keine Finanz- oder Wettberatung. Daten können verspätet, unvollständig oder falsch sein."]),
                .init(id: "purchases", title: "3. Credits und Käufe", paragraphs: ["Credits sind verbrauchbare digitale Güter, die über Apples In-App-Kaufsystem angeboten werden. Gekaufte Credits verfallen nicht. Eine von Apple bestätigte Rückerstattung kann die entsprechenden ungenutzten Credits entfernen."]),
                .init(id: "acceptable", title: "4. Zulässige Nutzung", paragraphs: ["Sicherheits-, Credit- oder Kontrollen dürfen nicht umgangen, automatisierte Massenanfragen nicht gesendet und API-Daten nicht unbefugt weitergegeben werden."]),
                .init(id: "account", title: "5. Konto und Löschung", paragraphs: ["Die App verwendet standardmäßig ein anonymes Firebase-Konto. Sie können das Konto und verknüpfte Daten jederzeit im Profil dauerhaft löschen."]),
                .init(id: "changes", title: "6. Verfügbarkeit und Rechte", paragraphs: ["Der Dienst wird ohne Garantie eines bestimmten Ergebnisses bereitgestellt. Änderungen werden mit einem neuen Gültigkeitsdatum angezeigt. Zwingende Verbraucherrechte an Ihrem Wohnort bleiben unberührt."])
            ]
        }
        if SupportedLocale.app.rawValue == "fr" {
            return [
                .init(id: "acceptance", title: "1. Acceptation et service", paragraphs: ["En utilisant NinetyLens, vous acceptez ces conditions. L’app fournit calendrier, favoris, historique et analyses probabilistes assistées par IA."]),
                .init(id: "disclaimer", title: "2. Avertissement", paragraphs: ["Les analyses sont fournies uniquement à titre informatif et de divertissement. Elles ne garantissent aucun résultat et ne constituent ni un conseil financier ni un conseil de pari."]),
                .init(id: "purchases", title: "3. Crédits et achats", paragraphs: ["Les crédits sont des biens numériques consommables proposés via les achats intégrés Apple. Les crédits achetés n’expirent pas. Un remboursement confirmé par Apple peut retirer les crédits non utilisés correspondants."]),
                .init(id: "acceptable", title: "4. Utilisation autorisée", paragraphs: ["Il est interdit de contourner les contrôles de sécurité ou de crédits, d’envoyer des requêtes automatisées en masse ou de redistribuer les données API sans autorisation."]),
                .init(id: "account", title: "5. Compte et suppression", paragraphs: ["L’app utilise par défaut un compte Firebase anonyme. Vous pouvez supprimer définitivement le compte et ses données depuis le profil."]),
                .init(id: "changes", title: "6. Disponibilité et droits", paragraphs: ["Le service est fourni sans garantie de résultat particulier. Les modifications importantes seront affichées avec une nouvelle date. Les droits impératifs des consommateurs restent applicables."])
            ]
        }
        if SupportedLocale.app.rawValue == "es" {
            return [
                .init(id: "acceptance", title: "1. Aceptación y servicio", paragraphs: ["Al usar NinetyLens aceptas estas condiciones. La app ofrece calendario, favoritos, historial y análisis probabilísticos asistidos por IA."]),
                .init(id: "disclaimer", title: "2. Aviso", paragraphs: ["Los análisis son solo informativos y de entretenimiento. No garantizan resultados ni constituyen asesoramiento financiero o de apuestas."]),
                .init(id: "purchases", title: "3. Créditos y compras", paragraphs: ["Los créditos son bienes digitales consumibles ofrecidos mediante compras integradas de Apple. Los créditos comprados no caducan. Un reembolso confirmado por Apple puede retirar los créditos no utilizados correspondientes."]),
                .init(id: "acceptable", title: "4. Uso permitido", paragraphs: ["No se pueden eludir controles de seguridad o créditos, enviar solicitudes automatizadas masivas ni redistribuir datos de API sin autorización."]),
                .init(id: "account", title: "5. Cuenta y eliminación", paragraphs: ["La app usa por defecto una cuenta anónima de Firebase. Puedes eliminar permanentemente la cuenta y sus datos desde el perfil."]),
                .init(id: "changes", title: "6. Disponibilidad y derechos", paragraphs: ["El servicio se ofrece sin garantía de un resultado concreto. Los cambios importantes se mostrarán con una nueva fecha. Se mantienen los derechos obligatorios del consumidor."])
            ]
        }
        return [
            .init(id: "acceptance", title: "1. Acceptance", paragraphs: ["By using NinetyLens, you accept these Terms of Use. If you do not agree, do not use the app. You may delete your anonymous account from the profile screen at any time."]),
            .init(id: "service", title: "2. Service", paragraphs: ["NinetyLens provides match schedules, favorites, analysis history, and AI-assisted probability analysis. Features, league coverage, credit costs, and free allowances may change over time."]),
            .init(id: "disclaimer", title: "3. Predictions and betting disclaimer", paragraphs: ["All analyses are probabilistic information for informational and entertainment purposes only. They are not guaranteed outcomes, financial advice, or betting advice. Data may be incomplete, delayed, or incorrect. You remain responsible for your decisions and losses."]),
            .init(id: "account", title: "4. Account and free use", paragraphs: ["The app creates an anonymous Firebase account by default. You are responsible for device and account security. New accounts receive a one-time welcome credit. Reopening a match analysis you already unlocked never costs another credit."]),
            .init(id: "purchases", title: "5. Credits and purchases", paragraphs: ["Credits are consumable digital goods offered through Apple’s in-app purchase system. Purchased credits do not expire. A refund confirmed by Apple may remove the corresponding unused credits. Apple processes payments and refunds."]),
            .init(id: "acceptable", title: "6. Acceptable use", paragraphs: ["You may not reverse engineer the service, send automated bulk requests, bypass quota or security controls, redistribute API data without authorization, or use the service unlawfully. Access may be limited in response to abuse."]),
            .init(id: "thirdparty", title: "7. Third-party services", paragraphs: ["Match data is supplied by football-data.org, infrastructure by Firebase/Google Cloud, AI analysis by Google Gemini, and one-time credit purchase validation by RevenueCat. Outages, delays, or data changes in those services may be outside NinetyLens’s control."]),
            .init(id: "ip", title: "8. Intellectual property", paragraphs: ["The NinetyLens name, design, and application code belong to their respective rights holders. Team, league, and provider names may be trademarks of their owners. You receive a limited, personal, non-transferable right to use the app."]),
            .init(id: "availability", title: "9. Availability and liability", paragraphs: ["The service is provided as is, without a guarantee of uninterrupted or error-free operation or fitness for a particular outcome. Subject to mandatory law, NinetyLens is not responsible for indirect damages or losses arising from app use."]),
            .init(id: "changes", title: "10. Changes and termination", paragraphs: ["The service and these terms may be updated. Material changes will appear with a new effective date. Access may be suspended for violations; you may stop using the service by deleting your account. Mandatory consumer rights in your location remain unaffected."])
        ]
    }
}

struct LegalDocumentScreen: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(document.effectiveDate).font(.caption).foregroundStyle(Pitch.textMuted)
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.headline)
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph).font(.subheadline).foregroundStyle(Pitch.textSecondary).lineSpacing(3)
                        }
                    }
                }
            }
            .padding(Pitch.screenPadding)
            .padding(.bottom, 24)
        }
        .pitchScreen()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
