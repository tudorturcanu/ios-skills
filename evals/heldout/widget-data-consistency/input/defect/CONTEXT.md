# TideWatch

TideWatch is an iOS app with a WidgetKit extension (small widget showing the next high tide time and height for the user's saved harbor). The app and the widget share data through the App Group `group.com.example.tidewatch`, declared in both targets' entitlements files.

## Complaint
Beta testers report: "I pull to refresh in the app and see the new tide time, but the home screen widget still shows the previous one. It only catches up the next time I refresh. Sometimes it is a whole refresh behind."

The app is not yet shipped; the testers use a TestFlight build on real devices. Nobody has attached logs.
