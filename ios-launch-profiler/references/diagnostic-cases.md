# Compare equivalent launch samples

Record samples with configuration, device, OS, install/data state, debugger, network state, measured start/end, and run order. Separate first launch after migration from steady-state process launch. Report sample count and spread alongside a median; small noisy differences are inconclusive.

A change that improves first frame from 500 ms to 350 ms but blocks the first tap for another 400 ms may have moved latency rather than improved usability. Measure both intervals if the deferred operation affects interaction. These numbers are illustrative, not a promised improvement or a measured result.

| Trace evidence | Next question |
| --- | --- |
| Main-thread CPU during decode | Can data volume, format, caching, or optional work be reduced? |
| Main thread blocked on another task | Which dependency or lock prevents progress? |
| Cost dominated by migration | Is this first-install/upgrade behavior represented separately? |
| Improvement disappears without debugger | Were baseline and changed conditions comparable? |

Source inspection can identify candidates; only measurements establish their contribution. Preserve negative results in the report.
