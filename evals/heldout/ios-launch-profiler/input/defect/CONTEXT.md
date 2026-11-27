# TrailCatalog launch complaint

TrailCatalog is a SwiftUI iOS 17+ app that shows a searchable list of hiking trails.

Support tickets since the 1.8 release (build 142) say the app "sits on a white/black screen for a couple of seconds" when opened from a cold start. 1.7 (build 141) felt instant. Nothing else about the release is believed to have changed except "more trails".

QA collected cold-launch timings on an iPhone 12 (iOS 17.5) by screen-recording and counting frames; they are in Metrics/cold_launch_timings.json. Nobody has captured an Instruments trace yet.

Files: App/TrailCatalogApp.swift, App/CatalogStore.swift, Resources/catalog_manifest.json, Metrics/cold_launch_timings.json. The bundled catalog.json itself is not included (18 MB).
