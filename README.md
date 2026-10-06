# FC Leads

An Android app for client outreach:

1. **Search** Google Maps by business type (55 types grouped by sector, matched to FansConnector's services), country (250) and city (135,000, largest first), or type your own search. Recent searches are one tap away.
2. **Audit** each business automatically: Google Maps profile, website, social media links, basic SEO and AI-answer readiness (AEO · GEO). Social links found on the website are listed; missing ones can be found on Google or added by hand.
3. **Design** a personalised 1080×1350 graphic with the business's results, in one of four accent colours.
4. **Send** by WhatsApp (step 1 opens their chat with the message typed in, step 2 sends the graphic) or email (opens the email app with recipient, subject, message and graphic). Messages can be edited per lead; defaults live in the Templates tab. You tap Send — WhatsApp and email apps never let another app send for you.
5. **Track** every lead: status (New → Contacted → Replied → Interested → Won/Lost), follow-up date, notes. The Leads tab filters by status, contact, website, follow-up, country and type, and exports CSV. Home shows the pipeline and follow-ups due.

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

- City data: GeoNames (CC BY 4.0), via the `all-the-cities` package; country list from `countries-list` (MIT).
- Google Maps does not give email addresses; the app looks for them on the business's website.
- Places API calls that include phone, website and rating are billed by Google. Check current pricing in Google Cloud.
- Send messages one by one and only to businesses that are a real fit. Bulk unsolicited messages can get a WhatsApp number banned.
