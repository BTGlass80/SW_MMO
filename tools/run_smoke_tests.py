import os
import sys
import glob
import subprocess
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed

def run_test(test_path, project_root, godot_cmd):
    base_name = os.path.basename(test_path)
    label = base_name.replace("_", " ").replace(".gd", " ").title().strip()
    
    godot_exe = shutil.which(godot_cmd)
    if godot_exe is None:
        godot_exe = godot_cmd # Fallback

    args = [
        godot_exe,
        "--headless",
        "--path", project_root,
        "--script", f"res://scripts/tests/{base_name}"
    ]
    
    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            shell=False,
            timeout=60
        )
        
        # Filter standard editor warning boilerplate to keep stdout clean
        clean_lines = []
        for line in proc.stdout.splitlines():
            s = line.strip()
            if not s:
                continue
            if "UID duplicate detected" in s:
                continue
            if s.startswith("at:") and "_process_file_system" in s:
                continue
            if s.startswith("[") and "% ]" in s:  # editor loading progress
                continue
            if "loading_editor_layout" in s:
                continue
            if "Godot Engine v4" in s:
                continue
            if "https://godotengine.org" in s:
                continue
            if "ObjectDB instances leaked at exit" in s:
                continue
            if s.startswith("at: cleanup (core/object/object.cpp"):
                continue
            clean_lines.append(line)
            
        clean_stdout = "\n".join(clean_lines)
        
        # Check if the output actually succeeded
        ok = proc.returncode == 0 and not any(err in proc.stdout for err in ["SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:", "!is_inside_tree()"])
        
        return {
            "test": base_name,
            "label": label,
            "exit_code": proc.returncode,
            "stdout": clean_stdout,
            "stderr": proc.stderr,
            "ok": ok
        }
    except subprocess.TimeoutExpired:
        return {
            "test": base_name,
            "label": label,
            "exit_code": -1,
            "stdout": "",
            "stderr": "Timeout expired (60s limit reached under concurrency)",
            "ok": False
        }
    except Exception as e:
        return {
            "test": base_name,
            "label": label,
            "exit_code": -1,
            "stdout": "",
            "stderr": str(e),
            "ok": False
        }

def main():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    tests_dir = os.path.join(project_root, "scripts", "tests")
    
    # Find all _smoke.gd files
    test_files = glob.glob(os.path.join(tests_dir, "*_smoke.gd"))
    if "admin_auth_live_smoke.gd" not in [os.path.basename(f) for f in test_files]:
        test_files.append(os.path.join(tests_dir, "admin_auth_live_smoke.gd"))
    test_files.sort()
    
    godot_cmd = os.environ.get("GODOT_CONSOLE", "godot-console")
    
    print(f"Running {len(test_files)} smoke tests sequentially (concurrency limit: 1)...", flush=True)
    
    # Limit max workers to 1 to avoid disk/CPU cache locking thrash on Godot startup
    max_workers = 1
    
    failures = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(run_test, f, project_root, godot_cmd): f for f in test_files}
        
        for future in as_completed(futures):
            res = future.result()
            
            # If the test succeeded and there's no custom printout, print a concise OK line
            if res['ok']:
                if res['stdout'].strip():
                    print(f"{res['label']}:", flush=True)
                    print(res['stdout'].strip(), flush=True)
                else:
                    test_label = res['test'].replace(".gd", "")
                    print(f"{res['label']}: OK", flush=True)
            else:
                failures.append(res)
                print(f"\nERROR in {res['test']}:", file=sys.stderr, flush=True)
                if res['stdout'].strip():
                    print(f"Stdout:\n{res['stdout'].strip()}", file=sys.stderr, flush=True)
                if res['stderr'].strip():
                    print(f"Stderr:\n{res['stderr'].strip()}", file=sys.stderr, flush=True)

    if failures:
        print(f"\nFailed {len(failures)} out of {len(test_files)} tests.", file=sys.stderr, flush=True)
        for f in failures:
            print(f"  - {f['test']} (Exit code: {f['exit_code']})", file=sys.stderr, flush=True)
        sys.exit(1)
        
    print(f"\nAll {len(test_files)} smoke tests completed successfully.", flush=True)
    # Output token expected by check_project.ps1 count tracker
    print(f"SMOKE_COUNT:{len(test_files)}", flush=True)

if __name__ == "__main__":
    main()
