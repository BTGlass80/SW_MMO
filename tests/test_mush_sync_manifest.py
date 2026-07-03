"""Unit tests for tools/mush_sync_manifest.py (weekly MUSH sync manifest tool).

These tests build a FAKE source tree under a tmp dir and point the tool's
`--mush-root` / a custom source spec at it -- they never touch the real
`C:\\SW_MUSH` (which is out of scope for an automated test and is strictly
read-only reference in this project).
"""

import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))

import mush_sync_manifest as msm  # noqa: E402


def _write(path, content=b"hello"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(content)


class _FakeTreeTestCase(unittest.TestCase):
    """Base class: builds a small fake MUSH tree + a matching source spec."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="mush_sync_manifest_test_")
        self.mush_root = os.path.join(self.tmp_dir, "fake_sw_mush")
        self.manifest_path = os.path.join(self.tmp_dir, "manifest.json")

        # Fixed files (mirrors TRACKED_FILES in production).
        _write(os.path.join(self.mush_root, "data", "skills.yaml"), b"skills v1\n")
        _write(os.path.join(self.mush_root, "data", "weapons.yaml"), b"weapons v1\n")

        # Glob dir: species/*.yaml (mirrors data/species/*.yaml).
        _write(os.path.join(self.mush_root, "data", "species", "human.yaml"), b"human v1\n")
        _write(os.path.join(self.mush_root, "data", "species", "wookiee.yaml"), b"wookiee v1\n")

        # Glob dir: docs/design/Guide_*.md.
        _write(os.path.join(self.mush_root, "docs", "design", "Guide_01_Core.md"), b"guide v1\n")
        # A non-matching file in the same dir must NOT be tracked.
        _write(os.path.join(self.mush_root, "docs", "design", "HANDOFF_notes.md"), b"handoff\n")

        # The db, always tracked as a single opaque file.
        _write(os.path.join(self.mush_root, "sw_mush.db"), b"binary-db-bytes\n")

        self.spec = {
            "files": ["data/skills.yaml", "data/weapons.yaml"],
            "dir_globs": [("data/species", "*.yaml"), ("docs/design", "Guide_*.md")],
            "always_files": ["sw_mush.db"],
        }

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _snapshot(self, note="test baseline"):
        manifest = msm.build_manifest(self.mush_root, note, self.spec)
        msm.write_manifest(manifest, self.manifest_path)
        return manifest

    def _diff_report(self):
        stored = msm.load_manifest(self.manifest_path)
        relpaths = msm.discover_source_paths(self.mush_root, self.spec)
        current_files = msm.build_file_records(self.mush_root, relpaths)
        return msm.compute_drift(stored["files"], current_files)


class DiscoverySourcePathsTests(_FakeTreeTestCase):
    def test_discovers_fixed_files_and_globs_but_not_non_matching_names(self):
        relpaths = msm.discover_source_paths(self.mush_root, self.spec)
        self.assertIn("data/skills.yaml", relpaths)
        self.assertIn("data/weapons.yaml", relpaths)
        self.assertIn("data/species/human.yaml", relpaths)
        self.assertIn("data/species/wookiee.yaml", relpaths)
        self.assertIn("docs/design/Guide_01_Core.md", relpaths)
        self.assertIn("sw_mush.db", relpaths)
        # HANDOFF_notes.md does not match the Guide_*.md pattern.
        self.assertNotIn("docs/design/HANDOFF_notes.md", relpaths)
        self.assertEqual(len(relpaths), 6)

    def test_missing_fixed_file_is_simply_omitted(self):
        spec = dict(self.spec)
        spec["files"] = list(self.spec["files"]) + ["data/does_not_exist.yaml"]
        relpaths = msm.discover_source_paths(self.mush_root, spec)
        self.assertNotIn("data/does_not_exist.yaml", relpaths)


class SnapshotThenDiffCleanTests(_FakeTreeTestCase):
    def test_snapshot_then_diff_reports_no_drift(self):
        manifest = self._snapshot()
        self.assertEqual(manifest["file_count"], 6)
        self.assertEqual(manifest["generated_note"], "test baseline")
        # Deterministic ordering: files dict written with sort_keys, so the
        # raw JSON on disk has sorted keys.
        with open(self.manifest_path, "r", encoding="utf-8") as handle:
            raw = handle.read()
        parsed = json.loads(raw)
        self.assertEqual(list(parsed["files"].keys()), sorted(parsed["files"].keys()))

        report = self._diff_report()
        self.assertFalse(report["has_drift"])
        self.assertEqual(report["added"], [])
        self.assertEqual(report["removed"], [])
        self.assertEqual(report["changed"], [])
        self.assertEqual(report["summary"]["unchanged"], 6)


class ChangedFileDetectionTests(_FakeTreeTestCase):
    def test_modified_file_is_reported_changed_with_size_delta(self):
        self._snapshot()
        skills_path = os.path.join(self.mush_root, "data", "skills.yaml")
        _write(skills_path, b"skills v2 -- much longer content now\n")

        report = self._diff_report()
        self.assertTrue(report["has_drift"])
        changed_paths = [entry["path"] for entry in report["changed"]]
        self.assertEqual(changed_paths, ["data/skills.yaml"])
        entry = report["changed"][0]
        self.assertNotEqual(entry["old_sha256"], entry["new_sha256"])
        expected_delta = entry["new_size"] - entry["old_size"]
        self.assertEqual(entry["size_delta"], expected_delta)
        self.assertGreater(entry["size_delta"], 0)
        self.assertEqual(report["summary"]["changed"], 1)
        self.assertEqual(report["summary"]["unchanged"], 5)


class AddedAndRemovedFileDetectionTests(_FakeTreeTestCase):
    def test_added_and_removed_files_are_both_reported(self):
        self._snapshot()

        # ADDED: a new file matching the Guide_*.md glob appears.
        _write(os.path.join(self.mush_root, "docs", "design", "Guide_02_New.md"), b"new guide\n")

        # REMOVED: a previously-tracked fixed file disappears.
        os.remove(os.path.join(self.mush_root, "data", "weapons.yaml"))

        report = self._diff_report()
        self.assertTrue(report["has_drift"])
        self.assertEqual(report["added"], ["docs/design/Guide_02_New.md"])
        self.assertEqual(report["removed"], ["data/weapons.yaml"])
        self.assertEqual(report["changed"], [])
        self.assertEqual(report["summary"]["added"], 1)
        self.assertEqual(report["summary"]["removed"], 1)


class UnreadableFileHandlingTests(_FakeTreeTestCase):
    def test_unreadable_file_is_recorded_non_fatally(self):
        # A directory masquerading as a tracked relpath raises OSError when
        # hash_file() tries to open() it -- exercises the UNREADABLE path
        # without relying on platform-specific chmod/ACL behavior.
        bogus_dir = os.path.join(self.mush_root, "data", "not_actually_a_file.yaml")
        os.makedirs(bogus_dir, exist_ok=True)

        records = msm.build_file_records(self.mush_root, ["data/skills.yaml", "data/not_actually_a_file.yaml"])
        self.assertIn("sha256", records["data/skills.yaml"])
        self.assertEqual(records["data/not_actually_a_file.yaml"], {"error": "UNREADABLE"})

    def test_persistent_unreadable_is_reported_but_not_counted_as_drift(self):
        old_files = {"weird.bin": {"error": "UNREADABLE"}}
        new_files = {"weird.bin": {"error": "UNREADABLE"}}
        report = msm.compute_drift(old_files, new_files)
        self.assertFalse(report["has_drift"])
        self.assertEqual(report["unreadable"], ["weird.bin"])
        self.assertEqual(report["changed"], [])

    def test_transition_to_unreadable_counts_as_changed(self):
        old_files = {"weird.bin": {"sha256": "abc", "size": 10}}
        new_files = {"weird.bin": {"error": "UNREADABLE"}}
        report = msm.compute_drift(old_files, new_files)
        self.assertTrue(report["has_drift"])
        self.assertEqual(len(report["changed"]), 1)
        self.assertEqual(report["changed"][0]["note"], "became UNREADABLE")


class ExitCodeTests(_FakeTreeTestCase):
    def _run_cli(self, argv):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = msm.main(argv)
        return code, stdout.getvalue(), stderr.getvalue()

    def test_snapshot_missing_mush_root_exits_2(self):
        code, _out, err = self._run_cli([
            "--mush-root", os.path.join(self.tmp_dir, "does_not_exist"),
            "--manifest-path", self.manifest_path,
            "snapshot", "--note", "n/a",
        ])
        self.assertEqual(code, 2)
        self.assertIn("not found", err)

    def test_diff_missing_mush_root_exits_2(self):
        code, _out, err = self._run_cli([
            "--mush-root", os.path.join(self.tmp_dir, "does_not_exist"),
            "--manifest-path", self.manifest_path,
            "diff",
        ])
        self.assertEqual(code, 2)
        self.assertIn("not found", err)

    def test_diff_missing_stored_manifest_exits_2(self):
        # No snapshot has been written yet.
        code, _out, err = self._run_cli([
            "--mush-root", self.mush_root,
            "--manifest-path", os.path.join(self.tmp_dir, "no_such_manifest.json"),
            "diff",
        ])
        self.assertEqual(code, 2)
        self.assertIn("no stored manifest", err)

    def test_full_cli_snapshot_then_clean_diff_exits_0(self):
        code, out, _err = self._run_cli([
            "--mush-root", self.mush_root,
            "--manifest-path", self.manifest_path,
            "snapshot", "--note", "cli baseline",
        ])
        self.assertEqual(code, 0)
        self.assertIn("files tracked", out)
        self.assertTrue(os.path.isfile(self.manifest_path))

        # Real CLI run uses the production DEFAULT_SOURCE_SPEC (via spec=None
        # inside cmd_snapshot/cmd_diff), but since our fake tree only has the
        # files matching our fixture, and the CLI path calls
        # discover_source_paths(root, None) which falls back to
        # DEFAULT_SOURCE_SPEC (the REAL production paths, e.g. data/skills.yaml
        # -- which DOES exist in our fixture, so this still works), we assert
        # a clean diff.
        code, out, _err = self._run_cli([
            "--mush-root", self.mush_root,
            "--manifest-path", self.manifest_path,
            "diff",
        ])
        self.assertEqual(code, 0)
        self.assertIn("NO DRIFT", out)

    def test_full_cli_diff_json_reports_drift_exit_1(self):
        self._run_cli([
            "--mush-root", self.mush_root,
            "--manifest-path", self.manifest_path,
            "snapshot", "--note", "cli baseline",
        ])
        _write(os.path.join(self.mush_root, "data", "skills.yaml"), b"changed via cli test\n")

        code, out, _err = self._run_cli([
            "--mush-root", self.mush_root,
            "--manifest-path", self.manifest_path,
            "diff", "--json",
        ])
        self.assertEqual(code, 1)
        payload = json.loads(out)
        self.assertTrue(payload["has_drift"])
        self.assertEqual([entry["path"] for entry in payload["changed"]], ["data/skills.yaml"])


if __name__ == "__main__":
    unittest.main()
