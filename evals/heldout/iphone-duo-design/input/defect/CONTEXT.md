# Context
App: "Trailnotes", a SwiftUI note-taking app, now being tested on iPhone Duo (outer display and large inner display).

Complaint from QA: when the device is opened or closed with the app running, the app keeps showing whatever layout it had at launch. Launched on the outer display and then opened: the single-column list is stretched across the inner display with no detail pane. Launched on the inner display and then closed: the two-column layout is clipped and cramped. Relaunching the app fixes it each time.
