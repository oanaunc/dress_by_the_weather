# Google Play Data safety declaration — Android 1.0

Completed November 26, 2026. Public policy: https://www.oanarinaldi.com/dressbytheweatherandroidprivacy.html

- Data collection/sharing: Yes. All app network requests use HTTPS; Android cleartext is disabled.
- No app account creation or external account sign-in. Google Play handles the separate platform purchase.
- Approximate location: collected/shared for app functionality, non-ephemeral, required for live service requests (provider receives IP in addition to optional approximate device coordinates).
- Precise location: collected/shared for app functionality, non-ephemeral, optional (manually chosen address/coordinate destinations may be precise; the Android permission itself is approximate only).
- In-app search history: collected/shared for app functionality, non-ephemeral, optional (Android geocoder / Photon place searches).
- Purchase history: collected for app functionality and fraud prevention, non-ephemeral, optional. Google Play purchase query/acknowledgement and local signed entitlement proof. No card information is accessed by the app; Google payment processing is governed by Google terms. Google acts as billing service provider.
- No advertising/analytics SDKs, email/contact collection, photo upload, health data, messages, microphone, calendar or contact access.
- Local photos/plans/preferences are not transmitted. Provider API logs are outside the developer's storage; do not promise deletion of provider logs. The public policy explains local deletion and provider contacts.
- No independent security-audit or UPI badge claimed.

Primary guidance consulted: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-en
