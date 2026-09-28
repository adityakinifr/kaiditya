# App Store submission

Status of this branch (`appstore-ready`): code/config is submission-ready. Remaining steps need your Apple account.

## Done in code
- Signing: automatic, team `LYC565AV7N` (simulator scripts build unsigned with `CODE_SIGNING_ALLOWED=NO`)
- `Resources/PrivacyInfo.xcprivacy`: no tracking, no data collected, UserDefaults reason `CA92.1`
- `ITSAppUsesNonExemptEncryption = false` (no export-compliance prompt per build)
- Version/build come from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`
- `KAIDITYA_*` launch hooks compiled out of Release (`GameScene.debugEnv`)
- Portrait-only orientation; iPhone-only device family
- `docs/privacy.html`, `docs/support.html` for GitHub Pages
- `scripts/archive.sh` (+ `scripts/ExportOptions.plist`) builds archive + .ipa; `--upload` uploads

## Your steps
1. **Xcode → Settings → Accounts**: sign in with the Apple ID for team `LYC565AV7N` (export fails with "No Accounts" until then).
2. Confirm membership is active and agreements accepted at developer.apple.com/account.
3. **GitHub Pages**: repo Settings → Pages → deploy from branch `main`, folder `/docs`.
   - Privacy URL: `https://adityakinifr.github.io/kaiditya/privacy.html`
   - Support URL: `https://adityakinifr.github.io/kaiditya/support.html`
4. **App Store Connect → Apps → +**: iOS, name "Kaiditya" (fallback "Kaiditya: Pint-Sized Hero"), bundle ID `com.kaiditya.game`, SKU `kaiditya-001`.
5. `scripts/archive.sh --upload` (use `BUILD=N` to bump the build number on later uploads).
6. TestFlight: install on your phone, play through once.
7. Metadata (below), screenshots, age rating, App Privacy = **Data Not Collected**, price Free, DSA = non-trader, turn off "Available on Mac" unless tested.
8. Submit for review.

## Metadata draft
- **Subtitle** (30): Pint-Sized Hero, Big-Time Save
- **Category**: Games → Adventure; secondary Family
- **Age rating**: 9+ (infrequent cartoon/fantasy violence; everything else None)
- **Keywords** (100): superhero,stealth,sneak,kids,hero,crystals,rescue,chase,boss,adventure,family,offline
- **Description**:
  > Lord Chow-Chow has stolen the city's Energy Crystals — and only Kaiditya, the pint-sized superhero, can get them back!
  >
  > Sneak past minions' vision cones, blend in with a disguise, dash, shield and grapple your way through 11 missions: rescue trapped citizens, shut down generators, chase a getaway truck and speedboat, and face Lord Chow-Chow in his fortress.
  >
  > • Stealth missions that get steadily harder — never unfair
  > • Earn up to 3 stars per level
  > • Unlock gadgets and costumes with coins you earn by playing
  > • Explore Hero City: arcade, wishing fountain, daily chest and a friendly dog
  > • No ads, no in-app purchases, no data collected — plays fully offline
- **Review notes**: No login or network. Coins are earned in play only (no purchases). Controls: drag left side to move; buttons on the right.

## Screenshots
Required: 6.9" iPhone portrait, 1320×2868 (1–10 images, no alpha). Capture on an iPhone 17 Pro Max simulator:
`xcrun simctl io <udid> screenshot shot.png` — take them after the graphics pass lands.
