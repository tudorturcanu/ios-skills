# Trailhead (hiking log app) - situation

Trailhead 1.4 shipped with a new schema (SchemaV2: distance field renamed to
distanceKm, plus an isFavorite flag). After updating from 1.3, several beta users
report that their hikes are all still listed (names and dates are fine), but every
hike now shows "0.0 km" and the yearly total is 0. Fresh installs of 1.4 look
normal. Our unit tests are green and QA did not see the problem on a clean install.

Files: Models/SchemaV1.swift, Models/SchemaV2.swift, Models/HikeMigrationPlan.swift,
App/TrailheadApp.swift, Tests/HikeMigrationTests.swift.
Distances in V1 and V2 are both kilometres; only the property name changed.
