# Evidence checklist

These are investigation prompts, not independent requirements. Verify live Apple rules and exceptions before recording failures. Add checks introduced by the current guidelines or app features.

## Release artifact

Inspect project/workspace or generated configuration, release schemes/settings, Info.plist inputs, entitlements, assets, dependency lockfiles, and available archive/export logs. Resolve generated values and build-script changes. Compare actual SDK/toolchain, minimum OS, and device families with dated submission rules. Inspect identifiers, versions, app/extension relationships, signing/capabilities, embedded frameworks, and packaging against current validation requirements.

Check the launch screen in the built app’s Info.plist. Uploads built with the iOS 27 SDK or later require one of the launch-screen keys listed in [TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements). Verify scene-based lifecycle adoption in the release app and launch it on an applicable OS. For UIKit, trace the resolved scene manifest and scene configuration. [UIKit scene transition](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)

Use [artifact-inspection.md](artifact-inspection.md) for command examples and interpretation limits. Inspect bundled manifests and actual dependencies; record artifact provenance separately from version/build labels. Keep archive validation and upload results as separate checks.

For a beta toolchain, confirm that Apple lists the exact version and intended upload channel. TestFlight acceptance does not establish App Store submission eligibility. [Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)

## Privacy and data flow

Inventory first-party code, SDKs, backend calls, analytics/ads, and external AI services. Trace data through recipients and retention, including remote feature flags and environment-specific endpoints. If server configuration or partner behavior is unavailable, mark those portions unverified rather than inferring them from a client default. Compare behavior with App Privacy answers, policy text, manifests, prompts, and observed traffic when available.

- Inspect sensitive-resource purpose strings/localization, permission timing, denial paths, and behavior before consent.
- For required-reason API candidates, verify actual use and the exact allowed reason in current Apple documentation. Do not invent codes or select a reason solely to pass validation.
- Inspect transitive/shipped SDK manifests and signatures under the current SDK rules.
- A manifest does not replace Connect disclosures. Establish whether tracking occurs before evaluating the prompt. For affected EU releases, verify the actual App Tracking Transparency flow on iOS or iPadOS 27.2 and later, including the applicable system prompt and the app’s behavior after denial. Record the OS and distribution region. [Apple’s EU tracking guidance](https://developer.apple.com/app-store/user-privacy-and-data-use/#att-in-the-european-union)
- Do not infer “no collection” from absent analytics code. Servers, logs, WebViews, and partners need evidence.

## Accounts

Trace onboarding, login alternatives, creation, and deletion. Check the current login-service rule and exceptions before requiring a provider. Verify deletion end to end, backend effects, retention explanations, and relevant token revocation. Logout or a UI-only delete button does not establish deletion. Use test accounts for destructive flows.

## Commerce

Classify digital functionality/content, physical goods, services, and other business models. Establish storefront and program conditions before evaluating payment routing or external links.

For purchases/subscriptions, compare product IDs/configuration, localized price and period, trial/renewal terms, entitlement delivery, restoration where applicable, management/cancellation access, and terms/privacy links. Exercise successful, cancelled, pending, failed, restored, and expired states with available test tooling. A local StoreKit configuration does not prove Connect products or production receipt handling are ready.

## Runtime and reviewer access

Exercise release flows, including first launch, login, loading/empty/error states, permissions, purchases, and backend connectivity. Inspect device-family layouts, OS compatibility, accessibility, and localization. State actual devices/environments tested and distinguish fresh install from upgrade when retained permissions, credentials, or migrated data affect a finding. Sample representative combinations based on affected flows; do not extrapolate one account, locale, device, or storefront to all supported combinations without evidence.

Check reviewer access, hardware/setup needs, feature navigation, and review notes. Evaluate completeness, functionality, metadata accuracy, content rights, and hidden behavior against applicable rules. Static inspection does not establish runtime behavior.

When sign-in matters, start without an active session and follow the exact reviewer setup using an authorized demo account or the submitted demo mode. Check required roles and sample data, any second factor or special setup, and access to the screens under review. For purchase review, check that the demo entitlement state exposes the purchase flow. Record credential validity and observed reachability without including credentials in the report. [Apple’s complete review guidance](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)

## Store metadata and Connect

Compare release behavior with descriptions, screenshots/previews, localized fields, support/privacy URLs, categories, age-rating answers, availability, and review details. Open links and inspect media; filenames are insufficient. Fetch current field and asset specifications, including the SDK and effective date for iPhone Duo screenshots where applicable. If the product page advertises accessibility support, verify each claim against Apple’s criteria and the relevant app tasks on that platform.

Compare the current age-rating questionnaire with reachable features, including Shared Location and Dating and Relationships. Check updated answers when submitting an update or editing the questionnaire. Apple’s November 19 Connect release notes give January 12, 2027 as the deadline for all apps. Verify storefront-specific results and any documented override, including Brazil’s A16 and A18 classifications. If you only have source, report the features observed and leave the submitted answers unverified. [Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/) · [Descriptor definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

Inspect agreements and commerce configuration when evidence/access exists. Determine encryption declarations from actual cryptography, including dependencies; never set exemption flags merely to bypass a questionnaire. Verify regional trader and other declarations against business evidence or Connect state.

## Conditional feature routing

| Trigger | Investigate under current feature-specific rules |
| --- | --- |
| User content/social features | Moderation, reporting, blocking, support, age controls |
| Children/age-sensitive features | Audience, recipients, parental mechanisms, advertising, regional obligations |
| AI/third-party processing | Data destinations, disclosure/consent, content, product claims |
| Health/finance/gambling/crypto/regulated services | Claims, responsible entity, licenses, territories, program evidence |
| Downloaded software/mini apps/emulation/browser engines | Execution model, native API access, content, program conditions |
| Location/background/push/VPN/hardware | Purpose, actual use, controls, capability eligibility |
| Extensions/widgets/App Clips/watch/other targets | Per-target bundles, capabilities, data sharing, platform rules |

## False-positive controls

- Missing text matches do not prove missing generated configuration or functionality.
- Do not require accounts, subscriptions, tracking prompts, or one login provider universally.
- Do not extend regional exceptions worldwide or mix distribution-channel rules.
- A rejection establishes Apple's stated concern, not unrelated violations.
