"""Unit tests for tools/telemetry_tally.py (Wave G G18 faucet/sink tally)."""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))

import telemetry_tally  # noqa: E402


def _write_jsonl(lines):
    handle = tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", suffix=".jsonl", delete=False)
    for line in lines:
        handle.write(line + "\n")
    handle.close()
    return handle.name


class TelemetryTallyTests(unittest.TestCase):
    def test_inflow_outflow_net_per_character(self):
        events = [
            {"type": "loot", "character_id": "char_a", "loot_credits": 60, "salvage_credits": 10, "ts": 100},
            {"type": "sell", "character_id": "char_a", "price": 40, "ts": 160},
            {"type": "buy", "character_id": "char_a", "price": 30, "ts": 220},
            {"type": "repair", "character_id": "char_a", "cost": 25, "ts": 280},
            {"type": "death", "character_id": "char_a", "credits": 500, "ts": 300},
            {"type": "buy", "character_id": "char_b", "price": 75, "ts": 120},
            {"type": "window_resolve", "window": 3, "envelope_count": 1, "ts": 130},
        ]
        path = _write_jsonl([json.dumps(event) for event in events])
        try:
            per_char, unknown, counts = telemetry_tally.tally(
                telemetry_tally.read_events(path))
        finally:
            os.unlink(path)
        char_a = per_char["char_a"]
        # inflow = loot 60 (loot_credits is the total; salvage NOT double-counted) + sell 40
        self.assertEqual(char_a["inflow"], 100)
        # outflow = buy 30 + repair 25
        self.assertEqual(char_a["outflow"], 55)
        self.assertEqual(char_a["deaths"], 1)
        # death keeps credits (DIV-0006): the death event contributes NO wallet delta
        self.assertEqual(char_a["inflow"] - char_a["outflow"], 45)
        self.assertEqual(per_char["char_b"]["outflow"], 75)
        self.assertEqual(counts["window_resolve"], 1)
        self.assertFalse(unknown)

    def test_bounty_events_counted_not_flagged(self):
        # DIV-0022: place (escrow+fee OUTFLOW) + collect (payout INFLOW) + refund (INFLOW) + payoff
        # (sink OUTFLOW) must all be counted, never warned as unknown credit-bearing types.
        events = [
            {"type": "bounty_place", "character_id": "char_placer", "credits": 550, "escrow": 500, "fee": 50, "ts": 100},
            {"type": "bounty_collect", "character_id": "char_hunter", "payout": 500, "credits": 500, "ts": 200},
            {"type": "bounty_payoff", "character_id": "char_target", "cost": 750, "ts": 300},
            {"type": "bounty_refund", "character_id": "char_placer", "refund": 500, "ts": 310},
        ]
        path = _write_jsonl([json.dumps(event) for event in events])
        try:
            per_char, unknown, _ = telemetry_tally.tally(
                telemetry_tally.read_events(path))
        finally:
            os.unlink(path)
        self.assertEqual(per_char["char_placer"]["outflow"], 550)   # escrow + posting fee debited
        self.assertEqual(per_char["char_placer"]["inflow"], 500)    # pay-off refund returned the escrow
        self.assertEqual(per_char["char_hunter"]["inflow"], 500)    # payout collected
        self.assertEqual(per_char["char_target"]["outflow"], 750)   # pay-off settlement sink
        self.assertFalse(unknown)  # none flagged as unknown credit-bearing types

    def test_unknown_credit_bearing_type_is_reported_not_ignored(self):
        # A future faucet (e.g. quest rewards) must surface in the tally the day it
        # ships — the faucets-and-sinks rule depends on this being loud.
        path = _write_jsonl([json.dumps(
            {"type": "quest_reward", "character_id": "char_c", "reward_credits": 200, "ts": 10})])
        try:
            per_char, unknown, _ = telemetry_tally.tally(
                telemetry_tally.read_events(path))
        finally:
            os.unlink(path)
        self.assertEqual(per_char["char_c"]["inflow"], 0)  # not silently counted
        self.assertIn("quest_reward", unknown)

    def test_torn_and_blank_lines_are_skipped(self):
        path = _write_jsonl([
            json.dumps({"type": "sell", "character_id": "char_d", "price": 10, "ts": 5}),
            "",
            '{"type": "buy", "character_id": "char_d", "pri',  # torn tail mid-write
        ])
        try:
            events = telemetry_tally.read_events(path)
        finally:
            os.unlink(path)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "sell")


if __name__ == "__main__":
    unittest.main()
