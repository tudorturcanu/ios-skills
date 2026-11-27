# Trailmix universal link review (base-defect)

## Verdict
There is a problem, and it is in the AASA file, not the app code. High confidence.

## Root cause
`apple-app-site-association.json` line 7 allows `"/": "/recipe/*"` (singular). The marketing link in `CONTEXT.md` line 4 is `https://links.trailmix.example/recipes/42` (plural). The pattern `/recipe/*` needs the literal path segment `recipe` followed by `/`. `/recipes/42` does not match it.

No other component matches `/recipes/42`:
- Line 8 is `/collections/*`.
- Line 9 is `/admin/*`, an exclusion.

So iOS treats the URL as not claimed by the app and opens it in Safari. That fits every symptom in `CONTEXT.md` lines 7-9:
- Safari opens from Notes and Messages.
- Long-press shows "Open in Safari" as the default.
- The custom scheme works, because it never goes through AASA (see below).

The app code agrees with the link, not with the AASA:
- `DeepLinkRouter.swift` line 30 parses `"recipes"` (plural).
- `CONTEXT.md` line 4 uses the plural.
- `/recipe/*` on line 7 of the AASA is the odd one out, most likely a typo.

## Things I checked that look correct
- **Team ID and bundle ID.** AASA line 5 is `K7P2QD9XM4.com.trailmix.app`. This matches `CONTEXT.md` line 3 and `CFBundleIdentifier` in `Info.plist` line 6.
- **Entitlements.** `Trailmix.entitlements` line 7 has `applinks:links.trailmix.example`. It has no `?mode=developer`, no port, and no wildcard problem. The host matches `DeepLinkRouter.universalHost` (line 9) and the host in the link.
- **AASA schema.** `appIDs` (plural) with `components` and `/` keys is the iOS 14+ format. The extra `comment` keys are allowed. The `exclude` entry does not overlap the other patterns, so its position does not matter here. iOS 17 supports all of this.
- **Custom scheme.** `Info.plist` lines 8-17 register `trailmix`. In `DeepLinkRouter.swift`, `trailmix://recipes/42` gives host `recipes` and path `/42`. Lines 18-21 rebuild that into `["recipes","42"]`, and `parse` returns `.recipe(42)`. This explains why the scheme works.
- **App-side routing of the https URL.** If iOS did hand the link to the app, the code would handle it correctly. `SceneDelegate.swift` lines 9-10 and 16-17 pass `webpageURL` to the router. The router's https branch (lines 14-16) checks the host and parses `["recipes","42"]` to `.recipe(42)`.

## Secondary observations (lower confidence, not the cause of the reported symptom)
1. **Possible dropped link on cold launch.**
   - In `SceneDelegate.willConnectTo` (lines 7-14), `handle(...)` runs and calls `coordinator?.navigate`.
   - Nothing in this folder assigns `coordinator` or `window`. `AppCoordinator` is not provided.
   - If the coordinator is created after `willConnectTo`, a cold-launch link is silently dropped.
   - I cannot tell from these files. It would only matter once the AASA is fixed, and only for cold launches.
2. **Entitlements may differ from the shipped build.** I can only see the checked-in file. `CONTEXT.md` says the capability is enabled and in the profile, and I take that as given.
3. **`/collections/*` is consistent.** AASA line 8 and router line 33 both use `collections`, so I expect collection links to work.

## Not verifiable from these files
- That the live AASA at `https://links.trailmix.example/.well-known/apple-app-site-association` is byte-identical to the local copy. `CONTEXT.md` says it is, and I did not fetch it.
- That the CDN or Apple's AASA CDN has refreshed. Apple fetches AASA at install time and caches it, so a fixed file may need a reinstall or a wait to take effect on devices.
- That the TestFlight build was signed with these entitlements.
- That the link is not also affected by a "tap within the same domain" or user-override effect. The long-press default of "Open in Safari" is more consistent with a non-match, but a user-chosen override cannot be excluded from the files alone.
- Anything in `AppCoordinator` or the app delegate, which are not included.

## What I would change
1. **Required fix.** Decide which path is canonical, then make the AASA and the marketing links agree. The simplest option is `"/": "/recipes/*"` on AASA line 7, which matches the router and the existing links. If `/recipe/...` was intended, the links and `DeepLinkRouter.parse` line 30 would have to change instead. Redeploy the AASA, then reinstall the app and retest. iOS caches AASA, so a delete and reinstall is the reliable test.
2. **Optional hardening.**
   - Put the `/admin/*` exclusion first in the components list, since ordering matters if a broader pattern is added later.
   - Make the router accept both `recipe` and `recipes` if old links exist in the wild.
   - Verify that the coordinator is ready before `willConnectTo` handles the URL, or queue the route.
