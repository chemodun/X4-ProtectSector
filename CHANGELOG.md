# Changelog

## [1.07] - 2025-03-15


## [1.06] - 2025-03-01

### Fixed

- The Lost Ship Replacement not always works correctly.

## [1.05] - 2025-03-01

### Added

- Support for the `Lost Ship Replacement` feature of version `7.50`
- Added additional parameter to set a threshold from moving to target to attack it. In percentage of the radar range.

### Fixed

- For version `7.50` and higher, boosters are used always, despite the `Avoid boosters usage` option.
- The default value for `Disable on destruction threat` is `0 percent` - i.e. disabled this check.

## [1.04] - 2024-12-31

### Fixed

- Slow floating to sector center when the "Park at sector core" is not enabled.

## [1.03] - 2024-12-26

### Added

- Added possibility to use the `Protect Sector` order in the fleet mode with the `Mimic` order.

### Improved

- Improved the target separation in case of  "sharing" is disabled - variable wait is solve the problem with the same target selection.

## [1.02] - 2024-12-20

### Added

- Added parameter to set exact delay between scans.

### Fixed

- Fixed a bug with approaching to the target - if it has equal speeds the catching is never happened.
- Added additional small delay in the approaching routine to prevent freezing

### Improved

- Improved the experience gaining

## [1.01] - 2024-12-13

### Added

- Added option to protect ships and stations in the desired sector via reaction on attacks on them by hostile ships.
- Added option to record events to the logbook, including starts, travel to desired sector, flying to the target, attacking the target, destroying the target, etc.

### Changed

- Between scans it uses `move.idle` script.
- Changed the type of option to disable on destruction threat: from boolean to the percentage of hull to make this order disabled.

### Improved

- Approaching to the target is rewritten.
- Attack of the ship is now under control of the `order.fight.attack.object` script.

## [1.00] - 2024-12-06

### Added

- Initial release of the Protect Sector extension.
- Allows protection of a sector from hostile ships.
- Configuration options for home sector, attack stations, attack ships, attack farther from stations, attack only visible targets, attack only hostile targets, pursue fleeing targets, share target with other, preserve shield energy, and disable on destruction threat.
- Compatibility with X4: Foundations 7.1.
