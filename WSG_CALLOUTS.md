# Incoming WSG callout pulses

Research and implementation: September 3, 2026. The listener is enabled by default and works whenever the WSG map is visible. Friendly `/bg` reports are accepted while in Warsong Gulch, including the battleground leader's messages (`CHAT_MSG_INSTANCE_CHAT` and `CHAT_MSG_INSTANCE_CHAT_LEADER`). The gate uses Classic WSG instance ID 489 and the PvP instance type, so instance chat elsewhere is ignored even if the WSG map is manually open. `/say` remains available, including your own `/s` messages for solo testing outside the battleground.

## Try it in game

Run `/reload`, then `/wsg show`. Send each example separately and watch the map:

Inside Warsong Gulch, use `/bg` instead of `/s` in these examples, such as `/bg efc tun` or `/bg efc our ramp`. Teammates do not need Zurk Maps installed. The latest accepted report from either channel replaces the previous report.

| Say command | Expected areas |
| --- | --- |
| `/s efc tun` | Both tunnels |
| `/s efc our ramp` | Your faction's ramp |
| `/s efc their gy` | The opposing faction's graveyard |
| `/s efc ally roof` | Alliance roof |
| `/s efc roof or gy` | Both roofs and both graveyards |
| `/s efc our tunnel or their ramp` | Your tunnel and the opposing ramp |
| `/s efc tot` | Both top-of-tunnel spots; not the whole tunnels |
| `/s efc on 2` | Both second floors |
| `/s efc mid` | The center, west, and east midfield regions |
| `/s efc hut` | All four buff huts |
| `/s efc crane` | East midfield, Horde leaf-hut area, and Horde topside area |
| `/s efc leaf hut construction` | Horde leaf-hut area |
| `/s tun` | Both tunnels; short location-only answers work too |

Each accepted report replaces the previous one, animates for 8 seconds, and fades during its last 0.75 seconds. Every possible area uses its own callout color, a tight drop shadow, a uniformly weighted rotating segmented border, mostly transparent diagonal stripes, and a supersampled antialiased edge mask. Ambiguous areas share the same stripe direction and phase. Hover leaves areas at their normal map position; mouse-down immediately presses them toward the anchored shadow and mouse-up returns them over 90 milliseconds. The shadow ignores pulse troughs but follows the final expiry fade exactly. Map clicking and player blips continue to work.

A standalone or attached `e` means enemy. For a Horde player, `e roof`, `eroof`, `roof e`, and `roof or gy e` resolve to the Alliance side; the same reports resolve to the Horde side for an Alliance player. The attached form works with the full location vocabulary, such as `ebanana` and `etop of tunnel`.

`/wsg callouts off` disables the listener's visual responses and saves that preference. `/wsg callouts on` enables them. `/wsg callouts clear` clears the current report. Hiding the map, stopping test mode, reloading, or changing world/instance clears reports. Reports received while the map is hidden are discarded.

## Automatic EFC health reports

The WSG options menu includes **Auto EFC Health**, enabled by default. While Zurk Maps has a live unit for the enemy flag carrier, it automatically reports downward crossings at 40%, 20%, and 10%. A five-point heal re-arms a crossed threshold, with a five-second barrier on same-band recovery updates. Manual Shift-click health reports remain immediate regardless of this setting.

Zurk Maps clients briefly coordinate before an automatic report. A stable per-player stagger selects an early candidate, that client sends a private addon claim, and peers cancel their pending copy when the public report appears. A more urgent threshold can supersede an earlier candidate. If the claimant never reports, another client takes over after a short backup delay. Clients also recognize the public Zurk Maps health format, which provides duplicate suppression when private addon messaging is unavailable.

## Research findings

