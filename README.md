# Protect Sector

This extension allows you to protect a sector from being harassed by hostile ships.
This is useful when you want to prevent hostile ships to attack your ships and stations. Or when you want to prevent from building in a sector.

## Compatibility
Compatible with `X4: Foundations 7.1`. At least it written and tested with this version.

## General information
Always the closest possible target will be selected to attack.
Several ships/fleets with one order can work in one sector or crossed sectors.
Not recommended to use single ship - the fleet is always better.
`Mimic` order in a fleet is fully supported.
But, again, not set single ship to mimic mode - use the fleet instead.

## Executing the order

You can select the order as any other, like "Protect Station" or "Protect Ship", from the "Combat" section of  orders.
Please be aware - this order required the ship captain to have at least two stars in the "Pilot" skill.

## Configuration

There are a several configuration options available. You can see all of them on a screenshot.

### Home Sector
This is a sector which will be protected. You can select it from the list of discovered sectors.
If you select not current sector, the ship will fly to the selected sector to some "safe" point before to start protecting it.

It can be any known sector, even if it is not yours.

### Attack Stations

`Disabled` by default.

If enabled, hostile stations in the protected sector will be attacked by ship and his squad.
It uses the specific logic to attack stations - equal to "Coordinate Attack" from the context menu.
With only one exception - the syncpoint will not be created. So, all squad ships will form the similar order but will not wait for each other.

### Attack Ships
You can select exact ship types:
- XL
- L
- M - `enabled` by default
- S - `enabled` by default

By default, the S and M ships are selected.

If it will find a hostile squad - it will not be attacked, if it contains at least one ship of the type higher than highest selected one.

### Attack farther from stations
There is a slider to define a minimal distance from the possible target to the hostile station. If the distance is less than the defined value, the ship will be selected as a target.
If value is 0 - the distance will not be checked.

Default value is `0`.

### Attack only visible targets

`Enabled` by default.

Used to prevent the ship from attacking the target, which is not revealed yet or not visible for the player.

It has slightly different behavior for stations and ships:
- For stations - the station should be visible on a map. So - it has to be revealed, but it is not required to be in a live view, i.e. in radar range of your ships, stations, satellites, etc.
- For ships - the ship should be visible online. So - it has to be in a radar range of your ships, stations, satellites, etc.

### Attack only hostile targets

`Enabled` by default.

If enabled, the ship will attack only hostile targets. It will use the appropriate command to filter the targets.

### Protect our ships and stations in sector

`Enabled` by default.

If enabled, the ship will react on the event when the player's ships or stations are attacked in the sector. It will try to protect them by attacking the hostile ships.


### - except military ships

`Enabled` by default.

If enabled, the ship will not protect the military ships. It will not attack the hostile ships, which are attacking the military ships.


### Pursue fleeing targets

`Disabled` by default.

If enabled, the ship will pursue the target, which is trying to flee after is being attacked.

### Share target with other

`Enabled` by default.

If you have more than one ship or squad with the same order, you can disable this option to prevent them from attacking the same target.

### Preserve shield energy

`Disabled` by default.

If enabled, the ship will not use the boosters to increase the speed. It will try to preserve the shield energy.

### Disable on destruction threat

It is a percentage of hull to make this order disabled.

By default, it is `40 percent`. To disable this check - set it to 0.

If set to non-zero value, the ship will stop attack and protecting when hull is less than desired percent and will try to flee.

### Park at sector core

`Disabled` by default.

If enabled, the ship will try to park at the sector core, when it is not targets to fight against.

### Delay between scans, seconds

Default value is `4 seconds`.
If you want - you can set it in between 1 and 90 seconds, with step 4 seconds. Bigger value will make less load on the CPU...

### Record to logbook

`Enabled` by default.

If enabled, the ship will record the events to the logbook. I.e. starts, travel to desired sector, flying to the target, attacking the target, destroying the target, etc.

## Situation when nothing to attack

If no Attack target is selected (i.e. no station and no any ship types are selected) - the ship's captain will periodically call to the player to inform about absence of the order.

## Special Thanks

Special thanks to the pilot [Assailer](https://steamcommunity.com/profiles/76561198087933619/myworkshopfiles/?appid=392160) for his awesome script ["Sector Patrol"](https://steamcommunity.com/sharedfiles/filedetails/?id=2458720435) which was used as a base for this one.

## Links

There is a thread on EgoSoft forum - [[Mod/AIScript] Order "Protect Sector"](url=https://forum.egosoft.com/viewtopic.php?p=5257237)