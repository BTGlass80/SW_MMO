from __future__ import annotations

import datetime as dt
import importlib.util
import io
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
	sys.path.insert(0, str(PROJECT_ROOT))

_spec = importlib.util.spec_from_file_location(
	"durable_loop",
	str(PROJECT_ROOT / "tools" / "durable_loop.py"),
)
durable_loop = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(durable_loop)


class TestDefaultPrompt(unittest.TestCase):
	def test_prompt_sets_project_direction(self):
		prompt = durable_loop.default_prompt("C:/prototype")
		self.assertIn("C:/prototype", prompt)
		self.assertIn("WEG Star Wars D6", prompt)
		self.assertIn("not a one-to-one MUSH port", prompt)
		self.assertIn("check_project.ps1", prompt)
		self.assertIn("Do not touch SW_MUSH", prompt)


class TestLauncher(unittest.TestCase):
	def test_agent_launcher_shape(self):
		out = durable_loop.build_launcher(
			workdir="C:/prototype",
			prompt_file="C:/state/prompt.txt",
			log_dir="C:/state/logs",
			agent_command="codex exec -",
		)
		self.assertTrue(out.startswith("@echo off"))
		self.assertIn('cd /d "C:/prototype"', out)
		self.assertIn('type "C:/state/prompt.txt" | codex exec -', out)
		self.assertIn('> "C:/state/logs\\run_%TS%.log" 2>&1', out)
		self.assertIn("\r\n", out)

	def test_test_fire_launcher_does_not_call_agent(self):
		out = durable_loop.build_launcher(
			workdir="C:/prototype",
			prompt_file="prompt.txt",
			log_dir="C:/logs",
			agent_command="codex exec -",
			raw_action="echo OK",
		)
		self.assertNotIn("codex exec", out)
		self.assertIn("echo OK", out)


class TestTaskXml(unittest.TestCase):
	def setUp(self):
		self.start = dt.datetime(2026, 6, 14, 22, 30, 0)

	def test_recurring_task_has_durable_settings(self):
		xml = durable_loop.build_task_xml(
			"C:/state/launcher.cmd",
			start_dt=self.start,
			every_minutes=30,
		)
		self.assertIn("<Interval>PT30M</Interval>", xml)
		self.assertIn("<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>", xml)
		self.assertIn("<StartWhenAvailable>true</StartWhenAvailable>", xml)
		self.assertIn("<ExecutionTimeLimit>PT2H</ExecutionTimeLimit>", xml)
		self.assertIn("<StartBoundary>2026-06-14T22:30:00</StartBoundary>", xml)

	def test_one_shot_has_no_repetition(self):
		xml = durable_loop.build_task_xml("C:/state/launcher.cmd", start_dt=self.start)
		self.assertNotIn("<Repetition>", xml)
		self.assertIn("<Command>cmd.exe</Command>", xml)

	def test_xml_is_well_formed(self):
		import xml.dom.minidom as minidom

		xml = durable_loop.build_task_xml(
			"C:/state/launcher.cmd",
			start_dt=self.start,
			every_minutes=15,
		)
		minidom.parseString(xml)


class TestDryRun(unittest.TestCase):
	def test_dry_run_returns_zero(self):
		with redirect_stdout(io.StringIO()):
			rc = durable_loop.main(
				[
					"arm",
					"--in",
					"120",
					"--dry-run",
					"--workdir",
					str(PROJECT_ROOT),
					"--name",
					"UNITTEST-SWMMO-DL",
				]
			)
		self.assertEqual(rc, 0)
		self.assertFalse((durable_loop.STATE_ROOT / "UNITTEST-SWMMO-DL" / "task.xml").exists())


if __name__ == "__main__":
	unittest.main()
