# App Store audit: ReceiptBox 1.4.0 (57)

Audit date: 2026-11-27. Intended submission date: not stated. Regions: not stated.
Scope: focused source audit of the provided files, triggered by the ITMS-91053 email. Not a full submission audit.
Evidence reviewed: CONTEXT.md, REVIEW_NOTES.txt, Info.plist, PrivacyInfo.xcprivacy, Sources/ReceiptStore.swift, Sources/ScannerView.swift. These are the only files; no archive, no project file, no git revision (source revision and dirty state unknown).
Policy currency: UNVERIFIED. This review was restricted to local files, so no Apple page (Review Guidelines, privacy manifest / required-reason API documentation, Connect Help) was retrieved. The source register is empty. Reason codes below come from memory and must be confirmed on Apple's page before use.

## Conclusion

- Inspected scope: **blockers found.** One confirmed processing blocker, ASA-001. The Apple email confirms the validation failure, so it is a factual fact rather than a policy judgment. The exact fix value is unverified against current docs.
- Submission verification: **incomplete.** Archive, runtime, Connect and policy-currency checks remain (listed below).

## Finding

### ASA-001 (Blocker): file-timestamp required-reason API is used but not declared in the privacy manifest
Linked checks: C-01, C-02, C-03.

Observed:
- `Sources/ReceiptStore.swift:26-27` requests `.contentModificationDateKey` in `contentsOfDirectory(at:includingPropertiesForKeys:)`.
- `Sources/ReceiptStore.swift:32-33` calls `fm.attributesOfItem(atPath:)[.modificationDate]` to sort receipts by file modification date.
- `PrivacyInfo.xcprivacy:11-21` declares only `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. There is no `NSPrivacyAccessedAPICategoryFileTimestamp` entry.

Why it applies: reading file modification dates is, to my knowledge, in Apple's required-reason API list under the file timestamp category. A missing category matches the ITMS-91053 "Missing API declaration" email. The team's belief that "a manifest was added" is correct but incomplete. The manifest covers UserDefaults only (used at `ReceiptStore.swift:5,13-14`), not file timestamps.

Remediation: add a second entry to `NSPrivacyAccessedAPITypes`:
```
<dict>
  <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
  <key>NSPrivacyAccessedAPITypeReasons</key><array><string>C617.1</string></array>
</dict>
```
C617.1 is, from memory, the reason for accessing timestamps/metadata of files inside the app's own container. The code reads only files in the app's Documents directory (`ReceiptStore.swift:8-10`), which would fit. Confirm the category name and exact reason wording in Apple's current required-reason API documentation before applying. Do not pick a reason merely to pass validation. Also read the full email: it may list more than one category or file, and ITMS-91053 can enumerate multiple missing declarations.

Verification: confirm the reason in Apple's docs; rebuild; check the `.xcprivacy` is in the app target's bundle resources (see gap G-1); re-upload and confirm no ITMS-91053 email.

## Other observations (not blockers)

- **R-1 (Risk, provisional): PDF generation is a stub.** `ScannerView.swift:25` calls `onFinish(Data())` with the comment "PDF rendering omitted in this excerpt". If the shipped build does the same, scans save empty PDFs. That is a completeness/functionality issue (likely Guideline 2.1, unverified here). If the file is only an excerpt, dismiss it. The call site and the real shipping code were not provided.
- **Rec-1 (Recommendation):** `ReceiptStore.swift:32-33` re-reads attributes with `attributesOfItem` although `contentModificationDateKey` was already prefetched at line 27. Using `resourceValues(forKeys:)` would be cleaner and cut file-system calls. This is an engineering suggestion, not a requirement. It still uses the file timestamp category, so ASA-001 stands.
- **Rec-2:** `ReceiptStore.swift:19` filenames come from a `name` parameter; check it is sanitized (path characters). Not an App Store rule.

## Checks

| ID | Area | Criterion | Boundary | Evidence | Outcome |
|---|---|---|---|---|---|
| C-01 | Privacy manifest | Every required-reason API used in source has a matching manifest category | Source | ReceiptStore.swift:27,32-33 vs PrivacyInfo.xcprivacy:11-21 | **Fail** (confirmed by Apple email; docs not retrieved, so rule text unverified) |
| C-02 | Privacy manifest | UserDefaults declaration present with permitted reason | Source | PrivacyInfo.xcprivacy:14-18; use at ReceiptStore.swift:13-14 | Pass for presence; CA92.1 (app's own defaults) appears consistent with usage; exact wording Unverified |
| C-03 | Privacy manifest | Manifest is packaged in the built app | Archive | Not available | Unverified |
| C-04 | Privacy manifest | Tracking/collected data declarations match behavior | Source | NSPrivacyTracking false, no domains, no collected types; no network code seen; ReviewNotes claim no network | Pass for provided files; Connect App Privacy answers Unverified |
| C-05 | Permissions | Camera purpose string present and specific | Source | Info.plist:15-16 | Pass (source); runtime prompt Unverified |
| C-06 | Launch | Launch screen key present | Source | Info.plist:19-20 `UILaunchScreen` | Pass for key presence (TN3208 not retrieved) |
| C-07 | Lifecycle | Scene-based lifecycle adopted in release app | Source/Archive | No app entry point or scene manifest provided; SwiftUI likely | Unverified |
| C-08 | Encryption | Export compliance matches actual crypto | Source | Info.plist:17-18 false; only first-party frameworks per CONTEXT.md; dependency list not seen | Unverified (plausible) |
| C-09 | Version | Version/build consistent with notes | Source | Info.plist 1.4.0 (57) matches REVIEW_NOTES.txt | Pass (source only) |
| C-10 | Review access | No login needed; setup described | Source/Connect | REVIEW_NOTES.txt:3-5 | Pass for description; runtime reachability Unverified |
| C-11 | Functionality | Scan produces valid PDF | Source | ScannerView.swift:25 stub | Unverified (R-1) |
| C-12 | Third-party SDKs | No SDK manifest/signature obligations | Source | CONTEXT.md claims none; no lockfile | Unverified |

Coverage by area: privacy manifest (1 Fail, 3 Pass-limited, 1 Unverified); permissions/launch/version/review notes Pass at source level; lifecycle, encryption, SDKs, functionality Unverified.

## Verification gaps (what I could not verify from these files)

1. The Apple email text and the intended archive: whether it lists more categories, and whether the `.xcprivacy` is in the target's Copy Bundle Resources (G-1). Needed: the email and the .xcarchive's `PrivacyInfo.xcprivacy`. This decides whether ASA-001 is the whole problem.
2. Apple's current required-reason API documentation (file timestamp category, C617.1 wording, effective dates): not retrieved. Needs a connected session.
3. Project file/build settings: SDK/Xcode used, deployment target (Info.plist says 17.0), scene manifest, signing. Not provided.
4. App Store Connect: App Privacy answers (should be no data collected if accurate), privacy policy URL, age rating questionnaire (deadline details not retrieved), screenshots, metadata, export compliance, regions, DSA trader status if EU.
5. Runtime: camera permission prompt, scan to PDF, sort behavior, on a device. Source cannot establish these.
6. Full source: other files in the app (not provided) may use further required-reason APIs (disk space, boot time, system uptime). Only these two Swift files were checked; others could add more declarations.

## Recommended changes, in order

1. Add the file timestamp category with the confirmed reason (ASA-001); read the full Apple email for other categories.
2. Confirm the manifest ships in the archive; rebuild and upload build 58 (build 57 is already uploaded).
3. Confirm real PDF rendering is in the shipping code (R-1).
4. Complete the Connect and runtime checks above before submitting.
