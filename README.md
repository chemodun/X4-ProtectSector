# Protect Sector

This extension allows you to protect a sector from being harassed by hostile ships.
This is useful when you want to prevent hostile ships to attack your ships and stations. Or when you want to prevent from building in a sector.

## Compatibility

Compatible with `X4: Foundations 7.10` and upper. At least it written and tested with versions `7.10` and `7.50`.

## Features

- Always the closest possible target will be selected to attack.
- Several ships/fleets with one order can work in one sector or crossed sectors.
- Not recommended to use single ship - the fleet is always better.
- `Mimic` order in a fleet is fully supported. But, again, not set single ship to mimic mode - use the fleet instead.
- The `Lost Ship Replacement` feature of version `7.50` is fully supported.
- The own (`experimental`) order for station attacks is available.
- The workaround for player ships repairing/restocking not only in current sector is implemented.
- From version `1.08` have own icons for the `Protect Sector` and `Station attack` orders.

## Download

You can download the latest version via Steam client - [Protect Sector](https://steamcommunity.com/sharedfiles/filedetails/?id=3379427822)
Or you can do it via the [Nexus Mods](https://www.nexusmods.com/x4foundations/mods/1566)

## Executing the order

You can select the order as any other, like "Protect Station" or "Protect Ship", from the "Combat" section of  orders.
Please be aware - this order requires the ship captain to have at least **two stars** in the "Pilot" skill.

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

#### Use "Coordinate attack"

`Enabled` by default.

If enabled, the ship will use the "Coordinate Attack" order to attack the stations. It will be used for the stations only, not for the ships.
If disabled, the ship will use the usual "Attack" order to attack the stations.

#### Use experimental "Attack Station"

`Disabled` by default.
If enabled, the ship will use the experimental "Attack Station" order to attack the stations. It will be used for the stations only, not for the ships.
Will work only if the ships in a fleet has `L` or `XL` classes only. Otherwise, the order will be ignored, and selection from previous parameter will be used.
For `L` only - four and more ships are recommended.

##### Important notice

If Use experimental "Attack Station" selected, the ship will use the `experimental` order independently of the order type selected in the previous parameter.

#### Common warning for station attacks

In non-OOS mode, i.e. when the Player is in the same sector, the stations drones will attack the ships. The appropriate logic to react on this event is implemented in `experimental` order, and working not bad :-).
But still not recommended to be in the same sector with the ship, independently of the order type selected.

### Attack Ships

You can select exact ship types:

- XL
- L
- M
- S

By default are set depending on the player ship type.

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

### By negative relation

This is a slider to define the relation to the `Player`. Take in account - relation is shown as `positive` value, due to limitation of the game engine.
So, if you want to attack the ships with relation `-10` and lower - you have to set the value to `10`.
Default value is `25`, i.e. attack the ships with relation `-25` and lower.

Please take in account -  when previous parameter is enabled, you can set this one in between 25 and 30 (-25 and -30 relation).
If the `Attack only hostile targets` is disabled - the value can be set in between 0 and 30 (0 and -30 relation).
**Use it carefully.**

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

### Attack distance: percentage of radar range

This setting allows you to define the ship behavior when the target is identified and selected.
The attack de facto contains two stages:

- The ship is trying to reach the target till some acceptable distance. This distance is defined as a percentage of the radar range.
- The ship is trying to attack the target when it is in the acceptable distance.

### Avoid boosters usage

`Disabled` by default.

If enabled, the ship will not use the boosters to increase the speed. In game version prior `7.50` it will help to preserve the shield energy. For version `7.50` and higher, boosters are used always, despite the `Avoid boosters usage` option.

### Disable on destruction threat

It is a percentage of hull of the target to make this order disabled. Useful when you want to achieve more abandoned ships.

By default, it is `0 percent` - i.e. disabled this check.

If set to non-zero value, the ship will stop attacking when hull is less than desired percent.

### Park at sector core

`Disabled` by default.

If enabled, the ship will try to park at the sector core, when it is not targets to fight against.

### Park exactly there

It's `optional` parameter, it means - it can be skipped to set.
Moreover, if `Park at sector core` is enabled - this parameter will not only be ignored, its value will be cleared. So, if you want to park exactly there - disable the `Park at sector core` option.
To set the value of this parameter - you have to select the exact position on the galaxy map inside the appropriate sector.

#### Important Notice

If the sector, selected in this parameter, is not the same as the `Home Sector` - the `Home Sector` will be changed to the selected one.

### Delay between scans, seconds

Default value is `4 seconds`.
If you want - you can set it in between 1 and 90 seconds, with step 4 seconds. Bigger value will make less load on the CPU...

### Ignore the threats of Hazardous zones

`Disabled` by default.

Please take in account, some sectors are not safe, even if the ship is not attacked. For example, the sectors with the hazardous zones, like `The Void`. If ship is in the hazardous zone it's shield and then hull will be continuously damaged.
From version 1.08 `Protect Sector` order will automatically finished in such sectors. Appropriate message will be shown in the logbook.

If you still want to use this order in the hazardous zone - you can enable this option. But please be aware - the ships can be destroyed in the hazardous zone, as there is no good solutions to avoid such zones.

### Record to logbook

`Enabled` by default.

If enabled, the ship will record the events to the logbook. I.e. starts, travel to desired sector, flying to the target, attacking the target, destroying the target, etc.

## Situation when nothing to attack

If no Attack target is selected (i.e. no station and no any ship types are selected) - the ship's captain will periodically call to the player to inform about absence of the order.

## Special Thanks

Special thanks to the pilot [Assailer](https://steamcommunity.com/profiles/76561198087933619/myworkshopfiles/?appid=392160) for his awesome script ["Sector Patrol"](https://steamcommunity.com/sharedfiles/filedetails/?id=2458720435) which was used as a base for this one.

## Links

There is a thread on EgoSoft forum - [[Mod/AIScript] Order "Protect Sector"](https://forum.egosoft.com/viewtopic.php?p=5257237)
