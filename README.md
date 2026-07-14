# Trae Remote Game Demo

A Godot 4.6.1 web game demo used to verify this workflow:

Godot project source -> GitHub Actions cloud export -> GitHub Pages.

The current game is a small top-down survival prototype inspired by Vampire Survivors.

## Current gameplay

- Large 2D map, about 10 screens wide and 10 screens tall.
- Camera follows the player while staying inside the map boundary.
- Click or tap the map to move the player.
- Enemies spawn slightly outside the visible area and continuously move toward the player.
- The player has HP displayed above the character.
- Touching enemies damages the player. The game ends when HP reaches 0.
- Killing enemies grants score. Current score is shown in the top-left UI.
- Level-up choices appear when score reaches configured thresholds.

## Weapons and upgrades

At Level 1, choose one initial weapon:

- **Bullet**: automatically targets nearby enemies and fires projectiles.
- **Orbit Sword**: circles around the player and damages enemies it touches.

Level-up choices are staged:

- **Level 1**: choose one initial weapon only.
- **Level 2**: choose from stat upgrades only. The game randomly presents up to 3 available stats, so the stat list can grow beyond 3 options later.
- **Level 3+**: choose from normal one-shot upgrades.

Current stat upgrades:

- Frequency
- Damage
- Area
- Duration
- Speed
- Count
- Pierce

Current normal one-shot upgrades:

- **Fire**: hits can trigger a 50px explosion for 50 damage, with a 20 second global cooldown.
- **Poison**: hits apply poison for 10 damage per second over 5 seconds; reapplying resets duration.
- **Frost**: hits apply frostbite for 2 damage per second over 5 seconds and reduce enemy movement speed by 50%; reapplying resets duration.

The stat system is shared by weapons, with per-weapon translation rules documented in:

- `docs/skill-system-framework.md`
- `docs/skill-calibration.md`

## Project structure

```text
assets/                 Upgrade icons and imported assets
docs/                   Skill-system design and calibration notes
scenes/main.tscn        Main Godot scene
scripts/main.gd         Game loop, map, enemy spawning, UI, level-up logic
scripts/player.gd       Player movement, HP, damage handling
scripts/enemy.gd        Enemy config, movement, HP, score value
scripts/projectile.gd   Bullet projectile behavior
scripts/stat_math.gd    Shared upgrade math
scripts/weapons/        Weapon implementations
tools/                  Local helper scripts
web/custom_shell.html   Custom Godot web shell
```

## Local environment

The local Godot executable is expected at:

```text
D:\GodotEngine\Godot_v4.6.1-stable_win64_console.exe
```

Check the local environment:

```powershell
.\tools\check_env.ps1
```

Optional local Web export:

```powershell
.\tools\export_web.ps1
.\tools\serve_dist.ps1
```

Local export output is ignored by Git. The normal publishing flow can rely on GitHub Actions for Web export.

## GitHub Pages deployment

1. Create a public GitHub repository.
2. Push this project to the repository's `main` branch.
3. In the repository settings, open `Settings -> Pages`.
4. Set `Source` to `GitHub Actions`.
5. Push to `main` or manually run `Deploy Godot Web to GitHub Pages`.
6. Open the Pages URL after the workflow succeeds.

The workflow uses `chickensoft-games/setup-godot@v2` to prepare Godot 4.6.1 and export templates on GitHub's temporary Ubuntu runner.
