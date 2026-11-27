---
name: ios-deeplink-doctor
description: "Diagnose and fix iOS universal-link and custom URL routing failures across cold launch, authentication, scenes, tabs, and sheets. Use for broken deep links or requested routing verification, not ordinary navigation styling."
---

# iOS Deep Link Doctor

Trace the link from delivery to the intended screen before changing routing architecture.

## Establish the failing boundary

Record a concrete URL, expected destination, actual result, build identity, OS, and launch/authentication state. Inspect the app lifecycle, scene configuration, URL types, associated-domain entitlements, and URL handlers. Use `rg` to locate `onOpenURL`, `onContinueUserActivity`, `NSUserActivityTypeBrowsingWeb`, scene delegate callbacks, and route parsers. Follow the actual target and configuration; a source entitlement file alone does not prove the signed app contains it.

Separate failures into website association, OS delivery, URL parsing, authorization, and navigation readiness. A handler invoked manually proves only the layers after delivery.

## Diagnose association and routing

For universal links, compare the signed application-identifier with the AASA app identifier; do not assume the application identifier prefix always equals the Team ID. Check each exact host, HTTPS response, redirects, and AASA matching rules. Read `applinks.details` in its actual legacy or modern format; inspect exclusions and component order. Account for Apple CDN caching and user link-opening choices before blaming the route handler. A successful origin fetch does not prove device association.

For an association change that works locally and fails in a distributed build, compare the signed entitlements and AASA rules for both builds and capture the device’s Associated Domains diagnostics for the failing host. Record the test time and distinction between origin response, CDN state, and delivery on that device. Apple’s developer-mode association can be used as a separate check for the origin and should be identified as such. [Apple’s association diagnostics](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links)

Parse with URL components and explicit scheme/host/path rules. Reject malformed or unsupported routes without crashing. Decode identifiers deliberately and test percent-encoding, duplicate query parameters, empty identifiers, and unexpected hosts. Links must not bypass account or resource authorization.

Trace pending routes through login, asynchronous model loading, tab selection, and modal dismissal. Retain the intended route until it can be consumed; avoid arbitrary sleeps. Identify scene ownership and duplicate callback behavior before adding global state. Preserve back navigation and define what a repeated link should do.

## Validate and deliver

Exercise parser tests separately from end-to-end delivery. Test terminated/background/foreground states, signed in/out, expired session, existing modal, invalid resource, and repeated delivery. With an available booted simulator, `xcrun simctl openurl booted 'URL'` exercises delivery, but a universal-link association result still needs a real tapped-link check on the intended device/build. Inspect the resulting screen. For association failures, long-press the full URL in Notes and check whether the app is offered. Record the current link-opening preference because choosing an option can change it. A typed address or same-host navigation in Safari stays in the browser by design. [Apple TN3155](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links)

Return the failing boundary, evidence with file locations, the smallest appropriate fix, and a table of tested versus untested states. If only an audit was requested, provide findings rather than edits.

## Diagnostic tool

When local AASA and signed entitlements are available, use the bundled [identity inspector](scripts/aasa_inspect.py):

```sh
python3 /absolute/path/to/ios-deeplink-doctor/scripts/aasa_inspect.py apple-app-site-association --entitlements signed.plist --host shop.example.com
```

Resolve the script path from this installed skill directory. Supply entitlements extracted from the intended signed build, not a guessed Team ID. The tool compares the signed application identifier and domain entries, retaining matching paths/components for human inspection. If every host match has a query qualifier such as `?mode=developer`, confirm the mode’s signing and device requirements before treating the entry as usable in the distributed build. [Apple’s entitlement guidance](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.associated-domains)

It handles array-form legacy and modern details, not every historical AASA representation. It does not simulate Apple's path/component matcher or verify web hosting, CDN state, or device delivery. No network requests or writes occur. Exit 0 means inspection completed, even with findings; exit 2 means invalid/unsupported input.

## Reference

Consult [Apple associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains) for deployment and AASA details. Verify SDK-specific behavior against the project's installed SDK.
