# Trae Remote Game Demo

A minimal Godot 4.6.1 web demo used to verify the workflow:

Godot project source → GitHub Actions cloud export → GitHub Pages.

## Demo behavior

- The page initially shows `欢迎`.
- Click the button and the text changes to `点击`.
- After 2 seconds, the text changes back to `欢迎`.

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

The current first test flow intentionally relies on GitHub Actions for Web export, so local export is optional.

## GitHub Pages deployment

1. Create a public GitHub repository.
2. Push this project to the repository's `main` branch.
3. In the repository settings, open `Settings → Pages`.
4. Set `Source` to `GitHub Actions`.
5. Push to `main` or manually run `Deploy Godot Web to GitHub Pages`.
6. Open the Pages URL after the workflow succeeds.

The workflow uses `chickensoft-games/setup-godot@v2` to prepare Godot 4.6.1 and export templates on GitHub's temporary Ubuntu runner.
