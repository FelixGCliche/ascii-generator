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
- **Primary target:** Web (HTML5 export, deployed to GitHub Pages). A Windows desktop
  export (`win64`) is also built.
- **Tooling:** [mise](https://mise.jdx.dev) manages every tool: Godot, lefthook, and
  [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlint`, `gdformat`),
  which mise installs with uv. Git hooks run through lefthook pre-commit.

## Structure

- `project.godot`: project config. `export_presets.cfg` holds the export presets (`win64`, `html5`).
- `src/`: all game code and scenes (`src/scenes/main.tscn` is the main scene).
- `.github/actions/setup-godot`: installs Godot through mise, plus the matching export templates.
- `.github/workflows/build-deploy.yaml`: on PRs to `main`, runs lint → export → deploy to Pages.

## Tooling

- Install tools: `mise install` (Godot, lefthook, uv, gdtoolkit)
- Install git hooks: `lefthook install`
- Lint: `gdlint ./` (rules in `.gdlintrc`)
- Format: `gdformat ./` (check only: `gdformat ./ -d`)
- Reimport assets (headless): `godot --headless --import`
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
