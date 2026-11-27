---
name: ios-accessibility-audit
description: "Audit a SwiftUI or UIKit user flow for accessibility barriers. Use when investigating VoiceOver navigation, Dynamic Type clipping, inaccessible controls, or an Xcode accessibility audit finding."
---

# iOS accessibility audit

Start with the task a person is trying to finish, such as correcting an invalid email and submitting a form. Identify the entry point, the relevant states, and what tells the person they succeeded. For a general request, choose a primary flow from the app and name the scope.

## Follow the interaction

- **VoiceOver.** Trace focus from the first field through submission, validation, and recovery. Can someone distinguish controls, activate each action, discover the error, and return to the right field? Inspect the accessibility tree for the label, value, traits, and actions that native controls already expose. An identifier used by UI tests supplies no spoken description. Check spoken output and focus transitions with VoiceOver when available.
- **Custom controls.** Check gesture-only actions and groups containing multiple buttons. If a row exposes both “Open” and “Favorite,” verify that both actions remain discoverable after grouping. Prefer a native control when its interaction matches. Preserve localized labels and expose changes in state through a value or trait.
- **Dynamic Type.** Compare the default size with the largest accessibility size on a narrow supported screen. Use realistic content. Check whether a person can still read the full message, reach the action, and scroll with the keyboard visible. Trace clipping to its cause, such as a fixed row height, before changing font or layout behavior.
- **Visual cues and touch.** Where the task depends on color, motion, or a small icon, check the actual state change and tappable area. Inspect resolved foreground and background colors in the affected appearance when reporting contrast. For an icon inside a padded button, measure the button’s hit region.

When the task uses custom gestures or animations, exercise the relevant alternative input and Reduce Motion settings. On iPhone Duo, record the active display and pose. Xcode 27.2 Device Hub cannot convey Duo screen content to accessibility tools, so verify spoken output and focus on the physical phone. [Xcode 27.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)

## Gather evidence and verify the fix

Use the [verification matrix](references/verification.md) for task-specific runtime checks.

Use the available project, screenshots, or pasted source. A screenshot can establish visible clipping. Spoken order and focus require runtime verification. With source alone, identify the responsible view and give a specific device check for any uncertain behavior.

For a visual Dynamic Type comparison, navigate a booted iOS simulator to a stable state. From the skill directory run `bash scripts/capture-dynamic-type.sh <device-UDID> <new-capture-directory>` with the UDID from `xcrun simctl list devices booted`. The helper captures Large and the maximum accessibility text size as PNGs and restores the original size. On a dual-display simulator, use `xcrun simctl io <device> enumerate` to identify the active display and pass its ID as the optional third argument so both screenshots target the same display. Inspect both images. If navigation changed, loading is still in progress, or the app overrides the system size, reproduce the state at each size and verify it before drawing conclusions.

In a runnable project, reuse its scheme, test fixtures, and navigation helpers. Wait for a distinctive element in the target state before running an Accessibility Inspector audit or calling `try app.performAccessibilityAudit()` in a supported XCTest UI test. For example, submit invalid input and wait for the error before auditing the form. Each audit covers the current screen state. Pair it with a task walkthrough for focus, announcements, and completion. [Apple’s audit guide](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) · [Apple’s accessibility testing guide](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app)

Lead with barriers that prevent completion. For each finding, give the affected task, reproduction steps or source location, observed evidence, and the smallest correction that addresses the cause. When asked to fix it, apply the correction and repeat the same interaction under the setting that exposed it. State which runtime checks ran and which still need a device.