Player guides consistently distinguish the enemy carrier (`EFC`) from the friendly carrier (`FC`). `FR`, `GY`, and `tun` are common abbreviations, with `EFR`, `EGY`, and `etun` explicitly indicating the opposing base. Some groups assume an unprefixed location is friendly; others use the surrounding carrier discussion to supply its side. This prototype deliberately highlights both bases for unqualified locations. [Jwl's flag-carrying terminology](https://xpoff.com/threads/jwls-guide-to-flag-carrying-everything-you-need-to-know.91697/)

`2nd` and `on 2` mean the middle floor, while roof means the upper level. Floor notation `1F/2F/3F` is also documented in player requests for battleground map addons. [Warsong Gulch 101](https://revengeofthegnomes.wordpress.com/2011/11/18/warsong-gulch-101/), [REPorter player terminology discussion](https://www.wowinterface.com/downloads/fileinfo.php?id=21089&page=4)

Classic players use architectural and buff names: banana, lobby, connector, balcony, window room, boots, leaf, and zerker. Construction/crane is particularly ambiguous because three sites share the landmark. Shrine is Alliance-specific, and sawmill is Horde-specific. These names describe smaller locations than several existing Zurk map regions. The implementation therefore uses the coverage below as an approximation, rather than inventing exact coordinates. [Rokman's Classic map guide](https://www.wowhead.com/classic/guide/classic-wow-warsong-gulch-advanced-map-strategies-wsg)

`ToT` means top of tunnel and occurs in player flag-carrying discussions as a location distinct from roof and tunnel. It gets a separate match before shorter tunnel aliases. [Player flag-carrying discussion](https://xpoff.com/threads/warsong-gulch-tips-and-tricks.58521/)

## Vocabulary and coverage

The following are implementation mappings to the existing map, not claims that every group uses every spelling. Expanded words, spacing variants, and a few obvious abbreviations/typos are convenience aliases. The full editable vocabulary is in `ZurkMaps_WSGIncoming.lua`.

| Accepted names and examples | Highlight coverage |
| --- | --- |
| `fr`, flagroom, flag stand, cap point, first floor | Flag room |
| `efr`, `egy`, `etun`, `eroof`, `eramp`, `etot`, `eleaf`, `ezerk` | Corresponding enemy-base region |
| second floor, `2nd`, `on 2`, `2F`, balcony, `balc`, connector, `con` | Second floor |
| roof, rooftop, third floor, `3rd`, `on 3`, `3F` | Roof |
| banana, banana ramp, roof ramp, `bananna` | Banana |
| topside, top side | Topside |
| tunnel, `tun`, `tunn`, tunnel mouth/entrance/exit, boots, speed buff | Tunnel |
| top of tunnel, tunnel top, `ToT` | Small existing top-of-tunnel region |
| ramp, bottom ramp | Ramp |
| graveyard, grave yard, `GY`, gy jump | Graveyard |
| leaf, leaf hut, resto, restoration, healing hut | Leaf hut |
| zerk, zerker, berserk, berserker, berserking, bers | Zerk hut |
| hut, buff hut | Leaf and zerk huts |
| window, window room | Flag room, approximately |
| lobby, stairs, staircase | Flag room and second floor, approximately |
| fence | Topside, graveyard, and ramp, approximately |
| top, up top, upstairs | Roof, second floor, topside, and ToT |
| base | Interior and base approaches; excludes midfield buff huts |
| gy side | Graveyard, leaf hut, and that faction's graveyard-side midfield wing |
| ramp side | Ramp, zerk hut, and that faction's ramp-side midfield wing |
| mid, middle, midfield | All three midfield regions |
| center mid, centre mid | Center region only |
| west, mid west, west mid, catapult | West midfield |
| east, mid east, east mid | East midfield |
| left, right, left mid, right mid | Both midfield wings because facing is unknown |
| tree, big tree | Existing named Tree region |
| trees, stump, stumps | Tree and both midfield wings, approximately |
| crane, construction | East midfield, Horde leaf hut, and Horde topside, approximately |
| east/mid crane or construction | East midfield |
| leaf/leaf hut crane or construction | Horde leaf hut |
| sawmill, sawmill crane/construction | Horde topside, approximately |
| shrine | Alliance roof and banana, approximately |
| flower box, flowerbox, planter | Alliance roof |

## Interpretation rules and limits

- Side words include Alliance/ally/alli, Horde, north/south, our/own/home/friendly, and their/enemy. North is Alliance and south is Horde on this map. Relative sides use the receiving player's faction; only friendly senders are accepted. An EFC subject alone does not imply which base the carrier is currently in.
- A side applies to following locations until another side or sentence boundary changes it. `our tunnel or their ramp` keeps the two qualifiers separate. `roof horde` also works. Distinct fixed landmarks such as sawmill retain their physical location.
- Longest phrases win. `top of tunnel`, `roof ramp`, and `leaf hut construction` do not also trigger their shorter component words. Repeated matches are deduplicated.
- Brief location-only answers are accepted. Longer prose needs an EFC subject. Explicit friendly-FC clauses, common questions, negated locations, and death/return clauses are ignored. Buff possession/use such as `efc has speed` is not treated as a location. A bare `2` or `3` needs EFC context and is not interpreted as a floor when followed by an escort count description.
- This is an English, deterministic phrase parser. It cannot fully interpret every sentence, player nickname, joke, route correction, or regional abbreviation. `Maybe`/`probably` reports still highlight possibilities. Unknown words are not fuzzy-matched to arbitrary locations.
- The actual carrier position is never inferred from these messages or changed by them. A pulse is a recent player's report, not verified tracking. Ignored messages do not replace the current report.
- For `/say`, friendship uses the sender GUID, visible/group unit relationships, or cached faction-compatible player race. Unknown senders and non-player GUIDs are ignored. The speaker's readable language alone is not used as evidence of friendliness. In WSG `/bg`, Blizzard's team-only channel identifies the sender as a teammate; valid player GUIDs are accepted even before distant players' race or unit data is cached.
- `China`/`reverse China` occur in Classic jump discussions, but the sources inspected did not establish sufficiently precise boundaries for this map. Those names are intentionally not assigned guessed polygons. [Classic player discussion](https://www.reddit.com/r/classicwow/comments/17s2v4c/fix_wsg_safespots_and_jump_skips/), [Blizzard forum discussion](https://us.forums.blizzard.com/en/wow/t/dear-premade-alli-sweaty-nerds/2258544)

## Verification

`Tests/run_wsg_incoming.py` uses Python's `lupa.lua51` to compile the changed Lua files and run the real parser and highlight factory against strict WoW frame doubles. It checks faction perspectives, ambiguous unions, phrase precedence, false positives, sender filtering, the twelfth chat-event argument, frame reuse, the edited Horde ramp polygon, expiration, hiding, settings, all existing map-generated messages, alias outputs, packaged masks, and TOC load order.

The installed files are ready for `/reload` testing. A live WoW client is still required to confirm the actual visual appearance and nearby-player chat delivery.
