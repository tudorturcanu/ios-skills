# Executable routing comparison: all conditions passed

| Condition | Fixed grader | Compilation |
| --- | --- | --- |
| Broken input | 11 / 32 | Passed |
| Reference implementation | 32 / 32 | Passed |
| No specialist skill | 32 / 32 | Passed |
| ios-deeplink-doctor | 32 / 32 | Passed |
| SwiftUI Pro | 32 / 32 | Passed |

The fixed grader compiled and executed every candidate. Source and grader hashes were preserved; original input and harness match the pre-run manifest. All agent reports accurately limit their claims to the synchronous Foundation core and distinguish it from device-level universal-link delivery.

No correctness advantage was observed. The prompt supplied a detailed product contract, which may make specialist guidance less useful. This is a useful regression fixture, not evidence that any skill is best. There was one run per condition and no reliable cost comparison. See [graded results](results.json), each run's grade.json and REPORT.md, and [methodology](README.md).

Next evaluations should test evidence gathering from less prescriptive user requests and larger realistic artifacts, while keeping grading grounded in documented requirements rather than hidden preferences.
