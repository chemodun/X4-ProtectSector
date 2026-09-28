# Changelog

## [2.00] - 2026-09-??

- Fixed
  - An idle ship (or fleet leader) did not re-scan its sector every few seconds as intended, a regression since version `1.13`. It reacted to a new enemy only when its idle delay ran out: 4 minutes for S/M, 9 for L, 15 for XL. The periodic re-scan works again.
  - Fewer script errors in the debug log after loading a save.
  - An idle ship could stay idle for good, never waking for its periodic re-scan or its idle timeout, in roughly one idle out of fifteen.
  - Subordinates set to mimic a commander running `Protect Sector` ignored the commander's parking, damage sensitivity, ignore blacklists and aggressive subordinates settings and used the defaults, logging a script error each time they started the order.
  - A ship set to park in its sector could fail to see that it had already reached its parking position and repeat the parking move every few seconds for as long as it was idle.
  - A ship could stay locked in one attack for an hour or more, mostly against Kha'ak out of the player's sector: the attack restarted every few seconds on a target the ship could not see, and was never broken off. It now breaks off within a minute and leaves that target alone for five minutes, also across an order restart or a save reload, unless the target attacks one of your ships.
  - The experimental `Attack Station` mode could stop with a script error when the ship came into contact with the station.  - The station check could log a script error when a station or build storage found by the scan had disappeared, or could not be measured, by the time the ship got to it.
  - An idle ship could run its periodic re-scan of the sector two to six times as often as intended after an interrupted idle, which cost extra script time in busy sectors and inflated the scan count.
  - An idle ship with station attacks enabled woke every 30 seconds for the build storage of a hostile station under construction that it never attacks, restarting its idle each time.
  - A ship parked in a sector with a hazardous region drifted away from its parking point while idle and kept flying back to it.
  - A fleet leader in a long fight ran one extra check of its subordinates for every attack in that fight instead of a single one; with `Aggressive subordinates` on, their attack orders were cancelled and re-issued more often than intended.
  - A ship that had to chase its target again after breaking off at long range could give the chase up too early, because the approach attempts from earlier in the same fight still counted.
  - A ship stopped by a hazardous region in its sector (with `Ignore the threats of Hazardous zones` off) went back to patrolling when one of your ships there was attacked, while the order was still shown as failed. It now stays stopped until the next hazard check.
  - A ship flying back to its sector from elsewhere arrived at a point that depended on the gate it came through, not at its parking position.
  - A ship could hang next to an enemy that had docked or entered a highway, with its subordinates' orders flipping several times a second: the game's attack drops such a target at once and then picks it again. The ship now leaves that target alone for a minute. A target that the game's attack drops within 3 seconds, three times in a row, is left alone for two minutes.
  - A ship chasing a large target could fly up and down instead of closing in, and often gave up the chase. It chose again every few seconds whether to pass above or below the target, and short legs cut off by the target's zone changes counted as not closing in. It now keeps one side for the whole approach.
  - With `Aggressive subordinates` on, subordinates were ordered to attack while their leader was still approaching the target, and those orders were cancelled at the leader's next step. They are now ordered to attack only once the leader attacks.
  - In areas that reduce radar range, a ship started its attack from farther away than its radar could reach, then flew at the target for a minute without firing and gave up. The attack distance now follows the ship's current radar range.
  - A ship that lost sight of its target mid-attack gave it up at once and called its subordinates back, even when the target was still on the map and close. While the target is on the map and within radar range, the ship now restarts the attack; within twice that range it flies after it and gives up only if it cannot close in. Subordinates already attacking it carry on.
  - Starting `Protect Sector` could write the "started" logbook entry twice, and a restart after loading a save could write it once although the order had not been started again.
  - A ship could choose a target that had just left its home sector, log and count the attack, and only drop the target at its next step. The sector scans now always cover the home sector, and a target outside it is never chosen.
  - With `Attack hostile only` off, attacking a non-hostile ship or station made it hostile to every player ship and station for 10 minutes (the game 9.00 behaviour), so all of them joined in. The target is now hostile only to the ships that attack it, as in 8.00, and they no longer pick unrelated ships as their next target.
  - A ship or subordinate no longer starts an attack it is not allowed to fire in (fire authorisation override); it looked engaged but never shot. A station it may not fire on is skipped for 2 minutes.

