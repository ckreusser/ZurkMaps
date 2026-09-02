# Changelog

All notable changes to Zurk Maps will be documented in this file.

## Unreleased

### Added

- Added compact M:SS capture timers for every contested Alterac Valley tower and graveyard, regardless of player faction.
- Added timer tooltips and callouts: left-click reports remaining time; right-click reports an enemy-held objective as weak or requests reinforcements for a friendly-held objective.
- Added animated geometry-following glows to the WSG friendly flag marker and friendly-carrier health-bar icon.
- Added a clipped, animated tower-fire treatment behind the WSG enemy-carrier health-bar flag icon.
- Added default Alterac Valley quick messages for slots 1–4 covering the North-to-Dwarf rush, stump counterplay, back-cap warnings, and coordinated flag pushes.
- Added both factions' Honor NPC blips and patrol paths to AV test mode so all routes can be reviewed from either faction.

### Changed

- Removed the synthetic AV objective-timer test control and `/av test timers` command; the regular AV map/NPC inspection test remains available.
- Nudged the WSG enemy-carrier health-bar flame one pixel right for final icon alignment.
- AV timer boxes now use compact fixed-position clock glyphs, objective-specific placement, faction-colored completion borders, a smooth grow pulse, and a 0.3-second fade.
- Improved AV tower-destruction fire with a faster, smoother whoosh and centered honor-gain text.
- Honor Bar battleground estimates now average all recorded games up to the latest 50 rather than only 10.
- Non-rank Honor Bar breakpoint dividers now remain inside the dark track at fractional and resized dimensions.
- Untouched AV quick-message defaults now follow the character faction, including “SOUTH TO DREK” Alliance variants; edited or intentionally blank slots remain user-owned.
- Friendly WSG teammate blips now render above the flag marker, while the carrier's redundant player blip is hidden and the flag retains the carrier tooltip.
- Rebuilt the WSG CAP/PICK footer as one fitted frame, aligned its buttons, and extended the attached Honor Bar to the same baseline.
- WSG, AB, and AV resize grips are hidden until map mouseover, fade in over 0.2 seconds, and fade out over 0.1 seconds while retaining their normal highlight and tooltip behavior.
- Added explicit source-credit comments for techniques inspired by Capping, Ranker, Nova Instance Tracker, and WeakAuras/LibCustomGlow; internal compatibility variables now use Zurk Maps naming.
- Refined AV patrol paths and descriptions for Lieutenant Stouthandle, Lieutenant Lonadin, Lieutenant Mancuso, Lieutenant Grummus, Lieutenant Murp, and Commander Mortimer.
- Removed the inaccurate patrol route from Lieutenant Rugba, who is represented as a stationary guard.

### Fixed

- Non-rank Honor Bar breakpoint delineations now span the full dark track and use an inner-track mask so they cannot overlap the border.
- Fixed AV Battlecry custom text being replaced by its default after updates or reloads.
- Fixed AV objective-timer text fitting, clock-digit movement, timer-box background overhang, completion smoothness, and collisions around Dun Baldar, Iceblood, and Frostwolf objectives.
- Fixed the friendly WSG flag-carrier player blip obscuring the larger flag marker while preserving carrier hover information.
- Moved AV quick messages into a dedicated SavedVariable and added migration from the previous nested storage location.
- Reconnected the quick-message UI to SavedVariables after `ADDON_LOADED`, fixing custom messages that were written to disk but appeared empty after `/reload`.
- Preserved existing custom or intentionally blank messages across addon updates; slot 5 remains blank by default and is never overwritten.
