# SW_MMO_Prototype Known Issues

This document tracks known issues for the beta release candidate. Issues are split into two categories: those acceptable for live beta (with known workarounds), and those that block the beta release.

## Acceptable For Beta

- **ObjectDB Leaks:** When the server or headless client terminates, Godot may report `WARNING: ObjectDB instances leaked at exit`. This is a known Godot engine quirk with some of our nodes/resources and does not impact gameplay or stability during the session.
- **No Encryption:** The current ENet transport is entirely unencrypted. It must only be used on LANs or trusted private networks. Do not expose it to the public internet.
- **Admin Allowlist:** Admin commands are gated by a hardcoded `_admin_allowlist` in `network_manager.gd`. Currently, "admin", "operator", and "pilot_1" are allowed. This requires a code change to add new admins.
- **Corpse Looting Without Consent:** The current death penalty (DIV-0006) and corpse rules (DIV-0025) allow third-party full-loot in lawless zones. Currently, this can happen very fast if someone is waiting right next to a downed player.
- **Stuck in Space:** Rarely, a network failure during hyperjump might leave a player "in space" without a valid scene. Workaround: An operator can run `/admin clear_space <character_id>` to return them to Mos Eisley.
- **Test Affordances:** Headless test arguments (e.g., `--economy-test-c1`, `--autofire`) are strictly for testing and gate proofs. They bypass normal gameplay flows and should not be used in normal play.

## Blocks Beta

- **Human PT1 Not Yet Run:** The machine soak and gate are green, but the project has
  not yet completed a human PT1 / strangers-night rehearsal. This blocks claiming a
  live beta candidate, but does not block continued unattended B8-B10 preparation.
