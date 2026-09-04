# AV rehearsal

Run **/av test** to start, **/av hide** to close the map, and **/av show** to reopen it.
The map menu's **Close Map** action also works while testing. The same simulation keeps
running with the map closed. **/av test off** stops it and restores live objective
data, or initial control outside AV. Stop and start again for a fresh run.

The map shows 40 friendly test players for your faction. Both factions are
simulated to drive the mirrored objective changes. Tests do not send chat or
addon packets, change real-player icon assignments, or award honor.

## Players and movement

- Nine players have rank 12–14 badges. Helmets follow the Gold / Class Colors
  setting, and one player starts with the Raid Boss icon. Ranked players and
  Raid Boss players always have +100% mounts, including newly assigned Raid Boss icons.
- Everyone starts immediately, walks a few yards west, stops for a three-second
  mount cast, then rides. Players dismount for every flag interaction and fight.
  After the task, they cast for three seconds at their current position before
  moving again; combat and contest movement never receives mount speed.
- Thirteen ordinary players in each 40-player team start with +60% mounts;
  the other 27 have +100%.
- Each player has a 35% chance of a 3–9% mounted-speed bonus. The bonus multiplies
  mounted speed and stays with that player for the run; it never affects footspeed.
- All movement is 30% slower than the original three-minute mounted crossing:
  unbuffed +100% mounted speed now covers a full north/south map height in about
  257 seconds, and footspeed takes about 514 seconds. Turns, slower mounts,
  combat, and stops add time. Resizing the map does not change travel times.
- Hover a single blip to see its current activity, mount tier, and bonus.

## Horde advance

1. Leave the eastern Horde cave, follow its access road west into the valley,
   then peel east/right of Iceblood GY and enter the Field of Strife.
2. A group of 1–5 crosses the field and approaches Balinda from below/left,
   dismounts, then kills Balinda, Greywand, Largent, and Lonadin one by one.
3. Another 2–4 enter Stonehearth Bunker, kill Stouthandle, Mancuso, and Commander
   Randolph, assault its flag, fight briefly, and rejoin.
4. One rider stops at Stonehearth GY, kills Spencer, then channels the flag for
   ten seconds. Every other non-Balinda group rides past that area.
5. Follow the road east of Icewing, pass Stormpike GY, and cross the bridge
   to Stormpike Aid Station. After its flag is assaulted, arriving groups split
   between Dun Baldar North and South Bunkers.
6. Two riders leave Aid, backtrack along the road, kill Commander Karl Philips,
   assault Icewing Bunker, and return before completing their tower assignments.
7. The Dun Baldar force kills Mortimer on the way to the bunkers. After those
   assignments, 2–5 players break away, kill Duffy, and assault Stormpike GY.
8. Once both Dun Baldar bunkers are contested, players gather dismounted
   immediately south of Vanndar. Detachments join them as they finish their tasks.

The large majority curves well west of Stonehearth Bunker to avoid its defensive
fire. Only the assigned bunker assault takes the close approach.

## Alliance advance and objectives

The Alliance follows the corresponding southbound plan. Its objective squads
kill nearby honor NPCs: Dardosh at Iceblood Tower; Stronghoof, Grummus, and Rugba
at Iceblood GY; Mulfort at Relief; Louis Philips and Murp at Tower Point; and
Malgor at Frostwolf GY. The Galvangar group takes Vol'talar and Lewis. The final
gathering is immediately north of Drek'Thar.

Only the opening graveyard scout may briefly rally beside the road to place
the first Iceblood GY assault about ten seconds after the Horde's Stonehearth
GY assault; the other players depart immediately. Later Alliance assaults wait
until at least ten seconds after the corresponding Horde assault, as well as
requiring their own squad to arrive and finish its flag interaction.

A ten-second flag interaction starts the contest; it does not instantly finish
the capture. The existing five-minute capture clocks run normally. Graveyards
then change faction, and towers are destroyed with the normal completion effects.
The advance, NPC sweep, and final captures take several minutes; the timing
varies with each run's mount bonuses and squad sizes.

Live POI refreshes and incoming timer synchronization cannot overwrite simulated
objectives. Simulated percentages update only the NPC health bar, preventing the
marker rebuild flicker. Deaths use the live death proc followed by the same
ten-second skull fade; captain and general skulls remain persistent, matching live
behavior. Stopping the test clears simulated clocks/effects and restores live NPC
state. A new run starts with all NPCs alive again.

## Automated checks

Tests/run_av_test.py uses Python with lupa.lua51. It checks movement speed and
stationary mount/flag channels throughout three complete matches, squad routes,
capture timing, sequential NPC combat, road/bridge and backtracking routes,
boss gathering, badge rendering, NPC health/death rendering, timer integration,
close/reopen behavior, live state restoration, and reuse of blip frames when restarting.
