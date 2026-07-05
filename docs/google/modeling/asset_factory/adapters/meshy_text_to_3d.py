#!/usr/bin/env python3
"""Meshy text-to-3D adapter for docs-only asset-factory experiments.

The script intentionally reads MESHY_API_KEY from the environment and never
writes it to disk. It stores redacted provider responses and downloaded review
artifacts under docs/gpt/asset_factory/generated/.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

try:
    import certifi
    import requests
except Exception:  # pragma: no cover - fallback keeps the adapter dependency-light.
    certifi = None
    requests = None


API_ROOT = "https://api.meshy.ai/openapi/v2/text-to-3d"


def main() -> int:
    parser = argparse.ArgumentParser(description="Meshy text-to-3D docs-only adapter")
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ["dry-run", "run-preview"]:
        p = sub.add_parser(name)
        p.add_argument("--spec", required=True, help="Spec JSON containing an assets array")
        p.add_argument("--asset-id", required=True, help="Asset id inside the spec")
        p.add_argument("--out-dir", required=True, help="Output directory for generated artifacts")
        p.add_argument("--poll-seconds", type=int, default=10)
        p.add_argument("--timeout-seconds", type=int, default=600)

    p_get = sub.add_parser("get")
    p_get.add_argument("--task-id", required=True)
    p_get.add_argument("--out-dir", required=True)
    p_get.add_argument("--download", action="store_true")

    args = parser.parse_args()

    if args.command in {"dry-run", "run-preview"}:
        spec = _load_asset_spec(Path(args.spec), args.asset_id)
        out_dir = Path(args.out_dir) / args.asset_id
        out_dir.mkdir(parents=True, exist_ok=True)
        request_body = _build_preview_body(spec)
        _write_json(out_dir / "request_body.json", request_body)
        _write_readme(out_dir, spec, request_body, submitted=args.command == "run-preview")
        if args.command == "dry-run":
            print(f"Dry run wrote {out_dir / 'request_body.json'}")
            return 0
        task_id = _create_preview(request_body)
        (out_dir / "task_id.txt").write_text(task_id, encoding="utf-8")
        task = _poll_task(task_id, args.poll_seconds, args.timeout_seconds)
        _write_json(out_dir / "provider_response_redacted.json", _redact_task(task))
        _download_task_assets(task, out_dir)
        _write_status(out_dir, task)
        print(f"Meshy preview complete: {task_id} -> {out_dir}")
        return 0

    if args.command == "get":
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        task = _get_task(args.task_id)
        _write_json(out_dir / "provider_response_redacted.json", _redact_task(task))
        if args.download:
            _download_task_assets(task, out_dir)
        _write_status(out_dir, task)
        print(f"Retrieved Meshy task: {args.task_id} -> {out_dir}")
        return 0

    parser.error(f"Unknown command {args.command}")
    return 2


def _load_asset_spec(path: Path, asset_id: str) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    for asset in data.get("assets", []):
        if asset.get("id") == asset_id:
            return asset
    raise SystemExit(f"Asset id not found in spec: {asset_id}")


def _build_preview_body(spec: dict[str, Any]) -> dict[str, Any]:
    body = dict(spec.get("api_body", {}))
    body.setdefault("mode", "preview")
    body.setdefault("target_formats", ["glb"])
    body["prompt"] = spec["prompt"]
    if len(body["prompt"]) > 600:
        raise SystemExit("Meshy prompt exceeds 600 characters")
    if body.get("mode") != "preview":
        raise SystemExit("This adapter's run-preview command only creates preview tasks")
    return body


def _api_headers() -> dict[str, str]:
    key = os.environ.get("MESHY_API_KEY")
    if not key:
        raise SystemExit("MESHY_API_KEY is not set")
    return {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def _request_json(method: str, url: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    if requests is not None:
        try:
            response = requests.request(
                method,
                url,
                headers=_api_headers(),
                json=body,
                timeout=60,
                verify=certifi.where() if certifi is not None else True,
            )
            if response.status_code >= 400:
                raise SystemExit(f"Meshy HTTP {response.status_code}: {response.text}")
            return response.json() if response.text else {}
        except requests.RequestException as exc:
            raise SystemExit(f"Meshy request failed: {exc}") from exc

    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method, headers=_api_headers())
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Meshy HTTP {exc.code}: {detail}") from exc


def _create_preview(body: dict[str, Any]) -> str:
    response = _request_json("POST", API_ROOT, body)
    task_id = response.get("result")
    if not task_id:
        raise SystemExit(f"Meshy create response did not include result: {response}")
    return str(task_id)


def _get_task(task_id: str) -> dict[str, Any]:
    return _request_json("GET", f"{API_ROOT}/{urllib.parse.quote(task_id)}")


def _poll_task(task_id: str, poll_seconds: int, timeout_seconds: int) -> dict[str, Any]:
    deadline = time.time() + timeout_seconds
    last_status = ""
    while True:
        task = _get_task(task_id)
        status = str(task.get("status", ""))
        progress = task.get("progress", "?")
        if status != last_status:
            print(f"Meshy task {task_id}: {status} {progress}%")
            last_status = status
        if status in {"SUCCEEDED", "FAILED", "CANCELED"}:
            return task
        if time.time() > deadline:
            raise SystemExit(f"Timed out waiting for Meshy task {task_id}")
        time.sleep(max(1, poll_seconds))


def _download_task_assets(task: dict[str, Any], out_dir: Path) -> None:
    if task.get("status") != "SUCCEEDED":
        return
    downloads = {
        "model.glb": task.get("model_urls", {}).get("glb"),
        "thumbnail.png": task.get("thumbnail_url"),
        "alpha_thumbnail.png": task.get("alpha_thumbnail_url"),
    }
    for name, url in downloads.items():
        if not url:
            continue
        _download_url(str(url), out_dir / name)


def _download_url(url: str, target: Path) -> None:
    if requests is not None:
        try:
            response = requests.get(
                url,
                timeout=120,
                verify=certifi.where() if certifi is not None else True,
            )
            if response.status_code >= 400:
                raise SystemExit(f"Download HTTP {response.status_code} for {target.name}: {response.text}")
            target.write_bytes(response.content)
            return
        except requests.RequestException as exc:
            raise SystemExit(f"Download failed for {target.name}: {exc}") from exc

    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            target.write_bytes(resp.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Download HTTP {exc.code} for {target.name}: {detail}") from exc


def _redact_task(value: Any) -> Any:
    if isinstance(value, dict):
        redacted: dict[str, Any] = {}
        for key, item in value.items():
            if key.endswith("_url") and isinstance(item, str):
                redacted[key] = _redact_url(item)
            elif key.endswith("_urls"):
                redacted[key] = _redact_task(item)
            else:
                redacted[key] = _redact_task(item)
        return redacted
    if isinstance(value, list):
        return [_redact_task(item) for item in value]
    if isinstance(value, str) and value.startswith("http"):
        return _redact_url(value)
    return value


def _redact_url(url: str) -> str:
    parsed = urllib.parse.urlsplit(url)
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))


def _write_status(out_dir: Path, task: dict[str, Any]) -> None:
    lines = [
        "# Meshy Task Status",
        "",
        f"Task id: `{task.get('id', '')}`",
        f"Type: `{task.get('type', '')}`",
        f"Status: `{task.get('status', '')}`",
        f"Progress: `{task.get('progress', '')}`",
        f"Consumed credits: `{task.get('consumed_credits', 'unknown')}`",
        "",
        "Downloaded files, if available:",
        "",
        "- `model.glb`",
        "- `thumbnail.png`",
        "- `alpha_thumbnail.png`",
        "",
        "Provider response is saved as `provider_response_redacted.json`; signed URLs are stripped.",
    ]
    (out_dir / "STATUS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_readme(out_dir: Path, spec: dict[str, Any], request_body: dict[str, Any], submitted: bool) -> None:
    lines = [
        "# Meshy Preview Request",
        "",
        f"Asset id: `{spec.get('id', '')}`",
        f"Display name: {spec.get('display_name', '')}",
        f"Submitted: `{submitted}`",
        "",
        "## Prompt",
        "",
        request_body["prompt"],
        "",
        "## Safety",
        "",
        "The API key is read from `MESHY_API_KEY` and is not written to this folder.",
    ]
    (out_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
