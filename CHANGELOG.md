# Changelog

All notable changes to Zurk Maps will be documented in this file.

## Unreleased

## Zurk Maps 1.3.0-r19

### Added

- Added a WSG-only **Auto EFC Health** option, enabled by default, for automatic enemy flag-carrier reports at 40%, 20%, and 10% health.

### Changed

- Coordinated automatic EFC health reports between Zurk Maps users with short per-player staggering, private threshold claims, public-report cancellation, and delayed backup takeover when a claimant never reports. More urgent thresholds use shorter delays, and manual Shift-click reports remain immediate.
- Reduced WSG teammate area animations from 12 seconds to 8 seconds and shortened the terminal fade to 0.75 seconds. Separated pulse opacity from expiry opacity so drop shadows remain stable during a pulse but fade and clear with the area, and replaced frame-dependent button easing with immediate press feedback and a fixed 90-millisecond release that handles rapid clicks.
- Expanded the WSG, AB, AV, and Honor Bar promo rotations to eight unique messages each. Every map now has five battleground-specific promos and three uniquely worded general-feature promos, all sized for in-game chat.
- Changed every promo pool to an independent shuffled rotation, guaranteeing all eight messages appear once before that pool repeats and preventing duplicates across rotation boundaries.
- Reworked WSG teammate callout areas with slow, color-matched diagonal stripes, tight drop shadows, and a uniformly weighted rotating segmented border. Ambiguous areas share one stripe direction and animation phase, and the caller receipt has been removed. Hover leaves areas level; mouse-down presses them toward the anchored shadow and mouse-up snaps them back. Rebuilt every area and callout mask with supersampled antialiasing, and unified Horde Ramp's hover, pulse, and shadow on its current geometry.
- Added WSG `e` shorthand for enemy-side locations in both attached and standalone forms, including `eroof`, `e roof`, suffix forms, ambiguous reports, and the full location vocabulary.
- Nudged every Alliance WSG area five map pixels to the right while leaving Alliance Top of Tunnel fixed, including hover targets, callout masks, animated borders, and shadows.
- Rebuilt AV test mode with rank 12–14 helmets and a Raid Boss blip, walking starts, three-second mount casts, slower travel, a mix of +60% and +100% mounts, and occasional 3–9% mounted-speed bonuses.
- Made every test player immediately walk a few yards west, perform a three-second mount cast, and begin the route. Reduced all movement speeds by another 30%. Rank 12–14 and Raid Boss players always use +100% mounts; ordinary players retain the slower mount mix.
- Added Horde breakaway routes for Balinda, Stonehearth Bunker/GY, Stormpike Aid Station, the Dun Baldar bunkers, and Stormpike GY. Mirrored Alliance advances contest Iceblood GY about ten seconds after the Horde contests Stonehearth GY.
- Corrected the Horde cave exit to follow the access road before veering east of Iceblood GY. The main raid now curves well clear of Stonehearth Bunker's defensive fire while its assigned assault squad takes the direct approach.
- Corrected the northern road approach past Stormpike GY and across the bridge. Squads gather immediately south of Vanndar after contesting both base bunkers, with a mirrored gathering north of Drek'Thar.
- Assigned honor NPCs to squads already visiting their graveyards and towers. Only the Stonehearth GY scout stops for Spencer; the Balinda squad takes Lonadin and almost every Horde rider passes the graveyard. Alliance squads mirror this behavior.
- Connected simulated flag interactions to the normal objective icons, five-minute capture clocks, and completion effects. Live objective refreshes and timer sync stay separate from the rehearsal.

### Fixed

- Kept WSG callout drop shadows visible through pulse troughs and fast pointer exits after clicking an area while preventing shadows from outliving the final expiry fade. Ordinary area buttons finish their mouse-up return with the shadow anchored when the pointer exits, then clear the artwork and shadow together on the exact completion frame.
- Allowed the AV map to close while test mode continues, reopening the same run with `/av show`. Stopping tests restores live objectives and clears simulated timers and tower effects.
- Reused AV test blip frames across restarts and kept rank helmets from being overwritten by class-dot coloring.
- Added stationary three-second remounts after fights and flag work, keeping combat and contests at footspeed. Prevented simulated NPC health updates from repeatedly rebuilding markers, then matched live NPC deaths with the normal proc and ten-second skull fade.

## Zurk Maps 1.3.0-r18

### Added

- Added WSG enemy flag carrier location highlights from friendly `/bg` callouts, including battleground leaders and distant teammates.
- Recognizes common WSG names and slang, with faction-aware qualifiers. Ambiguous reports pulse every plausible area for 12 seconds; newer reports replace older ones and fade automatically.
- Added `/wsg callouts on`, `/wsg callouts off`, and `/wsg callouts clear`. Friendly `/say` reports remain available for testing outside battlegrounds, with a callout reference and test guide in `WSG_CALLOUTS.md`.

### Changed

