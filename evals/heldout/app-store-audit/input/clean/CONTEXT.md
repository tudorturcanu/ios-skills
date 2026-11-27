# Context

ReceiptBox is a small iOS 17+ app that scans paper receipts and stores them as PDFs
on device. It uses only first-party frameworks (SwiftUI, VisionKit, Foundation); there
are no third-party SDKs. The submission files for build 57 are in this folder.

An earlier upload received an email from Apple about the privacy manifest
("ITMS-91053: Missing API declaration"). The team has since updated the manifest and
wants a pre-submission check before re-uploading.

Documented context: the only files whose timestamps the app reads are PDFs it created
itself inside its own Documents directory (app container); nothing is read from
user-picked or external locations.

Please review the submission files for readiness.