- Changed
  - The `Extension options` page is now built with `Options Helper`: the damage sensitivity thresholds are sliders, and a `Debug Level` dropdown (`None`, `Debug`, `Trace`) replaces the `Enable debug log` checkbox. Settings from the old page are carried over once.
  - `Mod Support APIs`, `Options Helper` and `Print Extension List` are now required, which raises the minimum game version to `8.00`. For `7.50` and `7.60` use version `1.18`.
  - Loading a save from an earlier version restarts `Protect Sector` once on every ship running it, with the same settings, so the order runs entirely on the new logic.
  - When both station attack modes are selected, the `Coordinate Attack` one is now unchecked on order start, leaving the experimental `Attack Station`, which was already the one used.
  - A ship with `Park on delay` now stays at its parking point while idle, as described, instead of flying off to patrol after arriving, and returns to it after a fight.
  - While a `Protect Sector` ship approaches or attacks its target, the game's own reaction to being attacked (the ship's `When attacked` setting) no longer replaces the order with a short attack on the attacker, which dropped the current fight and restarted the order. While the ship has no target, the setting works as before.
  - When a target is destroyed, lost or the attack on it ends, the ship first looks for its next target among the rest of that target's fleet as it stood at the start of the attack, then among the targets its own subordinates are already fighting, and only then searches the whole sector again. The usual filters apply, and an attack on another of your ships does not interrupt that choice.

