# Godot Catalyst

The most comprehensive MCP server for AI-powered [Godot 4.x](https://godotengine.org/) game development. **240+ tools** across 36 categories — more than any other Godot MCP.

Works with any MCP client: Claude Code, Cursor, Windsurf, Copilot, Cline, and more.

## Why Godot Catalyst?

| Feature | Godot Catalyst | GoPeak | godot-mcp-pro | Coding-Solo |
|---------|:-:|:-:|:-:|:-:|
| **Total tools** | **240+** | 110 | 169 | 15 |
| **Price** | **$15** | Free | $5 | Free |
| **LSP code intelligence** | **Yes** | Yes | No | No |
| **DAP debugging** | **Yes** | Yes | No | No |
| **Offline file parsing** | **Yes** | No | No | No |
| **CC0 asset search** | **Yes** | Yes | No | No |
| **AI asset generation** | **Yes** | No | No | No |
| **Input simulation** | **Yes** | No | Yes | No |
| **Performance profiling** | **Yes** | No | No | No |
| **Spatial intelligence** | **Yes** | No | No | No |
| **Convention enforcement** | **Yes** | No | No | No |
| **Networking tools** | **Yes** | No | No | No |
| **Localization tools** | **Yes** | No | No | No |
| **Visual testing** | **Yes** | No | No | No |
| **Dynamic tool modes** | **Yes** | Yes | Yes | No |
| **One-command install** | **Yes** | Yes | No | Yes |
| **Batch operations** | **Yes** | No | No | No |

## Quick Start

```bash
# One-command install
npx godot-catalyst --install-addon /path/to/your/godot-project
```

Or manually:

```bash
git clone https://github.com/shameindemgg/godot-catalyst.git
cd godot-catalyst && npm install && npm run build
```

## Architecture

```
AI Agent  <--stdio-->  TypeScript MCP Server  <--WebSocket:6505-->  Godot EditorPlugin
                              |
                       TCP:6005 (LSP)
                       TCP:6006 (DAP)
```

- **MCP Server** (TypeScript/Node.js) — Exposes 240+ tools via the MCP protocol over stdio
- **Godot Plugin** (GDScript) — Runs inside the Godot editor, receives commands over WebSocket
- **LSP Client** — Connects to Godot's built-in GDScript Language Server for code intelligence
- **DAP Client** — Connects to Godot's built-in Debug Adapter for debugging

## Features

### 240+ Tools across 36 categories

| Category | Tools | Description |
|----------|-------|-------------|
| Foundation | 2 | Connection status, ping |
| Scenes | 12 | Create, open, save, close, list, duplicate, reload scenes |
| Nodes | 14 | CRUD, properties, search, groups, instancing |
| Scripts | 10 | Create, edit, attach, detach, execute, search GDScript |
| Resources | 8 | CRUD, imports, dependencies, autoloads |
| Editor | 12 | Selection, undo/redo, settings, screenshots, tabs |
| Project | 10 | Project settings, filesystem, input actions, stats |
| Signals | 6 | List, connect, disconnect, emit signals |
| Build | 6 | Play/stop scenes, export projects |
| 2D | 8 | Sprites, collision, tilemap, camera, parallax |
| 3D | 10 | Meshes, materials, lights, CSG, environment |
| Animation | 10 | Animations, tracks, keyframes, AnimationTree |
| Audio | 6 | Audio players, buses, effects |
| Physics | 6 | Physics bodies, collision shapes, raycasts |
| Navigation | 5 | Navigation regions, agents, baking |
| Shaders | 6 | Shader create/edit/assign, parameters |
| Themes | 6 | Theme resources, colors, constants, styleboxes |
| Particles | 5 | GPU particles, materials, gradients, presets |
| TileMaps | 6 | TileMap cell operations, fill, clear |
| File Ops | 10 | Offline TSCN/TRES parsing, project.godot, GDScript templates |
| LSP | 10 | Diagnostics, completion, hover, definition, references, symbols, format, rename |
| Debug | 10 | Launch, breakpoints, step over/into/out, stack trace, variables |
| Batch | 5 | Batch operations, bulk get/set properties, create/delete nodes |
| **Docs** | **4** | **Offline Godot class reference search, class/method lookup** |
| **Input Simulation** | **7** | **Keyboard, mouse, touch, gamepad, actions, record/replay** |
| **Profiling** | **4** | **FPS, memory, draw calls, bottleneck detection, monitoring** |
| **Runtime** | **4** | **Runtime GDScript eval, live tree inspection, console output** |
| **CC0 Assets** | **5** | **Search Poly Haven, AmbientCG, Kenney for free game assets** |
| **AI Assets** | **3** | **Generate 3D models, textures, sounds via AI APIs** |
| **Asset Pipeline** | **2** | **Reimport assets, modify import settings** |
| **Spatial** | **4** | **Layout analysis, placement suggestions, overlap detection** |
| **Conventions** | **3** | **Naming/structure checks, auto-fix, custom rules** |
| **Analysis** | **3** | **Architecture overview, dead code detection, dependency graph** |
| **Plugins** | **2** | **Detect installed plugins and their capabilities** |
| **Networking** | **6** | **HTTP, WebSocket, multiplayer, RPC, sync setup** |
| **Localization** | **4** | **CSV translations, locale management** |
| **Visual Testing** | **4** | **Screenshots, pixel-diff comparison, video recording, test sequences** |
| **Visualization** | **2** | **Project map, architecture diagrams (Mermaid/DOT)** |
| **Integration Testing** | **2** | **GUT test runner, test results** |

### Dynamic Tool Modes

Not all MCP clients support 240+ tools. Use `GODOT_TOOL_MODE` to control which tools are registered:

| Mode | Tools | Use Case |
|------|-------|----------|
| `full` | ~240 | Claude Code, Cursor (default) |
| `lite` | ~80 | Clients with moderate tool limits |
| `minimal` | ~30 | Copilot Chat, constrained clients |
| `cli` | ~10 | Offline-only, no Godot needed |

## Setup

### Prerequisites

- [Node.js](https://nodejs.org/) >= 18
- [Godot 4.x](https://godotengine.org/download) editor

### 1. Install

**Option A: npx (recommended)**

```bash
npx godot-catalyst --install-addon /path/to/your/godot-project
```

**Option B: Clone**

```bash
git clone https://github.com/shameindemgg/godot-catalyst.git
cd godot-catalyst
npm install && npm run build
```

Then copy `godot-plugin/addons/godot_catalyst/` into your Godot project's `addons/` folder.

### 2. Enable the Plugin

Open your Godot project, go to **Project > Project Settings > Plugins**, enable **Godot Catalyst**.

### 3. Configure Your MCP Client

Add the server to your MCP client's configuration. Examples for popular clients:

<details>
<summary><strong>Claude Code</strong></summary>

Add to `~/.claude/settings.json` or project `.claude/settings.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/path/to/godot-catalyst/dist/index.js"],
      "env": {
        "GODOT_PROJECT_PATH": "/path/to/your/godot/project"
      }
    }
  }
}
```
</details>

<details>
<summary><strong>Cursor</strong></summary>

Add to `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/path/to/godot-catalyst/dist/index.js"],
      "env": {
        "GODOT_PROJECT_PATH": "/path/to/your/godot/project"
      }
    }
  }
}
```
</details>

<details>
<summary><strong>Windsurf / Cline / Other MCP Clients</strong></summary>

Most MCP clients use the same configuration format. Add the server with:

- **Command:** `node`
- **Args:** `["/path/to/godot-catalyst/dist/index.js"]`
- **Env:** `GODOT_PROJECT_PATH` set to your Godot project root

Refer to your MCP client's documentation for the exact config file location.
</details>

### 4. Enable LSP/DAP (optional)

For code intelligence and debugging tools, enable in Godot:

- **Editor > Editor Settings > Network > Language Server > Enable** (port 6005)
- **Editor > Editor Settings > Network > Debug Adapter > Enable** (port 6006)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_PROJECT_PATH` | (none) | Absolute path to the Godot project root (required) |
| `GODOT_TOOL_MODE` | `full` | Tool filtering: `full`, `lite`, `minimal`, `cli` |
| `GODOT_WS_PORT` | `6505` | WebSocket port for the Godot plugin |
| `GODOT_WS_HOST` | `127.0.0.1` | WebSocket host |
| `GODOT_PATH` | `godot` | Path to the Godot executable |
| `GODOT_LSP_PORT` | `6005` | GDScript Language Server port |
| `GODOT_DAP_PORT` | `6006` | Debug Adapter Protocol port |
| `GODOT_DOCS_PATH` | (none) | Path to Godot XML class reference docs |
| `MESHY_API_KEY` | (none) | API key for Meshy 3D model generation |
| `TRIPO_API_KEY` | (none) | API key for Tripo 3D model generation |

## Development

```bash
npm run build    # Compile TypeScript
npm run dev      # Watch mode
npm test         # Run tests
npm start        # Start the MCP server
```

## Testing

Tests use Node.js built-in test runner:

```bash
npm test
```

Tests cover the offline file parsers (TSCN, TRES, project.godot) which can run without a Godot instance.

## License

Proprietary — see [LICENSE](LICENSE) for details. The Godot editor plugin (`godot-plugin/`) is MIT-licensed.
