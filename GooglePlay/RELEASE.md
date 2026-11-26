# Android release record

Version **1.0 (2)** was submitted to Google Play on **26 November 2026, approximately 11:30 Europe/Bucharest**. The console confirmed **12 changes submitted for review** and displayed **Changes in review**. Automated checks were still running at that observation. It is not yet publicly released.

[Google Play publishing status](https://play.google.com/console/u/0/developers/8359156760975569195/app/4973699322018773438/publishing).

The production bundle includes all 214 approved photographs, eight guides, free worldwide weather and the one-time Dress Pro Lifetime upgrade. The US base price is **$19.99**, with Google localized pricing. The purchase option is active in 174 supported regions. Production distribution includes 177 countries/regions and the rest-of-world option. Managed publishing is disabled, so an approved release can publish automatically.

The source for the submitted application is commit `7f34988c97c0059690dcbbfa9c3b367db7e7e128`. Subsequent CI/documentation-only commits do not change the submitted application. See [bundle checksum and identifiers](build-record.json). Private upload keys remain outside the repository. The initial version 1 bootstrap bundle remains an unsubmitted internal-test draft and is not part of this production submission.

The store listing includes the original icon, feature graphic, eight phone screenshots, six 7-inch tablet screenshots and six larger-tablet screenshots. All artwork containing the generated couple is declared as AI-created/edited. The IARC terms were accepted after the owner's explicit confirmation, and the rating questionnaire is complete. Advertising and advertising-ID use are both declared absent.

Reviewers have instructions for the public temporary sample Studio, which exposes every Pro tool without payment or account creation. A second access-instructions entry links the [72-second captioned Android walkthrough](ReviewerWalkthrough.mp4). This video uses actual screenshots and is not represented as a continuous screen recording.

[The Android privacy policy](https://www.oanarinaldi.com/dressbytheweatherandroidprivacy.html) is live on the owner's website. Google's automated check reported a DNS-resolution error; the exact submitted HTTPS URL returned HTTP 200, and both Google Public DNS and Cloudflare resolved its host. The console's option to continue with a reported incorrect issue was used after this verification. The page and DNS should be checked if Google raises the issue during review. The existing iOS policy was preserved.

Validation completed:

- Eleven JVM tests passed, including exact parity with 9,360 shipping Swift outfit-engine cases, forecast parsing, time zones, purchase signature rejection, preferences and wardrobe/capsule behavior.
- Four instrumented phone flows passed, including real worldwide Sydney search, free tools, Pro tools and isolated sample-preview reset. Main free/Pro flows also passed on both tablet layouts.
- The separately installed, signed, minified production APK passed its UI smoke test: onboarding, free navigation, public Pro preview, wardrobe editing, exit and reset without granting ownership.
- Signed release bundle/APK builds and release lint passed. No real Google payment was made; live payment-sheet, cancellation and refund behavior still require a Play-installed licensed tester.

Android matches the original app's layouts, palette, photography, content and styling rules. Native Android permissions, billing, widgets and licensed fonts/icons differ from Apple system components.
