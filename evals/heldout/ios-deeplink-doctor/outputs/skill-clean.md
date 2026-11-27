# Trailmix universal link review (read-only)

## Summary
I found no defect in the supplied files that explains why `https://links.trailmix.example/recipes/42` opens Safari. The entitlements, AASA, URL parsing and scene handlers are all consistent with each other. The failing boundary is therefore most likely outside these files: association between the device and the domain (signed build, AASA fetch/CDN, or link-opening preference). It is not the routing code. This is an inference from the absence of defects, not a confirmed root cause. Nothing was built or run.

## Failing boundary (what the evidence supports)
- The custom scheme works (CONTEXT.md:8). That shows that `onOpenURL`-equivalent delivery, `DeepLinkRouter` parsing and `coordinator.navigate` work for recipes. It proves nothing about universal-link delivery.
- Safari opening on tap, and "Open in Safari" as the default on long-press (CONTEXT.md:7, 9), indicates iOS did not associate the host with the app, or the user's saved preference for the link is Safari. That happens before any app code runs, so the Swift handlers cannot be the cause.

## What I checked, and found consistent
| Check | Evidence | Result |
|---|---|---|
| Entitlement domain matches host | Trailmix.entitlements:7 `applinks:links.trailmix.example`; DeepLinkRouter.swift:9 same host; CONTEXT.md:2 link host | Match, no `?mode=developer` qualifier, no `www.` or subdomain mismatch |
| App ID matches | AASA:5 `K7P2QD9XM4.com.trailmix.app`; CONTEXT.md:3 Team ID `K7P2QD9XM4`, bundle `com.trailmix.app`; Info.plist:6 | Match (assuming application-identifier prefix equals Team ID; see unverified) |
| AASA format | AASA:3-12 modern `details` with `appIDs` and `components` (iOS 14+; device is iOS 17) | Valid form |
| Path matching | AASA:7 `/recipes/*` matches `/recipes/42`; AASA:8 `/collections/*`; AASA:9 excludes only `/admin/*`, which is not a shared shape | Covers both documented backend paths (CONTEXT.md:18-19). Exclusion order is not an issue |
| Hosting | CONTEXT.md:12-14 JSON, 200, no redirects | Acceptable per the documentation, not independently verified |
| Handler wiring | SceneDelegate.swift:9-10, 16-18 handle `NSUserActivityTypeBrowsingWeb` for cold launch and warm; Info.plist:25-26 registers the scene delegate | Correct for a scene-based app |
| Parsing | DeepLinkRouter.swift:14-16 requires https and exact host; `pathComponents` filtering of "/" yields `["recipes","42"]`; trailing slash also parses; non-numeric id returns nil (31) | Correct for the documented link shapes |

Plural `/recipes/` is used consistently in the AASA, router and backend, so there is no singular/plural mismatch.

## Candidate causes outside the files (ordered by my judgment, all unverified)
1. **Signed TestFlight build lacks, or has a different, associated-domains entitlement.** The source plist alone does not prove the signed app contains it (CONTEXT.md:15-16 asserts capability and profile only). I see no build settings or `CODE_SIGN_ENTITLEMENTS` mapping in this folder, so I cannot tell that Trailmix.entitlements is the file used for the TestFlight target/configuration.
2. **Apple CDN holds a stale or missing AASA for the host.** The origin serving the file correctly (CONTEXT.md:12-14) does not prove what the CDN returned to this device at install. Retest time and CDN state are unknown. A host that was added or changed recently could be affected.
3. **The domain `links.trailmix.example` and public reachability.** `.example` is a reserved name, so this is presumably a redacted placeholder. If the real host is not publicly reachable by Apple's CDN (for example behind auth, firewall, or non-public DNS), association fails exactly like this.
4. **User link-opening preference or a previous choice of Safari** (long-pressing a universal link and choosing Safari stores it per domain). The "Open in Safari" default in CONTEXT.md:9 is consistent with either a failed association or such a stored preference; the files do not distinguish them.
5. Application identifier prefix differing from the Team ID (for example a legacy App ID prefix). Unlikely, but the skill notes not to assume equality; the signed `application-identifier` would show it.

## Things I could not verify from the files
- The contents of the signed TestFlight binary's entitlements, and the application-identifier.
- Actual HTTP behavior of the AASA endpoint (host, content, redirects, CDN copy).
- Device-side association status (Settings > Developer > Associated Domains diagnostics, sysdiagnose).
- AppCoordinator (`navigate(to:)`) is not in the folder, so what happens after routing (tab/modal readiness, authentication, pending route) is unreviewed. It is not implicated in this symptom since the custom scheme works.
- That only one scene/window is in play; `UISceneConfigurationName` is absent in Info.plist:23-27, which is typically harmless with a delegate class name but is untested here.

## Minor observations (not causes of the symptom)
- SceneDelegate.swift:21 handles only `contexts.first`; fine for a single link per open.
- SceneDelegate.swift:31-32 silently drops unrecognized or invalid links, and with `coordinator` possibly nil at cold launch (line 32 uses optional chaining) the route would be lost if the coordinator is created later. That is a possible cold-launch issue worth checking in AppCoordinator, but it does not apply to the Safari symptom.
- Router drops query/fragment; fine for the documented shapes.

## What I would change
Nothing in the source based on current evidence. Do not rewrite routing or the AASA. Instead:
1. Extract entitlements from the actual TestFlight build (`codesign -d --entitlements :- Trailmix.app`) and confirm `applinks:links.trailmix.example` and the application-identifier. The bundled `aasa_inspect.py` can compare those with the AASA file.
2. Fetch the AASA from the CDN (`app-site-association.cdn-apple.com/a/v1/links.trailmix.example`), record the time, and compare with the origin.
3. On the device, check Associated Domains diagnostics for the host; reinstall after any CDN refresh; then test a tapped link from Notes (long-press shows the app option) and note the stored link-opening preference before and after.
4. Only if association proves good but the app still does not open, revisit delivery and AppCoordinator readiness.

Confidence: high that the supplied routing/entitlement/AASA files are internally consistent; low-to-moderate on which external cause applies, because none can be confirmed from these files.
