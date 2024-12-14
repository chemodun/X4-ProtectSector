# Changelog

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