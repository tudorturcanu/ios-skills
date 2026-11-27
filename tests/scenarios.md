# Behavioral evaluation scenarios

These are evaluation specifications, not records of executed agent tests. Give an agent the prompt, the named skill, and the fixture described below. Keep expected behavior out of its input. Evaluate observable output and repository changes. Use temporary projects and synthetic data; no production purchases or user stores are needed.

| Skill | Prompt and fixture | Observable success criteria |
| --- | --- | --- |
| ios-deeplink-doctor | “Fix a product link that opens login but never opens the product afterward.” Provide a parser and a coordinator that discards pending routes when authentication is required; include a valid AASA fixture. | Preserves the route through login, consumes it when navigation is ready, handles repeated delivery deliberately, and tests signed-in/out paths. Does not rewrite AASA without evidence or use a timed sleep. |
| ios-accessibility-audit | “Audit checkout accessibility.” Supply a quantity stepper with unnamed image controls, a combined row hiding independent actions, and a fixed-height error label. No running device. | Identifies task impact and specific source locations, proposes scoped semantics/layout fixes, and marks spoken output, traversal, focus, and rendering unverified. Does not claim VoiceOver passed. |
| swiftdata-migration-checker | “Verify this migration preserves customer records.” Provide V1 with optional nickname, V2 with renamed displayName, and only a current-schema in-memory test. | Recognizes missing historical on-disk evidence, preserves V1, proposes or creates an old-schema fixture with nondefault values, tests semantic preservation and reopen. Does not delete the store or call the current test sufficient. |
| storekit-entitlement-debugger | “Fix access that remains unlocked after refund.” Supply a reducer that only inserts verified product IDs and a synthetic sequence of entitled then empty snapshots. | Reconciles removal as well as addition, preserves explicit loading/error states, tests the transition, and distinguishes StoreKit snapshots from transport failure. Does not grant from unverified transactions or use consumable balances from currentEntitlements. |
| ios-localization-audit | “Find missing translations.” Supply Text("Save"), Text(verbatim: dynamicMessage), an intentional nontranslatable key, nested plural variations with one draft translation, and positional placeholders reordered in another locale. | Does not flag every SwiftUI literal, inspects nested variants, respects nontranslatable entries and reordered placeholders, identifies the actual draft and verbatim risk, and does not mark translations reviewed automatically. |
| ios-crash-triage | “Tell me the cause of this crash.” Provide an unsymbolicated .ips report with binary UUID A, a dSYM with UUID B, and a framework at the top of the stack. | Reports symbol mismatch, avoids invented source frames, classifies what the report supports, and asks for the exact missing symbols or discriminating diagnostics. Does not claim the framework caused the crash. |
| ios-launch-profiler | “Make startup faster.” Supply source with synchronous decoding but no device or trace. | Identifies a candidate bottleneck, proposes a repeatable measurement plan, and reports that improvement is unmeasured. No fabricated milliseconds or claim that moving work into a task proves success. |
| ios-offline-sync-review | “Fix duplicate orders after losing connectivity.” Supply a fake server that commits before timing out and a durable outbox that retries POST without an operation ID; no server deduplication contract. | Reproduces duplicate effects or explains the evidence, identifies ambiguous acknowledgment, and requires a real server idempotency contract. Does not claim a client-only retry flag guarantees exactly-once behavior. |
| ios-permission-flow-tester | “Fix photo access that stays blocked after Settings changes.” Provide cached denied status and code treating limited access as denied. | Re-queries framework status at the appropriate lifecycle boundary, treats limited access according to feature needs, tests recovery, and distinguishes simulator versus hardware evidence. Does not force broader access unnecessarily. |
| widget-data-consistency | “Fix a widget showing the previous account.” Supply a shared snapshot without account identity and code requesting reload before writing. | Corrects snapshot identity/write ordering and account invalidation, tests provider reads after switching, and acknowledges that already-rendered content may persist until the system refreshes. Does not promise immediate removal from a reload call. |

## Routing and scope checks

- “Change the paywall button color” should not initiate an entitlement audit.
- “Reduce Xcode compilation time” should not select ios-launch-profiler.
- “Review this Core Data migration” should not pretend SwiftData migration APIs apply.
- “Audit accessibility; do not edit” must produce findings without modifying the app.
- “Translate this one label into French” should not expand into an app-wide localization overhaul.
- “The app crashes right after the splash screen” should start with ios-crash-triage (a termination report exists), not ios-launch-profiler; “the app takes four seconds to show the first screen” should select ios-launch-profiler, not crash triage.
- “Restore Purchases does nothing” should select storekit-entitlement-debugger; “my App Store submission was rejected for a missing restore button” should select app-store-audit.
- “Tapping a notification should open a screen” is routing inside the app: ios-deeplink-doctor applies only if a URL or universal link is involved.
- “The widget shows old data” should select widget-data-consistency; “the widget looks wrong in Dynamic Type” should select ios-accessibility-audit.
- “Memory warning on launch” should select ios-launch-profiler or ios-crash-triage depending on whether a termination report exists; ios-memory-growth requires a repeatable interaction that grows memory.
- “Why does the app open on the wrong display on iPad?” should not select iphone-duo-design.
- A clean control (correct code and artifacts for the named skill) should produce a report of no confirmed defect and list what was not verified, not invented findings.

For each execution, record model/tool environment, input fixture revision, observed actions, pass/fail per criterion, and missing capabilities. Packaging checks do not substitute for these behavior tests.
