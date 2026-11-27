---
name: ios-permission-flow-tester
description: "Review or fix iOS permission lifecycles and recovery for camera, microphone, photos, location, notifications, and other protected resources. Use for authorization-state bugs; do not assume all permission APIs share the same states."
---

# iOS Permission Flow Tester

Treat authorization as changing capability, not a persisted boolean.

## Inventory the resource

Identify each protected operation, its framework, requested access scope, usage description, entitlement requirements, and supported OS versions. Use the installed SDK and that framework's current Apple documentation to enumerate actual states. Photo limited access, location accuracy/authorization, and notification provisional settings have distinct meanings. Do not invent a shared restricted/limited state for frameworks that do not expose it.

Trace the request trigger and preflight status query. Request access in context and avoid asking for broader access than the feature needs. Inspect alternatives such as a system photo picker that may satisfy the flow without broad library authorization. Verify usage-description keys in the built target, including relevant extensions.

## Exercise transitions

For each resource, test first request, acceptance, denial, subsequent attempt, restrictions where supported, and return from Settings. A denied permission usually requires a recovery path rather than repeating a prompt the OS will not show. Re-query actual capability when the app becomes active or before the protected operation, as appropriate; do not cache approval forever.

Handle limited/partial access as usable when the feature supports it. Check resource unavailability separately from permission denial: unavailable camera hardware, disabled services, and network failures are different states. Account for authorization changing during work and asynchronous callbacks arriving after a screen is dismissed.

If the request can outlive a view or a selection, exercise dismissal or selection change while the system prompt is open. When the result arrives, verify that the app updates the current permission state and starts protected work only for an action that is still pending and valid. Re-enter the feature to verify recovery.

Trace permission state separately from loading and operation completion. An empty authorized result or denied access must not leave an indefinite loading indicator. Authorization to save is not proof that an asynchronous save succeeded. For photo flows, read [photo access boundaries](references/photo-access-boundaries.md) to distinguish picker selection, library enumeration, and add-only saving.

Keep core flows navigable after refusal. Explain the feature impact and offer a supported Settings route when useful without trapping the user in repeated prompts. Do not treat simulator success as proof of hardware behavior.

For an App Tracking Transparency flow on iOS or iPadOS 27.2 and later, branch the test matrix by distribution region and the device-wide tracking setting. Verify the applicable prompt and that tracking follows the actual authorization status. In the EU, Apple documents a possible reprompt one year after the previous choice, subject to the device setting. Apply those conditions only to tracking. [Apple’s EU tracking guidance](https://developer.apple.com/app-store/user-privacy-and-data-use/#att-in-the-european-union)

## Verify and report

Create a table per framework: initial status, action, expected system behavior, expected app UI, observed result, and environment. Use a disposable simulator for reset-based tests when available; identify the target before resetting permissions and avoid wiping a user's device. Tests should assert recovery and access handling, not the exact wording or position of OS-owned prompts.

Record how permission was established. A `simctl privacy` grant can bypass normal request/configuration checks and may terminate the app. Check the installed tool's supported services, query the resulting status in the app, and distinguish cold relaunch from recovery in a surviving view. A successful CLI command alone does not verify authorization or the real prompt.

Return missing configuration, transition defects, scoped patches, and manual hardware checks remaining. Preserve the app's chosen permission scope unless the requested feature requires a change.

## Diagnostic cases

Read [diagnostic cases](references/diagnostic-cases.md) when choosing the next experiment or building a regression test. Use the cases that match the observed failure.

## Reference

Start with [Apple privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy) and follow the specific framework's authorization API documentation for states, availability, and prompt behavior.