- Placed the callout receipt directly beneath CAP/PICK with matching bronze borders, dark styling, class-colored caller names, and screen-edge spacing.

### Fixed

- Restored full-width honor fills, unrealized-honor stripes, and honor-gain stripe animation across WSG, AB, and AV in both vertical and horizontal layouts.
- Kept the local player's rotating arrow free of overlapping class, rank, and assigned blips in both Gold and Class Colors modes.
- Prevented ordinary dots from appearing over the WSG friendly flag carrier, class blips, or rank helmets after map updates. Flag handoffs restore the previous carrier's proper icon.
- Prevented confirmed rank badges from briefly reverting to ordinary blips when rank data is temporarily unavailable or raid slots change. Improved fallback rendering when special blip frames cannot be created.

## Zurk Maps 1.3.0-r17

### Changed

- Standardized framed icon and numbered-message buttons across all three maps with thin opaque borders, solid backgrounds, and evenly aligned artwork. Button sizes, positions, and actions are preserved.
- Matched AB capture timers to AV's fixed-digit `m:ss` clocks and faction-colored completion pulse/fade, preserving AB's capture timing, callouts, and timer positions.
- Enlarged AB capture clocks by 40% and all AB player blips by 25%, including rank badges, assigned icons, and test previews.
- Enlarged the callout-channel toggle and fitted the original in-game slider artwork to both track positions.

### Fixed

- Filled map artwork, honor-bar tracks and fills, and AB/AV timer backgrounds to their inner borders using hard interior clipping and oriented corner masks. Timer backgrounds remain fitted throughout their completion animation.
- Removed feathered honor-bar ends, corner gaps, and unintended border transparency at full opacity.
- Kept texture masking within the client's three-mask limit and removed unsupported mask-coordinate transforms.
- Aligned button artwork and backgrounds to the same pixel geometry as their borders, keeping opposite margins even when maps move or scale.
- Made rank 12–14 Shaman and Paladin class-colored blips use the same pink helmet artwork.
- Fixed WSG/AB resizing to hold the visible top-left corner in place and track the actual grab point while preserving map proportions and saved layouts.

## Zurk Maps 1.3.0-r16

### Added

- Added a shared Gold / Class Colors setting for teammate blips across Warsong Gulch, Arathi Basin, and Alterac Valley, saved across reloads.
- Added compact Warcraft-style class blips with faceted centers and forged rims. The approved rounded artwork is retained as an alternative asset.
- Added class-colored rank 12, 13, and 14 helmets, including matching tooltip icons and existing rank test previews. Only helmet pixels are recolored; rank-14 backgrounds, rank-13/14 gold bars, original transparency, and shadows are preserved.
- Added a Map Opacity slider at the bottom of the right-click menu, shared across all three maps and saved across reloads.

### Changed

- Reorganized the right-click menu into aligned settings, grouped actions, and an opacity footer, with consistent row spacing and a compact `/bg` / `/RW` toggle switch.
- Reduced the menu height by approximately 18% while retaining its option order, controls, and font sizes.
- Consolidated startup chat into one line listing `/wsg` (Warsong Gulch), `/ab` (Arathi Basin), and `/av` (Alterac Valley).
- Reduced ordinary class-blip size and refined their highlights and shading while retaining the existing Elite appearance.

### Fixed

- Made the opacity slider reflect actual map opacity: the original appearance is 72%, and 100% makes the map fully opaque.
- Reapplied opacity after SavedVariables load so the rendered map and slider remain synchronized after login or reload.
- Prevented opening the menu from rounding or changing saved opacity, and made the menu background opaque for readability.
- Replaced whole-badge rank tinting with 27 helmet-only class textures, removing unwanted orange and muddy color shifts while preserving original backgrounds and gold bars.

## Zurk Maps 1.3.0-r7

### Rank-up celebrations

- Added a draggable rank-up popup with your character name, new rank title and icon, an animated golden glow, and a native red close button.
- Honor breakpoint celebrations earned inside a battleground now wait until you leave, including breakpoints reached through end-of-match bonus honor.
- Added a faction-colored honor bar that animates from the preceding breakpoint to the milestone that earns your new rank, using your actual breakpoint layout.
- Completed segments become solid faction-colored metal; partial progress uses animated stripes. The moving indicator fades out over 0.5 seconds on arrival, and the rank-breakpoint glow settles after three seconds.
- Improved automatic text sizing, centering, icon spacing, and popup borders. Rank titles are highlighted in the subtext without displaying rank numbers.
- Added faction-specific rally text and a reminder that the new rank and Quartermaster purchasing privileges take effect after Tuesday's weekly reset.
- Removed the temporary developer button.

### Warsong Gulch

- Expanded the Horde Ramp highlight and added a larger, separate mouseover/tooltip area.
- Matched the Horde Ramp outline thickness to the other map regions.

### Honor bars

- Kept the live honor-progress indicator entirely inside the track on WSG, AB, and AV bars, including at full honor and in horizontal orientation.

## 1.3.0-r6q

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
