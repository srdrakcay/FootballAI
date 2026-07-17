# NinetyLens App Review Submission

Updated: 16 July 2026

## App Review notes

NinetyLens is a football fixture and informational probability-analysis app. It does not provide betting, wagering, odds, gambling accounts, real-money prizes, or guaranteed outcomes.

The app creates an anonymous Firebase account automatically; no reviewer credentials are required. Reviewers can:

1. Complete onboarding.
2. Browse supported fixtures by date.
3. Add or remove a favorite.
4. Open Profile to view the credit balance, Privacy Policy, Terms of Use, Sign Out, and Delete Account.
5. Use the included free credit on a supported fixture with available data.
6. Open the saved result again from History without a duplicate generation or duplicate credit charge.

The app has no subscription. `footballai_credits_5` and `footballai_credits_10` are consumable one-time purchases. Purchased credits do not expire. The required credit amount is displayed before an analysis. Apple handles payment; RevenueCat validates the transaction and a server webhook updates the Firestore wallet. If a transaction is refunded or reversed, the corresponding unused credit adjustment may be applied.

AI results are informational probabilities based on available match data. They are not betting or financial advice. A visible disclaimer accompanies the analysis.

Account deletion is available at Profile > Delete Account and removes the anonymous Firebase account plus user-linked profile, credit, favorite, history, and request data. Sign Out only removes the local session.

Support contact: `srdrakcay25@gmail.com`

## App Privacy answers

Select **Yes, we collect data from this app**.

The proposed disclosure is conservative and includes the app’s configured third-party SDKs.

### Identifiers — User ID

- Collected: Yes
- Purpose: App Functionality; Fraud Prevention / Security
- Linked to identity: No
- Used for tracking: No
- Detail: Firebase creates an anonymous UID. It is not connected to a name, email address, phone number, or advertising profile.

### Purchases — Purchase History

- Collected: Yes
- Purpose: App Functionality; Analytics
- Linked to identity: No
- Used for tracking: No
- Detail: Apple and RevenueCat transaction/product status is associated with the anonymous app user ID to validate purchases, maintain credit balance, prevent duplicate credit grants, and provide RevenueCat purchase reporting. NinetyLens does not receive payment-card details.

### Usage Data — Product Interaction

- Collected: Yes
- Purpose: App Functionality
- Linked to identity: No
- Used for tracking: No
- Detail: Favorite fixtures, analysis history, credit usage, and duplicate-analysis records are stored against the anonymous account to provide requested functionality.

### Diagnostics — Other Diagnostic Data

- Collected: Yes
- Purpose: App Functionality; Analytics
- Linked to identity: No
- Used for tracking: No
- Detail: Firebase Functions collects invocation metadata including function name and caller IP. Firebase/Google and RevenueCat may process limited SDK, OS, app-version, locale, request, and security information for operation, diagnostics, fraud prevention, and service quality.

### Location

- Precise Location: No
- Coarse Location: No for NinetyLens functionality. Do not declare a location feature.

### Financial information

- Payment Info: No
- Detail: Payment credentials are entered into Apple’s purchase flow and are not accessible to NinetyLens.

### Contact information, contacts, user content, browsing/search history, health, fitness, sensitive information

- No, unless a future release adds a feature that collects one of these categories.
- Support emails sent outside the app are handled only to answer the request and are not collected by the current app binary.

### Tracking

- Data used for tracking: No
- ATT prompt required: No
- The app does not include advertising, IDFA access, cross-app tracking, data brokerage, or behavioral advertising.

## Privacy URLs

| Locale | Privacy | Support | Marketing |
| --- | --- | --- | --- |
| English (U.S.) | `https://footballai-40789.web.app/privacy` | `https://footballai-40789.web.app/support` | `https://footballai-40789.web.app` |
| Turkish | `https://footballai-40789.web.app/tr/privacy` | `https://footballai-40789.web.app/tr/support` | `https://footballai-40789.web.app/tr` |
| German | `https://footballai-40789.web.app/de/privacy` | `https://footballai-40789.web.app/de/support` | `https://footballai-40789.web.app/de` |
| French | `https://footballai-40789.web.app/fr/privacy` | `https://footballai-40789.web.app/fr/support` | `https://footballai-40789.web.app/fr` |
| Spanish | `https://footballai-40789.web.app/es/privacy` | `https://footballai-40789.web.app/es/support` | `https://footballai-40789.web.app/es` |

Use the matching privacy URL for the optional Privacy Choices URL because it describes and links the in-app deletion method and privacy contact.

## Age rating and content declarations

- Gambling: None
- Contests: None
- Real Money Gaming: None
- Unrestricted Web Access: No
- User-Generated Content: No
- Messaging/Chat: No
- Advertising: No
- Mature/Sexual/Violent content: None
- AI-generated informational sports analysis: Yes, with visible limitations and no guaranteed claims

Select the age rating produced by App Store Connect from these truthful answers; do not manually lower it.

## Export compliance

The app uses standard HTTPS/TLS encryption supplied by Apple and third-party SDKs and does not implement proprietary cryptography. Answer the App Store Connect export-compliance questions consistently with exempt standard encryption. Final confirmation remains required when uploading the release build.

## Content rights

NinetyLens displays factual fixture and team information obtained through football-data.org. It does not claim affiliation with clubs, leagues, federations, Apple, Google, or the data provider. Do not add protected league or club names to keywords.

## Review checklist

- Privacy Policy is accessible both inside the app and from App Store metadata.
- Account deletion is available inside the app.
- All visible purchase products use Apple In-App Purchase.
- Purchased credits do not expire.
- No paywall screenshot is included in the public screenshot set.
- IAP review screenshot is stored at `AppStoreAssets/review/iap-credit-packs-review.png`.
- IAP promotional images are stored at `AppStoreAssets/iap/promotional-images/`.
- Localized App Preview videos are stored at `AppStoreAssets/previews/*-app-preview.mp4`.
- Reviewer can reach the core app without credentials.
- A production backend, sample-supported fixture, and purchase products must be available during review.
- Add both consumable IAPs to the first app-version submission.
- Test all URLs publicly after Firebase Hosting deployment.
