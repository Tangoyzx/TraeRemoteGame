# Skill System Reset Baseline

This document records the current reset state used as the starting point for the next skill-system design.

## Current runtime

- The player permanently starts with an independent basic attack. It is not a skill and does not occupy an upgrade option.
- The basic attack fires one projectile at the nearest enemy every `2.0s`.
- Each projectile deals `50` damage and has no pierce or elemental effects.
- The attack is implemented in `scripts/basic_attack.gd`; the projectile is implemented in `scripts/projectile.gd`.

## Preserved upgrade shell

- `scripts/main.gd` still contains `LEVEL_REQUIRED_SCORES`, level state, and the level-up popup UI.
- `UPGRADE_OPTIONS` is empty.
- `UPGRADES_ENABLED` is `false`, so score gains do not trigger the popup, pause the game, or change `Level 0`.
- Legacy option generation, selection, and application logic has been removed.

## Removed systems

- Orbit Sword, Drone Minion, and the old AutoShooter weapon.
- Shared stats, stat stacks, weighted pools, and legacy upgrade cards.
- Fire, poison, frost, electric, and advanced elemental effects.
- Enemy elemental debuffs, slows, paralysis, and damage-over-time support.

## Future boundary

The basic attack must remain separate from skill acquisition. Future upgrades may modify its fire interval or damage, but the attack itself should never be offered as a selectable skill. Define the new upgrade data model and the basic-attack modifier interface before enabling upgrade triggers again.
