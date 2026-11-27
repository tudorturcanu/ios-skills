---
name: ios-memory-growth
description: Diagnose rising memory use across repeated iOS interactions, such as opening and dismissing a picker. Use for retained SwiftUI models or UIKit controllers, growing caches, and before-and-after memory investigations.
---

# iOS memory growth

Choose one repeatable interaction and define which objects should be released when it finishes. Record the build, device, data set, and a point where pending animations, callbacks, and image decoding have settled. Warm up once. Measure at that same idle point after several identical cycles. Keep peaks during the interaction separate from live allocations after dismissal.

Use Instruments Allocations generations to find types whose surviving count grows each cycle. For a suspected model or controller, inspect incoming references in Xcode’s memory graph after dismissal. Record a concrete ownership path and where its lifetime should end. A plateau can indicate a bounded cache. Resident memory alone cannot establish an ownership defect. If Swift objects disappear while footprint grows, inspect allocations such as decoded images and graphics buffers.

To classify recorded counts, transcribe the settled surviving counts per cycle into the [generations format](references/generations-format.md) and run `python3 scripts/compare_generations.py <counts.json>` from this skill directory. It lists types that grow every cycle, separates plateaus from steady growth, and skips unsettled samples. Treat its output as a pointer to which type to trace, not as proof of an owner.

When generations overlap, capture an additional sample after all work for the last cycle should finish. Compare settled counts at increasing cycle numbers. Growth that stops after outstanding tasks finish points to overlapping work. Growth that survives dismissal and quiescence warrants tracing a retained owner or cache key. For caches, try both a repeated input and different inputs to distinguish reuse from growth per item.

Choose the fix at the owner boundary. For example, a coordinator may need to remove a finished child, a subscription may need cancellation, or a stored closure may capture its owner. Check that pending work can still complete and the screen still behaves correctly. Repeat the original measurement with identical inputs. Report cycle count, surviving instances or bytes before and after, and any unresolved growth. If only source is available, describe the suspected path and the measurement needed to confirm it.

Measure on a representative physical device when evaluating memory limits or jetsam risk. Simulator measurements can expose retained objects. Use device measurements to establish pressure and termination behavior. If the issue changes after a toolchain update, compare build SDK and runtime separately. Xcode 27 changes how SwiftUI evaluates `@State` initial values, with the change back-deployed to iOS 17. Check persistent instance counts before attributing repeated initialization to retention. [iOS and iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)

On Xcode 27.3 beta, check the installed `xctrace` help for Allocations, Leaks, and VM Tracker recording options. Keep the template and options in the baseline record so that different sampling or allocation settings do not look like a regression. [Xcode release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_3-release-notes)

For a runnable teaching example, run `swift examples/PickerLifetime.swift` from this skill directory. The [Swift fixture](examples/PickerLifetime.swift) checks the surviving model count for two closure capture strategies. Use actual project traces for app-specific findings. [Apple’s memory debugging guide](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
