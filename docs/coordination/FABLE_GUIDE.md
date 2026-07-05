# Fable & Antigravity - Coordination Guide

Welcome! This workspace is configured for dual-agent collaborative pair programming between:
- **Fable (Claude Code)**: Steers the big-picture vision, WEG Star Wars D6 game systems architecture, quest writing, and gameplay balancing.
- **Antigravity (Gemini)**: Steers the detail implementation, scene builds, visual playtests, compile stability, and GDScript coding.

---

## 1. How We Communicate

We communicate asynchronously and coordinate work through the **Model Context Protocol (MCP)** server deployed inside the workspace:

- **JSON Database**: [board.json](file:///c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype/docs/coordination/board.json) (authoritative status database).
- **Markdown Dashboard**: [board.md](file:///c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype/docs/coordination/board.md) (auto-generated visual status dashboard).
- **MCP Server Entrypoint**: [mcp_server.py](file:///c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype/docs/coordination/mcp_server.py) (stdio transport host).

---

## 2. MCP Server Configuration

To register this coordination server inside your local **Claude Code** (or VS Code Claude Desktop), copy the following config block into your Claude settings file (e.g. `%APPDATA%\Claude\claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "fable-coordinator": {
      "command": "python",
      "args": [
        "c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype/docs/coordination/mcp_server.py"
      ],
      "cwd": "c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype"
    }
  }
}
```

---

## 3. Exposed Coordination Tools

Once loaded, Claude Code will natively have access to the following tools:

1. `get_board()`: Read the current directives and status of all tasks.
2. `add_task(id, title, description, assigned_to)`: Create a new task (assign to `"Antigravity"` to cue implementation).
3. `update_task(id, status, log_entry)`: Update progress or mark a task as completed.
4. `add_directive(content)`: Post architectural rules, design instructions, or vision shifts.

---

## 4. Coordination Workflow

1. **Fable (Claude Code)** analyzes requirements, writes design files, posts new tasks/directives using `add_task` / `add_directive`, and logs their purpose.
2. **Antigravity (Gemini)** detects the new tasks assigned to it, implements the code, compiles the assets, runs tests, completes the tasks using `update_task`, and updates the walkthrough logs.
3. Both agents read the [board.md](file:///c:/Users/btgla/Documents/Codex/2026-06-14/i-d-like-you-to-create/outputs/SW_MMO_Prototype/docs/coordination/board.md) dashboard to maintain shared context.
