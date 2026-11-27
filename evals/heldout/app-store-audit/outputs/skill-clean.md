# App Store Audit: ReceiptBox 1.4.0 (57), source-only review

Audit date: 2026-11-27. Intended submission date and regions: not stated. Source revision: none (loose files, no VCS info). Distribution: App Store, iOS 17+.

## Scope and evidence boundary
Read-only review of CONTEXT.md, REVIEW_NOTES.txt, PrivacyInfo.xcprivacy, Info.plist, Sources/ReceiptStore.swift and Sources/ScannerView.swift. Nothing was built or run. No archive, Connect, or backend access.

Policy currency: I did not retrieve Apple's live pages (apple-sources.md list) in this session, so currency of rules is **unverified**. Reason codes below are cross-checked against my knowledge of Apple's privacy-manifest documentation and should be re-confirmed at https://developer.apple.com/documentation/bundleresources/privacy-manifest-files before upload. No violation is asserted that depends on an unretrieved rule.

## Conclusions
- **Inspected scope: no blockers found in inspected scope.** The ITMS-91053 concern appears addressed in the manifest source.
- **Submission verification: incomplete.** Archive, Connect, and policy-currency checks remain (see list).

## Checks

| ID | Area | Criterion | Boundary / evidence | Outcome |
|---|---|---|---|---|
| C-01 | Privacy manifest | Every required-reason API actually used is declared (UserDefaults, file timestamp) | Source: ReceiptStore.swift:5,13,14 (UserDefaults); :27 (`.contentModificationDateKey`) and :32-33 (`attributesOfItem ... .modificationDate`); PrivacyInfo.xcprivacy:13-28 | Pass (source). No other required-reason category (boot time, disk space, system uptime) found in the 3 Swift/plist sources provided |
| C-02 | Privacy manifest | UserDefaults reason fits use | `CA92.1` (app-only access) at xcprivacy:18; usage reads/writes own key "sortOrder" (ReceiptStore.swift:13-14) | Pass (source) |
| C-03 | Privacy manifest | File-timestamp reason fits use | `C617.1` at xcprivacy:26 covers timestamps of files inside the app/group/CloudKit container. Files are in `.documentDirectory` (ReceiptStore.swift:9), written by the app itself (:17-19); CONTEXT.md:11-13 states nothing is read from external or user-picked locations. `3B52.1` (user-granted files) and `0A2A.1` do not apply | Pass (source), conditional on the CONTEXT.md claim being true in the whole build |
| C-04 | Privacy manifest | Tracking/collection declarations consistent with code | xcprivacy:5-10 (no tracking, no collected data); no network or analytics code in the files; REVIEW_NOTES.txt:7-8 | Pass for provided files. Whole-binary claim unverified (C-12) |
| C-05 | Privacy manifest | Manifest is bundled in the app target and valid in the archive | Only a loose file is available | Unverified |
| C-06 | Permissions | Camera purpose string present and specific | Info.plist:15-16 | Pass (source) |
| C-07 | Permissions | Camera permission requested in context, denial handled | System prompt triggered by VNDocumentCameraViewController (ScannerView.swift:4-5,10). Denial/unsupported-device UI not in provided files (`VNDocumentCameraViewController.isSupported` not checked) | Unverified (runtime) |
| C-08 | Build config | Encryption declaration matches actual crypto | Info.plist:17-18 `ITSAppUsesNonExemptEncryption=false`; no network or crypto in provided code, first-party frameworks only (CONTEXT.md:3-4) | Pass (source); full binary/dependency check unverified |
| C-09 | Build config | Launch screen key present | Info.plist:19-20 `UILaunchScreen` | Pass (source). Info.plist is a partial excerpt, final merged plist unverified |
| C-10 | Build config | Version/build/min OS consistent with notes | Info.plist:9-14 vs REVIEW_NOTES.txt:1 (1.4.0 / 57) and CONTEXT.md:3 (iOS 17+) | Pass (source). Note Info.plist lacks CFBundleExecutable, CFBundlePackageType, etc., so it is evidently not the generated final plist (`MinimumOSVersion` is also normally injected at build) |
| C-11 | Build/SDK | Built with SDK/Xcode currently required for uploads; scene-based lifecycle | No project file or archive provided. SwiftUI sources suggest SwiftUI lifecycle but the `@main` App file is absent | Unverified |
| C-12 | Privacy | App Privacy answers in Connect, privacy policy URL, match "no data collected" | Not provided | Unverified |
| C-13 | Review access | Review notes enable reaching all features | REVIEW_NOTES.txt:3-5: no login, scan flow described. A reviewer on a device or simulator without a camera cannot scan | Pass for credentials (none needed); feature reachability unverified at runtime |
| C-14 | Completeness | Scanner produces real PDFs | ScannerView.swift:25 `onFinish(Data())` with comment "PDF rendering omitted in this excerpt" | Unverified (see ASA-002) |
| C-15 | Metadata | Screenshots, description, age rating (including updated questionnaire), support URL, availability | Not provided | Unverified |
| C-16 | Other | Accounts, commerce, UGC, AI, kids, regulated features | None indicated by the files (CONTEXT.md:3-4, REVIEW_NOTES.txt:7-8) | Not applicable on provided evidence |

