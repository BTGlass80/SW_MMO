# Antigravity MMO - Release Playtest Script

This document provides a step-by-step guide for non-developers to install, run, and validate the three core player stories of the SW_MMO prototype release candidate. 

Any failure or deviation from these steps must be treated as a release blocker or documented as a known issue.

## 1. Installation & Setup

1. **Prerequisites:**
   - Godot Engine 4.6.3 Stable (Windows 64-bit console version recommended).
   - Python 3.10+ (for running tests and telemetry scripts).
   - Git (for cloning the repository).

2. **Checkout the Game:**
   ```powershell
   git clone <repository_url> SW_MMO_Prototype
   cd SW_MMO_Prototype
   ```

3. **Verify the Build:**
   Run the automated gate to ensure the build is healthy before starting.
   ```powershell
   powershell .\tools\check_project.ps1
   ```
   *Expected:* Output ends with `All checks passed.`

## 2. Server Start

1. Open a new terminal window.
2. Launch the authoritative server:
   ```powershell
   & "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --headless --path . res://scenes/net_world.tscn -- --server
   ```
   *(Alternatively, run `start_game.bat server`)*
   *Expected Messages:* `server listening on port 24555`

## 3. Client Join & Character Creation

### First Client
1. Open a new terminal window.
2. Launch the first client (Client A):
   ```powershell
   & "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
   ```
   *(Do NOT use `--headless` for clients.)*
3. Connect to the server using the in-game UI (typically defaults to `127.0.0.1:24555`).
4. **Create Character:** Create a new character named "Pilot A" with a focus on piloting and basic crafting.

### Second Client
1. Open a new terminal window.
2. Launch the second client (Client B):
   ```powershell
   & "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
   ```
3. Connect to the server.
4. **Create Character:** Create a second character named "Hunter B" with a focus on combat and first aid.

## 4. Core Story 1: New Player First Hour

1. **Chat:** Pilot A types "Hello there!" in the local chat. Hunter B should see the message.
2. **Buy/Equip/Restock:** 
   - Hunter B approaches the local vendor NPC and purchases a Blaster Pistol and a Basic Medpac.
   - Hunter B opens their inventory and equips the Blaster Pistol.
3. **Survey & Harvest (Pilot A):**
   - Pilot A travels outside the city limits and uses the "Survey" action.
   - Pilot A harvests an organic resource node.
4. **Combat (Hunter B):**
   - Hunter B targets a low-level spawned creature (e.g., Womp Rat) and enters combat.
   - Hunter B successfully defeats the creature using the equipped blaster.
   - Hunter B takes damage, receiving at least 1 wound.

## 5. Core Story 2: Player Economy

1. **Crafting:** Pilot A uses the harvested organic resources to craft a `basic_medpac`.
   - *Expected:* The medpac appears as a unique item instance in Pilot A's inventory.
2. **List on Bazaar:** Pilot A opens the Bazaar terminal and lists the crafted medpac for 1500 credits.
   - *Expected:* Pilot A pays a listing fee (deducted from their credits).
3. **Buy from Bazaar:** Hunter B opens the Bazaar, finds Pilot A's medpac, and purchases it for 1500 credits.
   - *Expected:* 1500 credits are deducted from Hunter B. Pilot A receives 1500 credits.
4. **Item Use:** Hunter B opens their inventory and uses the purchased crafted medpac to heal their wound.
   - *Expected:* The wound is healed, and the medpac is consumed (or its condition degrades).

## 6. Core Story 3: Space Cargo

1. **Launch:** Pilot A boards their starter ship (e.g., Z-95 Headhunter) and launches into space.
   - *Expected:* Pilot A's client transitions to the space scene. Server registers space state.
2. **Harvest/Salvage:** Pilot A engages a debris field and successfully salvages a cargo item (`starship_salvage`).
3. **Land/Dock:** Pilot A returns to the planet surface and lands.
   - *Expected:* A docking fee (e.g., 50 credits) is deducted from Pilot A's wallet.
   - *Expected:* The salvaged cargo item is transferred from the ship's hold to Pilot A's personal inventory.

## 7. Persistence & Reconnect Check

1. **Disconnect:** Both Pilot A and Hunter B close their game clients.
2. **Restart Server:** Close the server terminal. Wait 5 seconds. Restart the server using the command from Step 2.
3. **Reconnect:** Pilot A and Hunter B relaunch their clients and reconnect.
4. **Validation:**
   - Pilot A verifies their credit balance reflects the Bazaar sale and docking fee deductions. The salvaged space cargo must still be in their inventory.
   - Hunter B verifies their wound is still healed, the blaster is still equipped, and their credit balance reflects the Bazaar purchase.

## 8. Telemetry Validation

After the server restart and playtest, validate the economy telemetry log to ensure all faucets and sinks were correctly captured.

1. Run the telemetry tally script:
   ```powershell
   python tools/telemetry_tally.py <path_to_appdata>/telemetry/events.jsonl
   ```
   *(On Windows, the path is typically `%APPDATA%/Godot/app_userdata/SW_MMO_Prototype/telemetry/events.jsonl`)*

2. **Expected Verification:**
   - No "unknown credit-bearing types" warnings are present at the bottom of the output.
   - Pilot A shows a clear net inflow from `space_sell_cargo` or bazaar sales, and outflow from `bazaar_list_fee` and `sink_fee` (docking).
   - Hunter B shows an outflow for `bazaar_buy` and NPC vendor purchases.
   - Total Faucets vs Total Sinks are fully accounted for.

## 9. Known Expected Messages

During normal play, the server console will output standard networking logs (e.g., `Peer connected`, `Applying snapshot`). These are expected.

However, if you see:
- `SCRIPT ERROR:`
- `Parse Error:`
- `ObjectDB instances leaked at exit` (This is a known Godot engine quirk and not a game logic failure, but should be minimized).
...then a bug has occurred. Record it.

## 10. Documenting Failures

If any step in this script fails, do not proceed to launch. Log the failure in `docs/KNOWN_ISSUES.md` (if minor/workaround available) or treat it as a critical blocker that must be fixed before the RC is approved.
