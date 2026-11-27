---
name: ios-crash-triage
description: "Diagnose iOS runtime crashes and unexpected process terminations from TestFlight, Xcode Organizer, Apple .ips or .crash reports, or a pasted backtrace. Use for crash symbolication, identifying implicated app code, and verifying a crash fix."
---

# iOS crash triage

Start with the process that actually exited. An extension and its host have separate lifetimes and binaries. Record the build, OS, exception, termination namespace and reason, and relevant thread from the supplied evidence. When working from a snippet, give any conclusion it supports and identify the smallest missing section that would change the diagnosis.

## Choose the evidence that explains the exit

- For an uncaught Objective-C exception, start with the exception reason and Last Exception Backtrace. Follow the throw site through framework frames to the app caller. The abort stack often shows only how the process exited.
- For a Swift trap, read the runtime message and inline frames. Several expressions on the same source line can trap. Inspect the values or preconditions that distinguish them.
- For EXC_BAD_ACCESS, distinguish the faulting memory address from the instruction address. Inspect the failing operation and ownership across its callers. A frame inside a release or collection operation may be where earlier corruption surfaced.
- For a watchdog termination, extract the lifecycle event and elapsed-time allowance from the termination explanation. Follow the main thread's wait to the thread or resource it depends on. The sampled stack captures one instant in the timeout.
- For a jetsam event, identify the victim process, kill reason and memory footprint from its process entry. The largest process may be a different app. Use a memory trace or repeatable workload to narrow down allocations.

## Resolve an app or embedded framework frame

Use existing symbols first. For a raw Apple JSON report, account for the metadata JSON object preceding the report body. In the relevant backtrace, use the frame's imageIndex to select its entry in usedImages. Compute the runtime instruction address as that image's base plus the frame's imageOffset. For translated text reports, take the instruction address printed on the frame and the load address from its Binary Images entry.

For crash-type JSON reports, the bundled [inventory helper](scripts/ips_inventory.py) can extract selected frame and image fields. Run `python3 /absolute/path/to/ios-crash-triage/scripts/ips_inventory.py report.ips` using the path in this skill. The output identifies whether the thread came from `faultingThread` or a unique `triggered` marker. If multiple threads are marked triggered and there is no valid index, inspect the original report to choose the relevant thread. Use the full report for other threads and exception backtraces. The helper reports a hexadecimal runtime address only when both the image base and offset are valid integers. Use the victim process entry directly for jetsam. [Apple’s JSON report format](https://developer.apple.com/documentation/xcode/interpreting-the-json-format-of-a-crash-report)

Locate the matching archive or dSYM from the supplied artifacts. If needed, search local Spotlight metadata with the image UUID in uppercase hyphenated form. An embedded framework has its own UUID and load address.

```sh
mdfind "com_apple_xcode_dsym_uuids == '$image_uuid'"
xcrun dwarfdump --uuid "$dwarf_file"
```

Set dwarf_file to the binary inside the dSYM's Contents/Resources/DWARF directory. Match both the UUID and architecture of the reported image to a listed slice before resolving addresses. A fresh build of the same source can have a different UUID. If symbols are missing, report the required image, architecture and UUID, and continue with the available evidence.

```sh
xcrun atos -arch "$arch" -o "$dwarf_file" -l "$load_address" -i "$instruction_address"
```

Pass addresses in hexadecimal. An echoed address alone is unresolved. Read inline frames together, and check any source line against the revision used to build the binary. [Apple's symbolication guide](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report)

## Close the investigation

Explain the chain from observed termination to the implicated operation. Distinguish what the report proves from the remaining hypothesis. For example, a collection bounds trap establishes an invalid index, while stale selection after an asynchronous list update needs evidence from the caller.

Choose a check that can distinguish the leading explanation from another plausible cause. For a suspected stale selection, remove the selected item between selection and callback, then exercise the same action. When a fix is requested, preserve the intended user behavior and verify that path against the affected configuration. State which checks actually ran and what evidence remains missing.
