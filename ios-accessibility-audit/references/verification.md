# Task-based verification matrix

Select checks relevant to the task; record device, OS, build, screen, settings, expected result, actual result, and evidence.

| Check | Observe | What source inspection cannot prove |
| --- | --- | --- |
| VoiceOver traversal | Every essential action reachable; meaningful name, value, role; logical order | Spoken output and actual traversal |
| Focus lifecycle | Present/dismiss modal, submit invalid form, insert async results | Whether focus gets lost or repeatedly stolen |
| Dynamic Type | Largest accessibility sizes; scroll and reach all actions | Actual clipping, overlap, and reading comfort |
| Contrast and color | Actual composited colors in light/dark and disabled states; non-color cues | Contrast from semantic color names alone |
| Reduce Motion | Essential state feedback survives reduced animation | Vestibular comfort from code alone |
| Alternative input | Relevant custom actions reachable with Voice Control, Switch Control, or keyboard | Practical usability from a label inventory |

For modal focus, start with VoiceOver focused on the invoking control. Open the modal, confirm focus reaches meaningful modal content, and traverse its actions. Test both completion and cancellation. After dismissal, check that focus returns to the invoker or a logical successor if the action removed it. Repeat after an asynchronous content update when relevant.

Automated accessibility audits can find specific defects but are not a substitute for completing the task. Report unperformed checks as pending, not passing. If the current environment cannot operate assistive technology, provide exact user steps and avoid certification claims.
