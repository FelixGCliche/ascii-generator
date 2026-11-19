# AGENTS.md

Instructions for any coding agent (Claude Code, OpenCode, or otherwise) working in this repo.

## What this repo is

A Godot app, hosted in the browser, that converts an uploaded image into ASCII art. It is
based on Acerola's video "I Tried Turning Games Into Text".

The conversion is **layer-based**. Each pass of the pipeline (e.g. downsampling,
luminance → character mapping, edge detection, edge-direction characters, color) is its
own layer, with parameters the user can tune at runtime. Layers can be toggled and
adjusted without touching the others.

## Stack

- **Engine:** Godot 4.7 (GDScript). The version is pinned in `mise.toml`, which is the
  single source of truth: local dev and CI both resolve Godot from it.
- **Primary target:** Web (HTML5 export, deployed to Cloudflare Pages: previews on PRs to
  `main`; production is built by Cloudflare on push to `main`). A Windows desktop export
  (`win64`) is also built.
- **Tooling:** [mise](https://mise.jdx.dev) manages every tool: Godot, lefthook,
  [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlint`, `gdformat`),
  which mise installs with uv, and `wrangler` (Cloudflare CLI, via node). Git hooks run
  through lefthook pre-commit.

## Structure

- `project.godot`: project config. `export_presets.cfg` holds the export presets (`win64`, `html5`).
- `src/`: all game code and scenes (`src/scenes/main.tscn` is the main scene).
- `plug.gd` + `addons/gd-plug/`: plugin manager (gd-plug); other plugins (e.g. GUT) are installed by it and git-ignored.
- `*.test.gd` files in `src/`, next to the code they test: GUT tests. `.gutconfig.json` holds the GUT settings.
- `.github/actions/setup-godot`: installs Godot through mise, plus the matching export templates.
- `.github/actions/build-web-template`: builds a slimmed web export template from Godot source (cached) and
  installs it over the stock one, so `index.wasm` stays under Cloudflare's 25 MiB file limit. Its SCons args
  live in `tools/web-template/scons.args` (2D-only profile); a 3D project edits that file, or deletes it to
  use the stock template.
- `.github/workflows/build-deploy.yaml`: on PRs to `main`, runs lint → test (GUT) → export → deploy a Cloudflare Pages preview
  (config in `wrangler.jsonc`, headers in `deploy/_headers`). Production is built by Cloudflare on push to `main`.

## Tooling

- Install tools: `mise install` (Godot, lefthook, uv, gdtoolkit, node, wrangler)
- Install git hooks: `lefthook install`
- Lint: `gdlint ./` (rules in `.gdlintrc`)
- Format: `gdformat ./` (check only: `gdformat ./ -d`)
- Reimport assets (headless): `godot --headless --import`
- Install plugins (gd-plug): `godot --headless -s plug.gd install`
- Run tests (GUT): `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
- Export locally: `godot --headless --export-release html5 build/index.html`

## Working in this repo

- **Web constraints come first.** The web export runs on WebGL2, so use the
  Compatibility renderer: no compute shaders, no RenderingDevice. Implement passes as
  canvas/spatial shaders (e.g. via `SubViewport` chains) or on the CPU.
- One pass = one layer. A layer's tunable parameters should be exposed through
  `@export` vars or a resource, so the UI can bind to them generically.
- Keep layers independent. A layer reads the previous layer's output and writes its own;
  layers don't reach into each other's internals.
- Follow the class-definition order and naming rules in `.gdlintrc`.

## Version Control

- Commit messages and PR titles must follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): subject`
- Always include a scope — never omit it
- Keep commit messages short and concise (a single subject line; avoid bodies unless truly necessary)
- Branch names must follow [Conventional Branch v1.1.0](https://conventionalbranch.org/): `<type>/<description>`
- Never add a description/body to a PR — title only
- Never add a `Co-Authored-By` trailer (or any AI-attribution trailer) to a commit

## Responses

- Keep responses concise and to the point unless the user asks otherwise.

## Planning Mode

- Always ask clarifying questions.
- Never assume design, tech stack or features.
- Use deep-dive sub-agents to assist with research.
- Use deep-dive sub-agents to review the different aspects of your plan before presenting it to the user.

## Change/Edit mode

- Never implement features yourself when possible; use sub-agents!
- Identify changes from the plan that can be implemented in parallel, and use sub-agents to implement them efficiently.
- When using sub-agents to implement features, act as a coordinator only.
- Use the best model for the task: premium models for complex tasks (like coding) and mid-tier models for simpler tasks, like documentation.
- After completing features (large or small), always run `gdlint ./` and `gdformat ./ -d`, and
  confirm the project imports cleanly with `godot --headless --import`.

## Testing

- Tests use [GUT](https://gut.readthedocs.io/), installed by gd-plug (`godot --headless -s plug.gd install`).
  Run them with `godot --headless -s addons/gut/gut_cmdln.gd -gexit`; config is in `.gutconfig.json`.
- Tests live in the feature folder, next to the code they cover (`src/layers/layer.gd` → `src/layers/layer.test.gd`),
  and are discovered recursively under `src/`. There is no separate `test/` folder.
  Test files are named `*.test.gd`, extend `GutTest`, and test functions are named `test_*`.
- Add tests with every feature or fix. Test logic that can run headless (params, data, chaining, parsing);
  headless runs don't render, so shader output is checked manually with solo preview.
- Never assume your changes simply work, always test. Run the GUT command after changes, and again before opening a PR.
- If GUT can't be used for a change, ask the user whether testing should be skipped.
