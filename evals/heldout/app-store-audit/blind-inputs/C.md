# ReceiptBox 1.4.0 (57) - Submission readiness review (read-only)

## Verdict
No blocking privacy-manifest or metadata problem found in the files provided. The ITMS-91053 cause appears resolved: every required-reason API visible in the source is declared with a reason that matches the documented usage. Remaining items are minor or cannot be verified from these files.

## Required-reason API cross-check (the earlier ITMS-91053)
| API use in source | Category | Declared in PrivacyInfo.xcprivacy | Verdict |
|---|---|---|---|
| `UserDefaults.standard` get/set, ReceiptStore.swift:5, 13-14 | UserDefaults | lines 14-19, reason CA92.1 | Correct. CA92.1 is for the app's own defaults, and the key `sortOrder` is app-private. |
| `contentModificationDateKey` (ReceiptStore.swift:27) and `attributesOfItem ... .modificationDate` (line 32-33) | File timestamp | lines 21-27, reason C617.1 | Correct. C617.1 covers timestamps of files inside the app container. CONTEXT.md lines 11-13 documents that only self-created PDFs in Documents are read. Documents is the app container (line 9). |
| `Data.write(.atomic)` (line 19), `contentsOfDirectory` (line 25) | not required-reason categories | n/a | Nothing to declare. |
| No uses found of system boot time, disk space or active keyboard APIs | n/a | n/a | No missing declaration in the visible source. |

Other manifest checks:
- `NSPrivacyTracking` is false, with empty tracking domains and empty collected data types (lines 5-10). This is consistent with REVIEW_NOTES.txt:7-8, the no-network claim, and the first-party-only frameworks in CONTEXT.md:3-5.
- The plist is well formed and the keys are correct.
- The reason strings are valid codes, and no extraneous reason is declared.

## Findings
1. Placeholder scan output (Low to Medium, only if shipped as is). ScannerView.swift:25 calls `onFinish(Data())` with the comment "PDF rendering omitted in this excerpt". If the real build matches this, every scan saves an empty PDF, which risks a guideline 2.1 (app completeness) rejection. The file is probably a trimmed excerpt, so confirm that the shipped source renders `scan` into PDF data.
2. No camera-availability check (Low). ScannerView.swift:9-12 never checks `VNDocumentCameraViewController.isSupported`. On a device or simulator without camera support, tapping Scan could fail or show a blank screen. Reviewers sometimes test on unusual configurations, so add a guard and a fallback message.
3. Placeholder bundle ID (Low, verify). Info.plist:6 is `com.example.receiptbox`. This must match the App Store Connect record and the signing profile. An `com.example` ID is typically not a registered one.
4. Sort setting is unused (Low, quality). `sortOrder` (ReceiptStore.swift:12-15) is stored, but `receipts()` (lines 24-36) always sorts by modification date. REVIEW_NOTES.txt:4 says "The sort setting is stored locally", so a reviewer who looks for a working sort option will not find one in this code.
5. Inefficient sort (Low, performance). `receipts()` requests `contentModificationDateKey` (line 27) but ignores it. The comparator instead calls `attributesOfItem` twice per comparison (lines 32-33), which means repeated disk hits. Read each date once, then sort. This also reduces timestamp-API call sites.
6. Unsanitized filename (Low). `save(pdf:name:)` (line 18) interpolates `name` into a path. If the name ever comes from user input or OCR text, characters like `/` or `..` could escape or collide. Sanitize the name and avoid overwrites.
7. Info.plist is minimal (Informational). The plist has no CFBundleExecutable, CFBundlePackageType or icon keys, and `MinimumOSVersion` is normally generated from the deployment target. This is probably an excerpt and the Xcode build will merge its generated values. Confirm that the archived build has them.

## Things that look correct
- `NSCameraUsageDescription` is present with a clear purpose string (Info.plist:15-16), as required for VisionKit camera scanning.
- No photo library, location or microphone usage is present in the code, so no further usage strings are needed.
- `ITSAppUsesNonExemptEncryption` is false (Info.plist:17-18). This is consistent with no network or custom crypto use, and it avoids the export-compliance prompt.
- Review notes say no login is needed and give clear steps (REVIEW_NOTES.txt:3-5). Privacy claims are consistent with the manifest and source.

## Could not verify from these files
- That PrivacyInfo.xcprivacy is actually a member of the app target and ends up in the archived .app bundle. A manifest that is missing from the bundle would still trigger ITMS-91053.
- That the full source tree has no other required-reason API use, such as other file timestamp calls, `systemUptime`, `volumeAvailableCapacity` keys, or UserDefaults use in other files. Only two Swift files were provided.
- That no third-party code or embedded framework is present, which would need its own manifest and signature (ITMS-91061). CONTEXT.md claims there is none.
- App Store Connect items: App Privacy nutrition-label answers (should be "Data Not Collected"), privacy policy URL, screenshots, age rating, app icon and asset catalog, support URL, and category.
- Signing, entitlements, supported device families and orientations, and Info.plist keys generated at build time.
- That the actual build 57 matches these files.

## What I would change
1. Verify the shipped PDF rendering code (finding 1) and add an `isSupported` guard (finding 2).
2. Confirm PrivacyInfo.xcprivacy is in the target's Copy Bundle Resources and appears at the root of the archive. Run a validation or inspect the archive's manifest.
3. Replace the `com.example` bundle ID with the registered one, if it is not already.
4. Either honor `sortOrder` in `receipts()` or remove the claim from the review notes. Read modification dates once during the sort.
5. Sanitize the receipt file name.
6. Keep C617.1 and CA92.1 as is. Re-check them if the app ever adds document picker, import or share-extension file reads, since C617.1 would then not cover those files (DDA9.1 or 3B52.1 would be needed).
