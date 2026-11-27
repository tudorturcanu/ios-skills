# Trailmix universal link review (project)

## Verdict
I found no defect in the provided files that explains the symptom. The app-side configuration, the AASA file and the routing code are all consistent with each other. The cause is most likely outside this folder, and I can't tell which of several candidates it is from the files alone. I'd rather say that than invent a bug.

## What the symptom says
- CONTEXT.md:7-9: the https link opens Safari, the `trailmix://` link works, and Messages offers "Open in Safari" as the default.
- That pattern means the app's code is fine (the custom scheme proves the routing and coordinator work). The OS is not treating the https link as a universal link for this app.
- Code inside the app can't cause that. If iOS had decided the link belonged to the app, it would call `scene(_:continue:)` or `willConnectTo`. The link never reaches the app, so the SceneDelegate and router are not where the failure is.

## Checked and found correct (evidence)
1. **Entitlement domain.** Trailmix.entitlements:5-7 has `applinks:links.trailmix.example`. This exactly matches the host in CONTEXT.md:4 and `DeepLinkRouter.universalHost` (DeepLinkRouter.swift:9). It has no scheme, no port and no path, which is the correct form. High confidence for the file's content.
2. **App ID.** apple-app-site-association.json:5 has `K7P2QD9XM4.com.trailmix.app`. That equals Team ID + bundle id from CONTEXT.md:3 and Info.plist:6. There is no typo or mismatch.
3. **AASA schema.** The file uses `applinks.details[].appIDs` plus `components` (lines 2-7). This is the valid iOS 13+ format. Each component uses the `"/"` key, which is correct. The extra `comment` key is a documented, allowed key. An `exclude: true` component (line 9) is valid.
4. **Path coverage.** CONTEXT.md:18-19 says links are `/recipes/<id>` and `/collections/<slug>`. These are matched by `/recipes/*` and `/collections/*` (lines 7-8). I see no singular/plural mismatch. `/admin/*` is excluded, but the exclude entry sits last (line 9). Components are evaluated in order, so exclusions normally go first. This is harmless here because `/admin/*` doesn't overlap the earlier patterns. Treat it as a hygiene issue, not the cause.
5. **Serving.** Per CONTEXT.md:12-14 the file is served at the `/.well-known/` path as JSON, HTTP 200, with no redirects. That is a stated fact, not something I could check.
6. **App routing.** `route(for:)` accepts `https` only for the matching host (DeepLinkRouter.swift:14-16). `pathComponents` filtered for "/" gives `["recipes","42"]` and parses to `.recipe(42)` (lines 27-32). SceneDelegate handles all three entry points: cold launch (SceneDelegate.swift:9-13), `continue userActivity` (16-18), and `openURLContexts` (20-22). The code is correct for universal links if the OS delivers them.
7. **Custom scheme.** Info.plist:8-17 registers `trailmix`. That explains why the custom scheme works, and it is unrelated to universal links.

## Things I could not verify from the files alone (candidate causes)
These are ordered by how plausible they look, not by evidence. I have no evidence for any of them.
- **Apple CDN fetch (swcd) of the AASA.** On iOS 14+ the device gets the AASA from Apple's CDN, not directly from your server. The CDN must reach `links.trailmix.example` publicly. The `.example` TLD is reserved and never resolves publicly. If that is the real host and not a redaction for this exercise, the CDN can't fetch the file and universal links can never work. CONTEXT.md says the file is "served" there but does not say it is reachable from the public internet. I can't tell whether `.example` is a placeholder.
- **CDN caching or delay.** New or changed AASA files can take time to propagate, and the CDN caches. The TestFlight install may have been done before the CDN picked up the file. Unverifiable.
- **Entitlement not in the built binary.** CONTEXT.md:15-16 says the capability is enabled and the profile includes it. I can't see the Xcode project, so I can't confirm that `CODE_SIGN_ENTITLEMENTS` points at this entitlements file for the TestFlight/Release configuration. A per-configuration mismatch is possible. The real signed entitlements could be checked with `codesign -d --entitlements :-`.
- **Server-side behavior.** The AASA must be the same for the CDN's user agent as for QA's `curl`. The file should not be gated by a redirect, a bot filter or auth for Apple's fetcher. I can't see the server.
- **Device state.** iOS remembers a user's choice. If someone earlier long-pressed and chose "Open in Safari", that choice persists. QA says it is a fresh install, so this is less likely, but it is not ruled out. Also, links typed or pasted into Safari's own address bar never open the app. The report covers Notes and Messages, so this should not apply.
- **AppCoordinator is not provided.** `coordinator` (SceneDelegate.swift:5) is never assigned in the files here. If it were nil at cold launch, `coordinator?.navigate` would silently do nothing. That would affect the custom scheme as well, and the custom scheme works, so it is not the cause of this symptom. It is still worth checking for cold-launch ordering.

## What I would change
Nothing in the provided code or config is wrong enough to justify an edit as a fix. Suggested actions are diagnostic:
1. Fetch Apple's CDN copy of the AASA at `https://app-site-association.cdn-apple.com/a/v1/links.trailmix.example`. Confirm it is returned, is current, and contains these components. This is the single most informative check.
2. Confirm that the host is publicly resolvable, since `.example` is not.
3. Inspect the entitlements of the actual TestFlight build to confirm `applinks:links.trailmix.example` is present.
4. Optional hygiene: move the `/admin/*` exclude component before the allow rules in the AASA (apple-app-site-association.json:9), because first match wins.
5. Optional: log in `scene(_:continue:)` to confirm no activity arrives, which would confirm the OS is not delivering the link.

## Confidence
- High: the files are internally consistent, and the app code is not the reason for the Safari behavior.
- Low: which external cause is responsible. The files don't contain enough information to decide.
