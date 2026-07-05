# SW_MMO_Prototype Known Issues

This document tracks known issues that exist in the pre-beta/private alpha release candidate. These issues are either minor enough to not block the core play loop, or have workarounds.

## 1. Engine Quirks

- **ObjectDB Leaks:** When the server or headless client terminates, Godot may report `WARNING: ObjectDB instances leaked at exit`. This is a known Godot engine quirk with some of our nodes/resources and does not impact gameplay or stability during the session.

## 2. Server/Networking

- **No Encryption:** The current ENet transport is entirely unencrypted. It must only be used on LANs or trusted private networks. Do not expose it to the public internet.
- **Admin Allowlist:** Admin commands are gated by a hardcoded `_admin_allowlist` in `network_manager.gd`. Currently, "admin", "operator", and "pilot_1" are allowed. This requires a code change to add new admins.

## 3. Gameplay

- **Corpse Looting Without Consent:** The current death penalty (DIV-0006) and corpse rules (DIV-0025) allow third-party full-loot in lawless zones. Currently, this can happen very fast if someone is waiting right next to a downed player.
- **Stuck in Space:** Rarely, a network failure during hyperjump might leave a player "in space" without a valid scene. Workaround: An operator can run `/admin clear_space <character_id>` to return them to Mos Eisley.
- **Test Affordances:** Headless test arguments (e.g., `--economy-test-c1`, `--autofire`) are strictly for testing and gate proofs. They bypass normal gameplay flows and should not be used in normal play.
