# FC Leads

An Android app for client outreach:

1. **Search** Google Maps for local businesses (e.g. "restaurants in Dhanmondi").
2. **Audit** each one automatically: Google Maps profile, website, social media links, basic SEO and AI-answer readiness (AEO · GEO).
3. **Design** a personalised 1080×1350 graphic with the business's results.
4. **Send** it by WhatsApp (opens the chat with that number) or email (opens the email app with subject, message and graphic). You tap Send.

## Setup

- Get a Google Places API key: Google Cloud Console → new project → turn on billing → enable **Places API (New)** → Credentials → Create API key (restrict it to Places API (New)).
- Open the app → **Settings** → paste the key and fill in the agency details (name, website, WhatsApp, email, your name). These appear on every graphic and message and can be changed any time.

The key is stored only on the phone, never in this repo.

## Build

GitHub Actions (`.github/workflows/build.yml`) runs `flutter analyze`, the tests and a release build on every push. Download the APK from the run's **fc-leads-android** artifact.

Locally:

```bash
bash tool/setup_platforms.sh   # creates the rest of android/ with flutter create
flutter pub get
flutter run
```

## Code map

| Path | What it does |
|---|---|
| `lib/services/places_api.dart` | Google Places API (New) Text Search |
| `lib/services/website_checker.dart`, `lib/logic/html_analyzer.dart` | Opens the website, checks HTTPS, mobile, title, description, H1, schema, FAQ, social links and emails |
| `lib/logic/audit_builder.dart` | Turns the findings into the five audit rows |
| `lib/logic/messages.dart` | WhatsApp and email text |
| `lib/widgets/audit_graphic.dart` | The outreach graphic |
| `android/.../MainActivity.kt` | Hands the graphic to WhatsApp / email apps |

## Notes

- Google Maps does not give email addresses; the app looks for them on the business's website.
- Places API calls that include phone, website and rating are billed by Google. Check current pricing in Google Cloud.
- Send messages one by one and only to businesses that are a real fit. Bulk unsolicited messages can get a WhatsApp number banned.
