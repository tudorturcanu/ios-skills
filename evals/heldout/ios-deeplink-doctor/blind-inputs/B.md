# Trailmix universal link review (read-only)

## Verdict
Failing boundary: website association (AASA path rules), not the app's routing. Confidence: high that this is a real defect and sufficient to explain the symptom; medium-high that it is the only cause (see "Could not verify").

## Primary finding: AASA path `/recipe/*` does not match the shared link `/recipes/42`
- CONTEXT.md:4 - marketing links are `https://links.trailmix.example/recipes/42` (plural `recipes`).
- apple-app-site-association.json:7 - the only recipe rule is `{ "/": "/recipe/*" }` (singular). `/recipes/42` does not match `/recipe/*` (the `/recipe/` prefix needs a slash after "recipe"). No other component matches: `/collections/*` (line 8) and the excluded `/admin/*` (line 9) are unrelated.
- Result: for this URL the AASA says the app does not handle it, so iOS opens Safari. This matches the symptoms: Notes/Messages open Safari, and the Messages long-press shows "Open in Safari" as default (CONTEXT.md:7-9).
- The app code expects the plural form: DeepLinkRouter.swift:30 (`case "recipes"`), and the custom scheme `trailmix://recipes/42` works (CONTEXT.md:8; parse at DeepLinkRouter.swift:17-21,30-32). So the AASA is the outlier, a singular/plural typo.
- Note `collections` is consistent (AASA line 8, router line 33), so collection links likely work; this is untested.

## Things that look correct (checked, not the cause)
- AASA format: modern `applinks.details[].appIDs` + `components` is valid; `"exclude": true` and `"comment"` are valid component keys; the exclusion comes last but does not overlap earlier rules (AASA lines 4-10). App ID `K7P2QD9XM4.com.trailmix.app` matches the Team ID and bundle id in CONTEXT.md:3 and Info.plist:6. (Prefix = Team ID is only an assumption; see below.)
- Entitlement: `applinks:links.trailmix.example` (Trailmix.entitlements:7) matches the exact host in links and in DeepLinkRouter.swift:9. No `?mode=developer` qualifier.
- Hosting facts (HTTP 200, application/json, no redirects, correct well-known path) are as stated in CONTEXT.md:11-14; they are claims, not verified by me.
- Router/scene code is not responsible for the Safari fallback: if iOS had delivered the link, SceneDelegate handles both cold launch (SceneDelegate.swift:9-10) and warm (`continue userActivity`, line 16-18), and `route(for:)` accepts https on the right host with `recipes/<int>` (DeepLinkRouter.swift:14-16,30-32). Delivery never reaches the app because it is decided before the app is involved.

## Proposed change
1. Fix AASA line 7 to `"/": "/recipes/*"` (or add it alongside `/recipe/*` if singular URLs are ever published). Optionally narrow to `/recipes/*` only if you want just numeric ids; the router already rejects bad ids (DeepLinkRouter.swift:31).
2. Redeploy, then expect Apple CDN caching delay before devices see it. For a TestFlight/installed build, re-validate after the update propagates; reinstalling or waiting may be needed. Use Apple's alternate mode (`?mode=developer`) only as a separate origin check, not as proof for distributed builds.
3. No Swift change is needed for this bug.

## Could not verify from the files alone
- That the signed TestFlight build actually contains the associated-domains entitlement for this host. Trailmix.entitlements is the project file; it has no `application-identifier`, so it is not the signed entitlements (the bundled aasa_inspect.py would exit 2 on it) and is not proof of the signed app. CONTEXT.md:15-16 asserts the capability/profile, which I take as reported only.
- That the application-identifier prefix equals Team ID K7P2QD9XM4 in the signed build (could differ in principle).
- Actual AASA contents on the live host (the local JSON is said to be served as-is, CONTEXT.md:11-12), CDN state, and per-device association/diagnostics.
- The user's link-opening preference on the QA device (a prior "Open in Safari" choice can also cause Safari, though the AASA mismatch alone already explains it).
- AppCoordinator is not provided; `coordinator` (SceneDelegate.swift:5) is an optional that is never assigned in these files, and `willConnect` (line 7-14) creates no window. If the coordinator is nil at cold launch, routes would be silently dropped (line 32). The custom scheme works per CONTEXT.md:8, so it is presumably set elsewhere, but cold-launch readiness (routing before the coordinator/UI exists, login gating) is untested.
- Not tested at all: iOS 17 behaviour, simulator `simctl openurl`, universal-link delivery after the fix.

## Secondary observations (low severity, not causes)
- SceneDelegate.swift:21 handles only the first URL context; duplicate/multiple deliveries are ignored.
- Router silently drops unknown links (DeepLinkRouter.swift:31); no authorization or pending-route retention is visible.
- Percent-encoded or unusual collection slugs are accepted unvalidated (DeepLinkRouter.swift:34-35).

## Tested vs untested
| State | Status |
|---|---|
| Static read of AASA vs link path | Done: mismatch found |
| Entitlement host vs link host | Done (project file only) |
| Custom scheme routing | Reported working (CONTEXT.md:8); code reads consistent |
| Signed build entitlements | Untested |
| Live AASA / CDN / device diagnostics | Untested |
| Cold/warm/auth/modal states | Untested |
