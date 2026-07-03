#!/usr/bin/env python3
"""Faucet/sink credit tally over the server's telemetry JSONL (Wave G G18).

The MUSH economy invariant — "faucets and sinks land together" — is enforceable
empirically now that telemetry keys every credit-bearing event to the PERSISTENT
character_id. This script turns "economy feel" into a number the loop can be held
to: per-character credit inflow (sell, loot) vs outflow (buy, repair), plus the
event mix. Run it on every PT1 session log.

Usage:
    python tools/telemetry_tally.py <path-to-events.jsonl> [--json]

The server writes the log to user://telemetry/events.jsonl, i.e. on Windows:
    %APPDATA%/Godot/app_userdata/<project>/telemetry/events.jsonl

Torn/blank lines are skipped (crash-safe append means a torn tail is expected).
Credit-bearing event types this script does NOT know yet are REPORTED, not
silently ignored — a new faucet must show up here the day it ships.
"""

import argparse
import json
import sys
from collections import Counter, defaultdict

# type -> credits extractor. INFLOW = credits entering a character's wallet.
INFLOW = {
    "sell": lambda e: int(e.get("price", 0)),
    "loot": lambda e: int(e.get("loot_credits", 0)),  # loot_credits = credits + salvage total
    # DIV-0022 (PvP bounties): a hunter's payout, and an escrow refund on pay-off / expiry.
    "bounty_collect": lambda e: int(e.get("payout", 0)),
    "bounty_refund": lambda e: int(e.get("refund", 0)),
}
# OUTFLOW = credits leaving a character's wallet (sinks).
OUTFLOW = {
    "buy": lambda e: int(e.get("price", 0)),
    "repair": lambda e: int(e.get("cost", 0)),
    # DIV-0022 (PvP bounties): placement debits escrow + a non-refundable posting fee; pay-off is a sink.
    # NOTE: only the fee is a NET sink (escrow returns as a bounty_collect/bounty_refund inflow), so
    # place+collect net to the fee — exactly the faucets-and-sinks intent.
    "bounty_place": lambda e: int(e.get("credits", 0)),
    "bounty_payoff": lambda e: int(e.get("cost", 0)),
}
# Known types that carry no wallet delta (death keeps credits per DIV-0006).
NEUTRAL = {"death", "travel", "window_resolve"}

# Fields that suggest an event type moves credits even if we don't know it.
CREDITY_FIELDS = ("price", "cost", "credits", "loot_credits", "reward_credits")


def read_events(path):
    events = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                parsed = json.loads(line)
            except json.JSONDecodeError:
                continue  # torn tail from a crash mid-write
            if isinstance(parsed, dict):
                events.append(parsed)
    return events


def tally(events):
    """Returns (per_character dict, unknown_credity Counter, type_counts Counter)."""
    per_char = defaultdict(lambda: {
        "inflow": 0, "outflow": 0, "deaths": 0, "events": Counter(),
        "first_ts": None, "last_ts": None,
    })
    unknown_credity = Counter()
    type_counts = Counter()
    for event in events:
        etype = str(event.get("type", ""))
        type_counts[etype] += 1
        cid = str(event.get("character_id", "")) or "(no character)"
        record = per_char[cid]
        record["events"][etype] += 1
        ts = event.get("ts")
        if isinstance(ts, (int, float)):
            if record["first_ts"] is None or ts < record["first_ts"]:
                record["first_ts"] = ts
            if record["last_ts"] is None or ts > record["last_ts"]:
                record["last_ts"] = ts
        if etype in INFLOW:
            record["inflow"] += INFLOW[etype](event)
        elif etype in OUTFLOW:
            record["outflow"] += OUTFLOW[etype](event)
        elif etype == "death":
            record["deaths"] += 1
        elif etype not in NEUTRAL:
            if any(field in event for field in CREDITY_FIELDS):
                unknown_credity[etype] += 1
    return per_char, unknown_credity, type_counts


def render(per_char, unknown_credity, type_counts):
    lines = []
    lines.append("character                        inflow   outflow       net  deaths  span(s)")
    lines.append("-" * 78)
    total_in = total_out = 0
    ordered = sorted(per_char.items(), key=lambda kv: -(kv[1]["inflow"] - kv[1]["outflow"]))
    for cid, record in ordered:
        if cid == "(no character)" and record["inflow"] == 0 and record["outflow"] == 0:
            continue  # window_resolve etc. — no wallet, nothing to show
        net = record["inflow"] - record["outflow"]
        total_in += record["inflow"]
        total_out += record["outflow"]
        span = ""
        if record["first_ts"] is not None and record["last_ts"] is not None:
            span = "%d" % int(record["last_ts"] - record["first_ts"])
        lines.append("%-30s %8d  %8d  %8d  %6d  %7s" % (
            cid[:30], record["inflow"], record["outflow"], net, record["deaths"], span))
    lines.append("-" * 78)
    lines.append("%-30s %8d  %8d  %8d" % ("TOTAL (faucet vs sink)", total_in, total_out, total_in - total_out))
    lines.append("")
    lines.append("event mix: " + ", ".join("%s=%d" % (t, n) for t, n in sorted(type_counts.items())))
    if unknown_credity:
        lines.append("")
        lines.append("WARNING: credit-bearing event types this tally does NOT count yet "
                     "(update INFLOW/OUTFLOW in tools/telemetry_tally.py — faucets and "
                     "sinks land together):")
        for etype, count in unknown_credity.items():
            lines.append("  %s x%d" % (etype, count))
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Per-character credit faucet/sink tally over telemetry JSONL.")
    parser.add_argument("log_path", help="path to the server's telemetry events.jsonl")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON instead of the table")
    args = parser.parse_args(argv)
    try:
        events = read_events(args.log_path)
    except OSError as error:
        print("cannot read %s: %s" % (args.log_path, error), file=sys.stderr)
        return 2
    per_char, unknown_credity, type_counts = tally(events)
    if args.json:
        payload = {
            "characters": {
                cid: {
                    "inflow": rec["inflow"], "outflow": rec["outflow"],
                    "net": rec["inflow"] - rec["outflow"], "deaths": rec["deaths"],
                    "events": dict(rec["events"]),
                } for cid, rec in per_char.items()
            },
            "unknown_credit_bearing_types": dict(unknown_credity),
            "type_counts": dict(type_counts),
        }
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(render(per_char, unknown_credity, type_counts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
