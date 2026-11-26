# App Review walkthrough

[Watch ReviewerWalkthrough.mp4](ReviewerWalkthrough.mp4)

Actual app screen recording, with captions explaining free features and the optional Pro upgrade. Recorded on iPhone Simulator with clearly labeled sample weather; Pro tools use the Debug preview. The submitted Release build has no purchase bypass. StoreKit purchase, cancellation, restore, relaunch and refund revocation were separately verified with Apple’s local test catalog. No real payment was made.

## Chapters

- 00:00 — Your weather. Your daily outfit.
- 00:03 — Understand every layer.
- 00:11 — See the day ahead.
- 00:16 — Pack the essentials.
- 00:24 — One purchase. Permanent Pro.
- 00:27 — Your personal style studio.
- 00:35 — Wear what you own.
- 00:39 — Dress the whole week.
- 00:44 — Plan the next escape.
- 00:50 — Fewer pieces. More outfits.
- 00:55 — An editorial collection.
- 00:59 — Style with purpose.

Reproduce the capture with `AppFlowTests/testReviewerWalkthrough`, `simctl io recordVideo`, and `Scripts/render_review_video.py`. Raw video and intermediate panels are ignored build artifacts.