- Added
  - A `Protect Sector overview` screen, opened from the right-click menu of a ship running the order or assisting one, or from its own icon in the game's top menu row (the row of `Map`, `Player Information` and `Options`), right after `Map`: every fleet on the order by home sector on the left; kills, attacks, time in combat, broken-off attacks, idle share, lowest hull, the subordinates with their own kills and the targets the fleet could not catch on the right. With the history on (`Extension options`, depth 3 to 48 hours, default 24) the numbers are shown for a window of 15 minutes to 24 hours that can be moved over the history; with it off, the totals since the counters started. With the history on, a fleet that is destroyed or leaves the order stays listed, greyed out, with its numbers (a destroyed fleet's up to the last 15-minute sample) until they fall out of the history, and `Ships lost` counts every ship of a fleet that is destroyed, captured or abandoned by its crew, the leader included. A double-click on a target in `Targets tried` narrows the list on the left to the sector, then to the fleet, that tried it most; a double-click on a fleet opens the map on its ship. The screen refreshes itself every 30 seconds; `Extension options` sets the interval from 30 seconds to 10 minutes, or 0 for no automatic refresh. A tab row on top switches to `Coordination`: the same list with each fleet's state (engaged, idle, away from home, holding, assigned), and on the right the coordination state of the sector or fleet with the targets it involves, their strength ratio, the fleets on them or holding for them and any open call for help; `Show on Map` for the fleet and `Show Target on Map` for the target, or a double-click on the target. A third tab, `Settings`, shows the order settings of the fleets: for a sector of up to 12 fleets, a grid with one column per fleet, where a value other than the one most of the sector's fleets use is highlighted; for a larger sector, how its fleets split on each setting and which fleets differ. The list on the left counts the differing settings per fleet and per sector. A fleet assisting a commander follows the commander's settings and shows only a note.
  - The `Debug` level writes one compact line per state change of the order, meant for troubleshooting long unattended sessions. `Trace` adds the detailed output of the previous `Enable debug log` option.
  - `Fleet coordination`, on by default in `Extension options`: every fleet running the order reports to one coordinator, which decides for the fleets of a sector together. A fleet leader leaves a target that fleets nearer to it already handle with enough force, leaves a target it cannot reach or catch to the fleet already on it, hands a target to a nearer idle fleet, and calls the idle fleets nearby to a group too strong for it alone; fleets that cannot take a group hold off and pledge their strength to it, with a logbook entry and a notification, and go together once enough have gathered; fleets losing their fight call for help once and break off together if none comes within a minute; an attack on one of your ships or stations sends the nearest fleet that is strong enough, or two together, instead of waking every idle fleet, and a far or slower fleet when no other can go. `Share target with other` is now `Share target with other fleets`: off, the fleet fights alone and no other fleet is sent to its target, whether the option is on or off, unless a fleet much nearer to the target asks for it: that one takes it over and the farther one is released. A shared target is taken over the same way by a much nearer fleet strong enough alone, and a fleet moving on to the next ship of the group it fought leaves one that nearer fleets already handle.
  - `Attack responses before a fleet's own targets`, on by default: an attack on one of your ships or stations may take the nearest fleet off a target it picked itself, never off another attack response or a call for help. An idle fleet goes instead unless the busy one is more than 5 km nearer.
  - `Coordinator settings` at the top of the overview's `Coordination` tab with `All fleets` selected: the attack responses option above, and sliders for the strength a fleet needs to attack alone, to attack with help and to stay in a fight, the radius of a hostile group, the distance and speed past which a fleet leaves a target to another fleet already on it, the margin by which a fleet must be nearer to take a target over, and the coordinator's timers, with a `Restore Defaults` button. The mouse-over text of each explains it. Every load puts a missing or invalid setting back to its default.
  - A fleet that keeps refusing the targets the coordinator gives it (five times, because its own attacks on them failed or it lost them) is marked, with a logbook entry and a notification, and takes no targets until you unmark it with the `Unmark` button in `Problematic fleets` on the overview's `Statistics` or `Coordination` tab, or on that fleet's own page on `Coordination`. The mark stays through reloads and order restarts, so fix the fleet's loadout or settings first.
  - A ship with no working weapons or no ammunition for them no longer flies at a target only to break off at once. It skips the attack, is marked in `Problematic fleets` with a logbook entry and a notification, takes no targets, and clears the mark by itself once it can fire again. Losing them while idle or on the way to a target is caught too: the ship stops its approach, and the coordinator marks the fleet within 30 seconds. The overview counts these as `Could not attack: no weapons or ammunition` instead of `Broken off, out of range`, and shows `No weapons.` or `No ammunition.` on the fleet's page and its name in red in the list, whether `Fleet coordination` is on or off; `Problematic fleets` lists every such fleet, including one not marked yet or assisting a commander.
  - The ship's fire authorisation override (`Global Orders`, for the whole faction or per ship) is respected: a target the override does not allow the ship to attack is no longer picked, taken as a coordinator's answer or given to the fleet by the coordinator, where before the ship flew at it and the game's attack broke off at once. With `Attack only hostile targets` off, a target that the game's attack refuses within 3 seconds for the override is left alone for two minutes. The overview counts such attacks as `Could not attack: Fire Authorisation Override`.
  - The overview's list colours each home sector's name by its owner.
  - The overview's `Settings` tab has an `LSR` column in the list on the left: the fleet's `Lost Ship Replacement` setting, which a click turns on or off, as the right-click menu does. The box of `All fleets` or a sector sets every fleet under it and is ticked only when all of them have it on. A fleet assisting a commander shows its commander's setting, greyed out. The column is hidden while the game does not allow lost ship replacement.
  - When a fleet leader running `Protect Sector` is lost and the game promotes one of its subordinates to lead the fleet, the new leader takes over the order with the same settings, and with the history on the fleet keeps its record, now listed under the new leader. A leader already moved to another order before it was lost is left alone. This replaces the takeover added in `1.13`, which lapsed 20 minutes after the order started or last checked its subordinates in a fight, so a leader lost later left the fleet without the order. The new leader also gets back the fleet's `Lost Ship Replacement`, which the game drops with the old leader; the old leader itself, and any replacement still waiting to be built for the fleet, are not rebuilt, as the game keeps no record of them after the loss.

