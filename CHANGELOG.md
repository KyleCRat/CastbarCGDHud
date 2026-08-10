# Changelog

## [12.1.0-1] - 2026-08-10

### Features

- Added separate radial indicators for player casts, channels, and the global cooldown.
- Added a cast latency zone and an optional completion flash for the global cooldown.
- Added native game settings for HUD dimensions, colors, arc angles, fill direction, inversion, and background visibility.
- Added a movable, lockable HUD with a saved position, live settings preview, and test animation.

### Fixes

- Fixed the cast indicator ending when an unrelated spellcast success event fires.
- Added safe fallbacks when cast or cooldown timing is unavailable or protected.

### Compatibility

- Updated interface metadata for World of Warcraft 12.1.0.

### Packaging

- Added standardized repository text policy and release packager metadata.
