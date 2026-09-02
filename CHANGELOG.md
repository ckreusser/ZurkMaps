# Changelog

All notable changes to Zurk Maps will be documented in this file.

## Unreleased

### Added

- Added default Alterac Valley quick messages for slots 1–4 covering the North-to-Dwarf rush, stump counterplay, back-cap warnings, and coordinated flag pushes.
- Added both factions' Honor NPC blips and patrol paths to AV test mode so all routes can be reviewed from either faction.

### Changed

- Refined AV patrol paths and descriptions for Lieutenant Stouthandle, Lieutenant Lonadin, Lieutenant Mancuso, Lieutenant Grummus, Lieutenant Murp, and Commander Mortimer.
- Removed the inaccurate patrol route from Lieutenant Rugba, who is represented as a stationary guard.

### Fixed

- Moved AV quick messages into a dedicated SavedVariable and added migration from the previous nested storage location.
- Reconnected the quick-message UI to SavedVariables after `ADDON_LOADED`, fixing custom messages that were written to disk but appeared empty after `/reload`.
- Preserved existing custom or intentionally blank messages across addon updates; slot 5 remains blank by default and is never overwritten.
