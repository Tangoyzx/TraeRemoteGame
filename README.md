# Trae Remote Game Demo

A Godot 4.7.1 web game demo used to verify this workflow:

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
D:\GodotEngine\Godot_v4.7.1-stable_win64_console.exe
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

The workflow uses `chickensoft-games/setup-godot@v2` to prepare Godot 4.7.1 and export templates on GitHub's temporary Ubuntu runner.

## Cloudflare Pages deployment

This repository can also deploy the same Godot Web export to Cloudflare Pages:

```text
.github/workflows/deploy-cloudflare-pages.yml
```

Cloudflare Pages only needs to host static files. Godot does not run on Cloudflare.
The workflow builds the game on GitHub Actions, precompresses `index.wasm` to
`index.wasm.gz`, removes the raw `index.wasm`, copies Cloudflare headers from
`web/cloudflare/_headers`, and uploads `dist/` with Wrangler.

### Cloudflare setup

1. In Cloudflare, open `Workers & Pages`.
2. Create a Pages project using **Direct Upload**. Do not connect the Git
   repository to Cloudflare's own build system.
3. Use a stable project name, for example:

```text
trae-remote-game
```

4. Create a Cloudflare API token with permission to edit Cloudflare Pages for
   the target account.
5. In GitHub, open `Settings -> Secrets and variables -> Actions`.
6. Add repository secrets:

| Secret | Required | Description |
| --- | --- | --- |
| `CLOUDFLARE_ACCOUNT_ID` | Yes | Cloudflare account ID that owns the Pages project. |
| `CLOUDFLARE_API_TOKEN` | Yes | API token used by Wrangler to upload the build. |

7. Add repository variable:

| Variable | Required | Example | Description |
| --- | --- | --- | --- |
| `CLOUDFLARE_PAGES_PROJECT_NAME` | Yes | `trae-remote-game` | Existing Cloudflare Pages project name. |

### Deployment flow

Push to `main` or manually run `Deploy Godot Web to Cloudflare Pages` in
GitHub Actions. The workflow uploads these files:

```text
index.html
index.js
index.pck
index.wasm.gz
_headers
```

The custom Web shell fetches `index.wasm.gz` and decompresses it in the browser,
so Cloudflare should serve it as a normal static asset and must not add
`Content-Encoding: gzip` to that file.

After the workflow succeeds, open the Cloudflare Pages production URL, for
example:

```text
https://trae-remote-game.pages.dev
```

Verify that the game loads and that the top-center version label shows the
latest `GAME_VERSION`.

## Tencent Cloud Lighthouse deployment

This repository also includes an optional workflow for deploying the same Godot Web export to a Tencent Cloud Lighthouse server through SSH and `rsync`:

```text
.github/workflows/deploy-tencent.yml
```

The server only needs to host static files, for example with Nginx in the BT Linux Panel. Godot does not need to run on the server.

### GitHub Secrets

Configure these repository secrets before running `Deploy Godot Web to Tencent Cloud`:

| Secret | Required | Example / default | Description |
| --- | --- | --- | --- |
| `TENCENT_HOST` | Yes | `1.2.3.4` | Tencent Cloud Lighthouse public IP. |
| `TENCENT_SSH_PORT` | No | `22` | SSH port. |
| `TENCENT_SSH_USER` | Yes | `deploy` | SSH user used by GitHub Actions. |
| `TENCENT_SSH_KEY` | Yes | private key text | Private key matching the server user's `authorized_keys`. |
| `TENCENT_DEPLOY_PATH` | No | `/www/wwwroot/trae-remote-game` | Deployment root on the server. |

The workflow runs on pushes to `main` and on manual `workflow_dispatch`. It exports the Web build, keeps `index.wasm.gz`, removes the raw `index.wasm`, uploads files to:

```text
$TENCENT_DEPLOY_PATH/releases/<short-git-sha>/
```

Then it switches:

```text
$TENCENT_DEPLOY_PATH/current -> $TENCENT_DEPLOY_PATH/releases/<short-git-sha>
```

The newest 5 releases are retained for rollback.

### Server preparation

Recommended one-time setup with a dedicated deploy user:

```bash
sudo useradd -m -s /bin/bash deploy
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo touch /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh

sudo mkdir -p /www/wwwroot/trae-remote-game/releases
sudo chown -R deploy:deploy /www/wwwroot/trae-remote-game
```

Add the GitHub Actions public key to:

```text
/home/deploy/.ssh/authorized_keys
```

Make sure the server has `rsync` available and the Tencent Cloud firewall allows inbound SSH and HTTP traffic.

### Nginx static site root

Point the BT/Nginx site root to:

```text
/www/wwwroot/trae-remote-game/current
```

The custom Web shell fetches `index.wasm.gz` and decompresses it in the browser, so the server should serve that file as a normal static asset and should not add `Content-Encoding: gzip` to it.

Minimal Nginx server block:

```nginx
server {
    listen 80;
    server_name _;

    root /www/wwwroot/trae-remote-game/current;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.wasm$ {
        default_type application/wasm;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.wasm\.gz$ {
        default_type application/gzip;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.(js|pck|png|jpg|jpeg|gif|svg|ico|css)$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location = /index.html {
        add_header Cache-Control "no-cache";
    }
}
```

Manual rollback example:

```bash
cd /www/wwwroot/trae-remote-game
ln -sfn releases/<previous-sha> current
```