## [1.18] - 2026-07-20

- Fixed
  - Resetting subordinates order moved to an idle state, instead immediately after target is destroyed/lost/etc...

## [1.17] - 2026-07-15

- Fixed
  - Fixed a bug where the ship (or fleet leader) could get stuck endlessly re-engaging a target that fled out of sensor range while still remaining in the sector, causing it to ignore other hostile threats (e.g. a nearby Kha'ak attack) until manually reset. The ship now correctly breaks off and searches for a new target once it can no longer detect the current one and it has moved beyond effective engagement distance.

## [1.16] - 2026-03-27

- Added
  - New `Aggressive subordinates` option to make subordinates more aggressive in attacking targets. It was introduced in version `1.13` as the default behavior; with this update, it becomes optional and is disabled by default.

- Fixed
  - Fixed a bug with `Aggressive subordinates` where subordinates were forced to attack targets outside the sector where the leader is.
  - In some cases the `Park exactly there` option was assumed by the game engine as a null value, which prevented the `Behavior tab` from being opened on order failure.

## [1.15] - 2026-03-26

- Added
  - New option `Received damage sensitivity` to set the sensitivity of the reaction on receiving damage. There are three levels: 1 - low, 2 - medium, 3 - high. With different thresholds in idle or attack state.
  - Possibility to set appropriate threshold for the sensitivity levels based on the percentage of the hull integrity per ship size and state in `Extension Options` menu.
  - New option `Ignore blacklists` - to ignore blacklists when going to and protecting the `Home sector`. Equal to the behavior of the order before version `1.15`. Otherwise, when not set, the order will use `military` blacklist group to reach and protect the `Home sector`.

- Improved
  - Behavior when hazardous or unreachable sectors are set as home ones. Order does not stop, but generates a failure instead.

- Changed
  - Due to the above change and specific behavior of UI with null values in order params, the default value for `Park exactly there` is set to center of the sector instead of empty one. And now it does not make parking as default behavior but just sets the parking position to the center of the sector. Parking will happen only if `Park on delay` is enabled.
  - The `Park on delay` is introduced instead of `Park at sector core` to cover both parking in the center and parking in the desired position.
  - Version is set to `1.15` to be in line with the version of the main script of the mod.

- Fixed
  - Restocking and repairing now processes only reachable stations.

## [1.13] - 2026-03-14

- Fixed
  - Avoidance of targets in some circumstances when the target is `L` or `XL` and the ship is `M` or `S`.
- Improved
  - Implemented extra `push` on subordinates to attack the desired target.
  - Checking and sending ships to `repair` for ships under this order's control and their subordinates.
- Implemented
  - Reassigning the order and its parameters in case the primary ship was destroyed and replaced by game mechanics. Previously, the order was just stopped in this case.

## [1.12] - 2026-01-30

- Fixed
  - Order breaks attack "dangerous" enemy ships when `KUDA AI tweaks` installed.

- Improved
  - Added `Protect Sector` options menu in the `Extension Options` if the `Mod Support APIs` extension is installed.
  - Added `Enable debug log` option to log detailed information to the debug log.

## [1.11] - 2025-12-06

- Fixed
  - Order ignoring new enemy stations in some rare cases.
  - Error message generated by `DisengageHandler`.
- Improved
  - Improved the logic of resupply checks.
  - Other small improvements and code cleanups.

## [1.10] - 2025-08-07

- Fixed
  - Fixed possible incompatibility with `move_to` command in the `X4: Foundations 8.00` and upper.

- Improved
  - Targets handling in non-shared mode.

## [1.09] - 2025-05-18

- Fixed
  - `Mimic` mode not started correctly.

- Changed
  - If `experimental` order of `Attack Station` is selected but fleet has ships smaller than `L`- the both `experimental` and `Attack Station` options are disabled.

## [1.08] - 2025-05-11

- Added
  - Internal (`experimental`) station attack order. Written from scratch positioning ships against stations, including reaction on stations drones attacks in non-OOS mode. Works only for fleets with `L` and `XL` ships. For only `L` ships - four and more ships are recommended.
  - Possibility to select station attack order - by default it is `Coordinate attack`. Other possibilities are `usual` one and `experimental` one.
  - Additional confirmation for the working in hazardous regions, like `The Void`. Please be aware - the order will stop working in the sectors with the hazardous regions without the confirmation.
  - Own icons for the `Protect Sector` and `Station attack` orders.

- Improved
  - Fully rewritten the logic of idling and scanning for enemy ships. Now it is more precise.
  - Implemented workaround for the repairing/restocking ships. By default Player owned ships can be repaired only in current sector. Please be aware - after installing version `1.08` the ships controlled by this order can go to be repaired/restocked after some time. It is not a bug, but a feature :-).

