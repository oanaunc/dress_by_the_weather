# Android reviewer guide

[Watch the 72-second Android reviewer guide](ReviewerWalkthrough.mp4).

This is a captioned walkthrough built from actual Android app screenshots. Weather is explicitly labelled sample except the live Sydney screen. Pro screenshots use the Debug development preview; the signed Release build verifies Google Play purchases. The public sample Studio also provides every Pro tool in Release without payment, using temporary isolated data.

Review access: On first launch choose **Explore the sample edition**, then **Looks → A little more personal. → Preview the sample Studio**. No app account, password, purchase, special code or expiry. Exit preview resets the sample and restores the real app. For real worldwide forecasts select a city or optionally grant approximate current location.

The source project includes 214 approved original photographs and eight guides. No photos are downloaded at runtime, and no AI service receives wardrobe photos.

Live Google payment/cancellation/refund flows require a Play-installed licensed tester and were not exercised with a real payment. Local RSA proof verification, invalid-signature rejection, paywall gating, public demo isolation and restoration logic are covered separately.

Recreate with `python3 Scripts/render_android_review_video.py` after running the phone instrumented capture. Intermediate files remain in ignored `build/`.