## Findings

**ASA-001 (Recommendation): "Sort setting" is stored but never applied.**
Linked: C-14. ReceiptStore.swift:12-15 stores `sortOrder`, but `receipts()` (:24-36) always sorts by modification date and never reads it. REVIEW_NOTES.txt:4 says "The sort setting is stored locally", so a reviewer may look for a sort control. Not a rule violation. Remediation: either honor `sortOrder` in `receipts()` or remove the setting and adjust the notes. Verification: confirm in UI that the control exists and changes order.

**ASA-002 (Risk, provisional): Placeholder PDF output in the submission files.**
Linked: C-14. ScannerView.swift:25 passes an empty `Data()` to `onFinish`, and the comment says rendering is omitted "in this excerpt". If this is only a trimmed excerpt, there is no issue. If it is the shipped code, the core feature would save empty/invalid PDFs, which risks rejection for app completeness (Guideline 2.1). I have not retrieved the live guideline text this session, so the rule citation is unverified. Remediation: confirm the release build renders scan pages into a PDF (e.g., PDFKit/UIGraphicsPDFRenderer over `scan.imageOfPage(at:)` for each page). Verification: scan a multi-page receipt on a release build, open the saved PDF.

**ASA-003 (Recommendation): Timestamp lookup is inefficient and redundant.**
ReceiptStore.swift:27 prefetches `.contentModificationDateKey`, but the sort (:32-33) calls `attributesOfItem` twice per comparison, which hits the file system repeatedly. Use `url.resourceValues(forKeys:)` once per file, then sort. Both APIs map to the same required-reason category, so the manifest does not change. Optional engineering improvement, not a requirement.

**ASA-004 (Recommendation): Camera-unavailable path.**
ScannerView.swift:10 creates the controller without checking `VNDocumentCameraViewController.isSupported`, and no denied-permission handling is visible. Reviewers on simulators could hit a dead end. Optional guidance; add a graceful message and mention in review notes if relevant.

## About the earlier ITMS-91053
The manifest now declares both categories the code uses (UserDefaults CA92.1 and FileTimestamp C617.1). C617.1 is the correct reason for timestamps of app-container files, matching the documented context. Nothing in the provided files suggests the declarations are missing or wrong. I would not change the reasons. Do not add 3B52.1 or other reasons "to be safe". Whether the email is fully resolved depends on the re-upload processing result and on the manifest actually being in the archive (C-05). If the app target contains other code (the files here are an excerpt) that touches timestamps outside the container, or uses other required-reason APIs, the declarations must be revisited.

## Remaining verification (ordered by blocking risk)
1. Archive/validation: confirm `PrivacyInfo.xcprivacy` is in the built .app and the merged Info.plist contains the keys above (Xcode organizer validation or `codesign`/`plutil` on the archive). Then re-upload and check for a repeat ITMS-91053 or other ITMS-91xxx email.
2. Full source scan of the real target for other required-reason APIs (file size/disk space, system boot time, etc.) beyond the three provided files; the review covered only provided files.
3. Release-build runtime test: scan flow, produces valid PDFs, camera denied state, listing order (ASA-001/002).
4. App Store Connect (role: Admin/App Manager): App Privacy "Data Not Collected" answers, privacy policy URL, age-rating questionnaire (check current deadline in Connect release notes), screenshots meeting current specs, export-compliance answers, review notes entry.
5. Policy currency: retrieve the current App Review Guidelines, Submitting, Upcoming Requirements and privacy manifest pages and confirm Xcode/SDK minimum for the planned upload date and the C617.1/CA92.1 definitions.

## What I would change
- Nothing in PrivacyInfo.xcprivacy.
- Make sure the real PDF rendering ships (ASA-002); honor or remove `sortOrder` (ASA-001); minor cleanups ASA-003/004.

## Source register
No Apple pages retrieved in this audit (browsing not used). Sources to open are listed in the skill's apple-sources.md. All rule statements above are marked unverified for currency.