- Fixed
  - Fixed a reaction on attack on player's ships/stations by enemy drones.
  - Accidentally attacks from the non-enemies are not considered as an attack on the player ships/stations.

## [1.07] - 2025-03-16

- Added
  - `By negative relation` to set the relation to possible targets more precisely.
  - `Park exactly there` to set the exact position where the ship should park when it is not targets to fight against. Useful for big sectors.

- Improved
  - Idle flying when any parking is not set.
  - Attack of the stations via `Coordinate attack` in now visible, as it is run not as a script, but as an order.

## [1.06] - 2025-03-01

- Fixed
  - The Lost Ship Replacement not always works correctly.

## [1.05] - 2025-03-01

- Added
  - Support for the `Lost Ship Replacement` feature of version `7.50`
  - Added additional parameter to set a threshold from moving to target to attack it. In percentage of the radar range.

- Fixed
  - For version `7.50` and higher, boosters are used always, despite the `Avoid boosters usage` option.
  - The default value for `Disable on destruction threat` is `0 percent` - i.e. disabled this check.

## [1.04] - 2024-12-31

- Fixed
  - Slow floating to sector center when the "Park at sector core" is not enabled.

## [1.03] - 2024-12-26

- Added
  - Added possibility to use the `Protect Sector` order in the fleet mode with the `Mimic` order.

- Improved
  - Improved the target separation in case of  "sharing" is disabled - variable wait is solve the problem with the same target selection.

## [1.02] - 2024-12-20

- Added
  - Added parameter to set exact delay between scans.

- Fixed
  - Fixed a bug with approaching to the target - if it has equal speeds the catching is never happened.
  - Added additional small delay in the approaching routine to prevent freezing

- Improved
  - Improved the experience gaining

## [1.01] - 2024-12-13

- Added
  - Added option to protect ships and stations in the desired sector via reaction on attacks on them by hostile ships.
  - Added option to record events to the logbook, including starts, travel to desired sector, flying to the target, attacking the target, destroying the target, etc.

- Changed
  - Between scans it uses `move.idle` script.
  - Changed the type of option to disable on destruction threat: from boolean to the percentage of hull to make this order disabled.

- Improved
  - Approaching to the target is rewritten.
  - Attack of the ship is now under control of the `order.fight.attack.object` script.

## [1.00] - 2024-12-06

- Added
  - Initial release of the Protect Sector extension.
  - Allows protection of a sector from hostile ships.
  - Configuration options for home sector, attack stations, attack ships, attack farther from stations, attack only visible targets, attack only hostile targets, pursue fleeing targets, share target with other, preserve shield energy, and disable on destruction threat.
  - Compatibility with X4: Foundations 7.1.
