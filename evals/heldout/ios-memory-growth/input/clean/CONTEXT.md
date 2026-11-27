# Context: Gallery app memory complaint

App: "Folio", a UIKit photo-gallery app (iOS 17+). QA previously reported rising memory after repeated detail open/close; a change was made and QA re-measured. Please review whether the growth complaint still holds.
and closing the photo detail screen many times in one session, the app's memory
footprint keeps rising and eventually it is terminated in the background.

Repro as reported by QA: from the grid, tap a photo (detail screen is pushed),
wait for the full-size image to appear, tap Back. Repeat. Same 12 photos each time.

Files provided:
- GalleryCoordinator.swift   pushes/pops the detail screen
- PhotoDetailViewController.swift   the detail screen
- PrefetchCenter.swift   shared service that loads full-size images
- footprint.txt   footprint readings after N open/close cycles on the current build (Xcode memory gauge, release build)

No Instruments trace, memory graph, or crash log is available.
