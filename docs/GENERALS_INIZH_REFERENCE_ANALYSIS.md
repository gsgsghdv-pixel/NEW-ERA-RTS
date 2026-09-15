# Generals / Zero Hour INIZH reference analysis

The supplied INIZH.big was successfully parsed as a BIGF archive and inspected locally. This document records derived architecture findings only; original game data/assets are not copied into the repository.

## Archive inventory
- 135 files
- Core INI definitions include economy/game data, command buttons/sets, weapons, armor, locomotors, science, player templates, and object definitions.
- Object definitions are split by faction and specialist generals.

## Scale of the data-driven model
- 363 Weapon definitions in Weapon.ini
- 182 Locomotor definitions in Locomotor.ini
- 96 Science definitions in Science.ini
- 472 CommandSet definitions in CommandSet.ini
- 817 CommandButton definitions in CommandButton.ini
- 58 faction-building objects in FactionBuilding.ini
- 45 frontline faction unit definitions across the main USA/China/GLA infantry+vehicle files inspected

## Systems that matter for NEW ERA RTS
1. PlayerTemplate defines playable factions, starting buildings/units, intrinsic sciences, science command sets, colors and presentation.
2. Object/*.ini is the core data-driven unit/building layer: model, animations, condition states, upgrades, weapons, locomotion and command sets are composed per object.
3. Weapon.ini separates damage, range, projectile, fire FX, recoil, reload timing and damage behavior from unit objects.
4. Armor.ini provides damage-type resistance categories, enabling differentiated infantry/vehicle/building survivability.
5. Locomotor.ini provides movement speed, acceleration, braking, turning, terrain/surface restrictions and movement behavior.
6. CommandSet.ini + CommandButton.ini define the context-sensitive RTS control bar and production/ability actions.
7. Science.ini provides rank-gated progression and faction/general special abilities.
8. AIData.ini contains explicit wealth thresholds, build/team rates, guard scan behavior, line-of-sight attack behavior and skirmish base-defense parameters.
9. Animation2D.ini demonstrates reusable UI/combat feedback animations rather than hard-coded one-off effects.

## Design consequence
NEW ERA RTS should move toward a data-driven RTS architecture rather than a collection of hard-coded button handlers. The Godot layer should consume definitions for factions, structures, units, weapons, armor, locomotion, production, upgrades, science and AI priorities.

## Current priority
- Keep the opening cinematic requirement intact.
- Make base construction and prerequisites spatial/footprint-aware.
- Replace passive placeholder economy with resource nodes and logistics.
- Build a real production/command hierarchy.
- Add target acquisition, attack/move orders, weapon timing and damage types.
- Add condition states for damaged/rubble behavior and destruction.
- Expand AI into base building, production, defense and attack waves.
- Keep the supplied Attack animated cursor as a combat-feedback asset.

This analysis is a technical reference for implementing original NEW ERA RTS systems; it is not a redistribution of the supplied game archive.
