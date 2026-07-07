from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_SCRIPT = PROJECT_ROOT / "tools" / "pt1_bundle.ps1"


class Pt1SessionBundleTests(unittest.TestCase):
	def setUp(self):
		self.tmp_dir = Path(tempfile.mkdtemp(prefix="pt1_bundle_test_"))
		self.save_dir = self.tmp_dir / "save"
		self.log_dir = self.tmp_dir / "watchdog_logs"
		self.session_root = self.tmp_dir / "sessions"
		self.telemetry_path = self.save_dir / "telemetry" / "pt1_events.jsonl"
		self.gate_log_path = self.tmp_dir / "gate_source.txt"
		self.session_id = "PT1_UNIT"

		(self.save_dir / "characters").mkdir(parents=True)
		self.log_dir.mkdir(parents=True)
		self.telemetry_path.parent.mkdir(parents=True)

		(self.save_dir / "characters" / "pilot_1.json").write_text(
			json.dumps({"sheet": {"credits": 1000}}),
			encoding="utf-8",
		)
		(self.log_dir / "server_20260706_200000.log").write_text(
			"server started\nserver stopped\n",
			encoding="utf-8",
		)
		(self.log_dir / "watchdog_journal.log").write_text(
			"[2026-07-06 20:00:00] watchdog armed\n",
			encoding="utf-8",
		)
		self.telemetry_path.write_text(
			"\n".join(
				[
					json.dumps({"type": "sell", "character_id": "pilot_1", "price": 200, "ts": 1}),
					json.dumps({"type": "sink_fee", "character_id": "pilot_1", "amount": 50, "ts": 2}),
				]
			)
			+ "\n",
			encoding="utf-8",
		)
		self.gate_log_path.write_text("All checks passed.\n", encoding="utf-8")

	def tearDown(self):
		shutil.rmtree(self.tmp_dir, ignore_errors=True)

	def _powershell(self):
		exe = shutil.which("powershell") or shutil.which("pwsh")
		if exe is None:
			self.skipTest("PowerShell is not available")
		return exe

	def _run_bundle(self, action: str):
		cmd = [
			self._powershell(),
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			str(BUNDLE_SCRIPT),
			"-Action",
			action,
			"-SessionId",
			self.session_id,
			"-SaveDir",
			str(self.save_dir),
			"-LogDir",
			str(self.log_dir),
			"-TelemetryPath",
			str(self.telemetry_path),
			"-SessionRoot",
			str(self.session_root),
			"-GateLogPath",
			str(self.gate_log_path),
		]
		return subprocess.run(cmd, cwd=PROJECT_ROOT, text=True, capture_output=True, check=False)

	def test_start_and_close_create_operator_bundle(self):
		start = self._run_bundle("Start")
		self.assertEqual(start.returncode, 0, start.stdout + start.stderr)

		session_dir = self.session_root / self.session_id
		before_zip = session_dir / "persistence_before.zip"
		self.assertTrue(before_zip.exists())
		self.assertEqual((session_dir / "gate.txt").read_text(encoding="utf-8"), "All checks passed.\n")
		triage = (session_dir / "triage.md").read_text(encoding="utf-8")
		self.assertIn("P0 - Blocks Next PT1", triage)
		self.assertIn("Known-Issues Update", triage)
		self.assertTrue((session_dir / "operator_note.md").exists())
		with zipfile.ZipFile(before_zip) as archive:
			self.assertTrue(any(name.endswith("pilot_1.json") for name in archive.namelist()))

		close = self._run_bundle("Close")
		self.assertEqual(close.returncode, 0, close.stdout + close.stderr)

		self.assertTrue((session_dir / "persistence_after.zip").exists())
		self.assertTrue((session_dir / "watchdog_logs" / "server_20260706_200000.log").exists())
		self.assertTrue((session_dir / "watchdog_logs" / "watchdog_journal.log").exists())
		self.assertTrue((session_dir / "pt1_events.jsonl").exists())

		tally = (session_dir / "telemetry_tally.txt").read_text(encoding="utf-8")
		self.assertIn("pilot_1", tally)
		self.assertIn("TOTAL (faucet vs sink)", tally)
		self.assertIn("sell=1", tally)
		self.assertIn("sink_fee=1", tally)
		self.assertNotIn("WARNING: credit-bearing event types", tally)

		audit = self._run_bundle("Audit")
		self.assertEqual(audit.returncode, 0, audit.stdout + audit.stderr)

		(session_dir / "gate.txt").write_text("Smoke tests failed.\n", encoding="utf-8")
		bad_gate_audit = self._run_bundle("Audit")
		self.assertEqual(bad_gate_audit.returncode, 4)
		self.assertIn("gate.txt does not contain", bad_gate_audit.stdout)
		(session_dir / "gate.txt").write_text("All checks passed.\n", encoding="utf-8")

		tally_path = session_dir / "telemetry_tally.txt"
		original_tally = tally_path.read_text(encoding="utf-8")
		tally_path.write_text(
			original_tally + "\nWARNING: credit-bearing event types this tally does NOT count yet\n",
			encoding="utf-8",
		)
		bad_tally_audit = self._run_bundle("Audit")
		self.assertEqual(bad_tally_audit.returncode, 4)
		self.assertIn("unknown credit-bearing events", bad_tally_audit.stdout)
		tally_path.write_text(original_tally, encoding="utf-8")

		audit_requires_feedback = subprocess.run(
			[
				self._powershell(),
				"-NoProfile",
				"-ExecutionPolicy",
				"Bypass",
				"-File",
				str(BUNDLE_SCRIPT),
				"-Action",
				"Audit",
				"-SessionId",
				self.session_id,
				"-SessionRoot",
				str(self.session_root),
				"-RequireFeedback",
			],
			cwd=PROJECT_ROOT,
			text=True,
			capture_output=True,
			check=False,
		)
		self.assertEqual(audit_requires_feedback.returncode, 3)
		self.assertIn("*feedback*.md", audit_requires_feedback.stdout)

		(session_dir / "pilot_feedback.md").write_text("# feedback\n", encoding="utf-8")
		audit_with_feedback = subprocess.run(
			[
				self._powershell(),
				"-NoProfile",
				"-ExecutionPolicy",
				"Bypass",
				"-File",
				str(BUNDLE_SCRIPT),
				"-Action",
				"Audit",
				"-SessionId",
				self.session_id,
				"-SessionRoot",
				str(self.session_root),
				"-RequireFeedback",
			],
			cwd=PROJECT_ROOT,
			text=True,
			capture_output=True,
			check=False,
		)
		self.assertEqual(audit_with_feedback.returncode, 0, audit_with_feedback.stdout + audit_with_feedback.stderr)

		(self.save_dir / "characters" / "pilot_1.json").write_text(
			json.dumps({"sheet": {"credits": 9999}}),
			encoding="utf-8",
		)
		restore = self._run_bundle("Restore")
		self.assertEqual(restore.returncode, 0, restore.stdout + restore.stderr)
		restored = json.loads((self.save_dir / "characters" / "pilot_1.json").read_text(encoding="utf-8"))
		self.assertEqual(restored["sheet"]["credits"], 1000)
		self.assertTrue(any(path.name.startswith("save.restore_hold_") for path in self.tmp_dir.iterdir()))


if __name__ == "__main__":
	unittest.main()
