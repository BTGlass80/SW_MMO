import sys
import json
import os
from datetime import datetime

# Setup paths relative to this script's directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BOARD_JSON_PATH = os.path.join(BASE_DIR, "board.json")
BOARD_MD_PATH = os.path.join(BASE_DIR, "board.md")

# Default database template
DEFAULT_DB = {
    "directives": [
        {
            "id": "dir_1",
            "timestamp": "2026-07-04T22:42:31",
            "author": "Fable (Claude Code)",
            "content": "Fable drives the big-picture vision, architectural design, and task assignments. Antigravity drives the local implementation, compilation, testing, and detail polishing."
        }
    ],
    "tasks": [
        {
            "id": "task_1",
            "title": "Establish Fable-Antigravity MCP Coordination Server",
            "description": "Deploy local stdio-based MCP server to coordinate between Claude Code and Antigravity inside the workspace.",
            "status": "completed",
            "assigned_to": "Antigravity",
            "created_at": "2026-07-04T22:42:31",
            "updated_at": "2026-07-04T22:42:31",
            "log": ["Initial MCP server deployed and handshake verified."]
        }
    ]
}

def load_db():
    if not os.path.exists(BOARD_JSON_PATH):
        save_db(DEFAULT_DB)
        return DEFAULT_DB
    try:
        with open(BOARD_JSON_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write(f"Error loading board.json: {e}\n")
        return DEFAULT_DB

def save_db(db):
    try:
        # Write JSON database
        with open(BOARD_JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(db, f, indent=2, ensure_ascii=False)
        # Render markdown visualization
        render_markdown(db)
    except Exception as e:
        sys.stderr.write(f"Error saving board: {e}\n")

def render_markdown(db):
    lines = []
    lines.append("# Fable & Antigravity - Project Coordination Board")
    lines.append(f"*Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n")
    
    lines.append("## Fable Directives")
    lines.append("These are high-level vision, rules, and design constraints issued by Fable:\n")
    for d in db.get("directives", []):
        lines.append(f"- **[{d['timestamp']}]** {d['content']}")
    lines.append("")
    
    lines.append("## Task Status Board")
    lines.append("| Task ID | Title | Status | Assigned To | Last Updated |")
    lines.append("| --- | --- | --- | --- | --- |")
    for t in db.get("tasks", []):
        status_emoji = "✅" if t["status"] == "completed" else "🚧" if t["status"] == "in_progress" else "❌" if t["status"] == "blocked" else "📝"
        lines.append(f"| `{t['id']}` | **{t['title']}**<br>*{t['description']}* | {status_emoji} `{t['status'].upper()}` | `{t['assigned_to']}` | {t['updated_at']} |")
    lines.append("")
    
    lines.append("## Detailed Task Log")
    for t in db.get("tasks", []):
        if t.get("log"):
            lines.append(f"### `{t['id']}`: {t['title']}")
            for entry in t["log"]:
                lines.append(f"- {entry}")
            lines.append("")
            
    with open(BOARD_MD_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

# Define tools list and schemas
TOOLS = [
    {
        "name": "get_board",
        "description": "Retrieve the current state of the project coordination board (all tasks and directives).",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "add_task",
        "description": "Create a new task on the coordination board.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "string", "description": "Unique task identifier (e.g. task_compile_assets)"},
                "title": {"type": "string", "description": "Short title of the task"},
                "description": {"type": "string", "description": "Detailed description of requirements"},
                "assigned_to": {"type": "string", "description": "Assignee: Antigravity or Fable", "enum": ["Antigravity", "Fable", "Unassigned"]}
            },
            "required": ["id", "title", "description"]
        }
    },
    {
        "name": "update_task",
        "description": "Update the status and log of an existing task.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "string", "description": "The task ID to update"},
                "status": {"type": "string", "description": "New status for the task", "enum": ["todo", "in_progress", "completed", "blocked"]},
                "log_entry": {"type": "string", "description": "Optional progress or completion comment to append to the log"}
            },
            "required": ["id", "status"]
        }
    },
    {
        "name": "add_directive",
        "description": "Add a high-level vision or architectural directive from Fable.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "The directive content or rule description"}
            },
            "required": ["content"]
        }
    }
]

def handle_request(req):
    method = req.get("method")
    params = req.get("params", {})
    req_id = req.get("id")

    if method == "initialize":
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "serverInfo": {
                "name": "fable-antigravity-coordinator",
                "version": "1.0.0"
            }
        }
        
    elif method == "tools/list":
        return {
            "tools": TOOLS
        }
        
    elif method == "tools/call":
        name = params.get("name")
        args = params.get("arguments", {})
        db = load_db()
        
        if name == "get_board":
            return {
                "content": [{"type": "text", "text": json.dumps(db, indent=2)}]
            }
            
        elif name == "add_task":
            new_task = {
                "id": args["id"],
                "title": args["title"],
                "description": args["description"],
                "status": "todo",
                "assigned_to": args.get("assigned_to", "Unassigned"),
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "log": []
            }
            db["tasks"].append(new_task)
            save_db(db)
            return {
                "content": [{"type": "text", "text": f"Successfully created task: {args['id']}"}]
            }
            
        elif name == "update_task":
            t_id = args["id"]
            found = False
            for t in db["tasks"]:
                if t["id"] == t_id:
                    t["status"] = args["status"]
                    t["updated_at"] = datetime.now().isoformat()
                    if args.get("log_entry"):
                        t["log"].append(args["log_entry"])
                    found = True
                    break
            if not found:
                raise Exception(f"Task not found: {t_id}")
            save_db(db)
            return {
                "content": [{"type": "text", "text": f"Successfully updated task: {t_id}"}]
            }
            
        elif name == "add_directive":
            new_dir = {
                "id": f"dir_{len(db['directives']) + 1}",
                "timestamp": datetime.now().isoformat(),
                "author": "Fable (Claude Code)",
                "content": args["content"]
            }
            db["directives"].append(new_dir)
            save_db(db)
            return {
                "content": [{"type": "text", "text": f"Added directive: {new_dir['id']}"}]
            }
            
        else:
            raise Exception(f"Unknown tool: {name}")
            
    elif method == "ping":
        return {}
        
    else:
        raise Exception(f"Method not supported: {method}")

def main():
    sys.stderr.write("Fable-Antigravity MCP coordination server started.\n")
    # Initialize DB on start
    load_db()
    
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        try:
            req = json.loads(line.strip())
            # Handle initialized notification (which is a JSON-RPC notification, no response required)
            if req.get("method") == "initialized":
                continue
                
            res = handle_request(req)
            response_payload = {
                "jsonrpc": "2.0",
                "id": req.get("id"),
                "result": res
            }
            sys.stdout.write(json.dumps(response_payload) + "\n")
            sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(f"Exception processing request: {e}\n")
            if "id" in req:
                err_response = {
                    "jsonrpc": "2.0",
                    "id": req["id"],
                    "error": {
                        "code": -32603,
                        "message": str(e)
                    }
                }
                sys.stdout.write(json.dumps(err_response) + "\n")
                sys.stdout.flush()

if __name__ == "__main__":
    main()
