param(
    [string]$GodotConsole = "godot-console"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Invoke-GodotStep {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    Write-Host "`n$Label"
    $output = & $GodotConsole @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }

    $joined = $output -join "`n"
    if ($joined -match "SCRIPT ERROR|SCRIPT ERROR:|Parse Error|Parser Error") {
        throw "$Label emitted a Godot script error."
    }
}

Write-Host "Godot version:"
& $GodotConsole --version

Write-Host "`nPython unit tests:"
$pythonOutput = & cmd /c "python -m unittest discover -s `"$projectRoot\tests`" 2>&1"
$pythonExitCode = $LASTEXITCODE
$pythonOutput | ForEach-Object { Write-Host $_ }
if ($pythonExitCode -ne 0) {
    throw "Python unit tests failed with exit code $pythonExitCode."
}

Invoke-GodotStep "Import check:" @("--headless", "--path", $projectRoot, "--import", "--quit")

Invoke-GodotStep "Runtime launch check:" @("--headless", "--path", $projectRoot, "--quit-after", "2")

Invoke-GodotStep "Rules smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/rules_smoke.gd")

Invoke-GodotStep "Ground combat model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/ground_combat_model_smoke.gd")

Invoke-GodotStep "Armor condition model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/armor_condition_model_smoke.gd")

Invoke-GodotStep "Armor repair model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/armor_repair_model_smoke.gd")

Invoke-GodotStep "Action window model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/action_window_model_smoke.gd")

Invoke-GodotStep "Range action window model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_action_window_model_smoke.gd")

Invoke-GodotStep "Combat event envelope model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_event_envelope_model_smoke.gd")

Invoke-GodotStep "Combat event log model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_event_log_model_smoke.gd")

Invoke-GodotStep "Character sheet model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/character_sheet_model_smoke.gd")

Invoke-GodotStep "Range controller smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_controller_smoke.gd")

Invoke-GodotStep "Range status model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_status_model_smoke.gd")

Invoke-GodotStep "Range inspection model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_inspection_model_smoke.gd")

Invoke-GodotStep "Range hit feedback model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_hit_feedback_model_smoke.gd")

Invoke-GodotStep "Range state badge model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_state_badge_model_smoke.gd")

Invoke-GodotStep "Range target model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_target_model_smoke.gd")

Invoke-GodotStep "Positional range model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/positional_range_model_smoke.gd")

Invoke-GodotStep "Moving target model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/moving_target_model_smoke.gd")

Invoke-GodotStep "Modal overlay model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/modal_overlay_model_smoke.gd")

Invoke-GodotStep "Space overlay layout model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_layout_model_smoke.gd")

Invoke-GodotStep "Space overlay mode model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_mode_model_smoke.gd")

Invoke-GodotStep "Space station strip model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_station_strip_model_smoke.gd")

Invoke-GodotStep "Space contact selection model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_contact_selection_model_smoke.gd")

Invoke-GodotStep "Space action log model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_action_log_model_smoke.gd")

Invoke-GodotStep "Space tactical model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_tactical_model_smoke.gd")

Invoke-GodotStep "Space overlay live clock smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_live_clock_smoke.gd")

Invoke-GodotStep "Space status model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_status_model_smoke.gd")

Invoke-GodotStep "Data smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/data_smoke.gd")

Invoke-GodotStep "Net smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/net_smoke.gd")

Invoke-GodotStep "World builder smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/world_builder_smoke.gd")

Invoke-GodotStep "Content smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/content_smoke.gd")

Invoke-GodotStep "Combat arena smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_arena_smoke.gd")

Invoke-GodotStep "Hostile aggression smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/hostile_aggression_smoke.gd")

Invoke-GodotStep "Persistence smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/persistence_smoke.gd")

Invoke-GodotStep "Telemetry log smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/telemetry_log_smoke.gd")

Invoke-GodotStep "Persistence schema smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/persistence_schema_smoke.gd")

Invoke-GodotStep "Zone state smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/zone_state_smoke.gd")

Invoke-GodotStep "Territory smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/territory_smoke.gd")

Invoke-GodotStep "Siege smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/siege_smoke.gd")

Invoke-GodotStep "Siege state model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/siege_state_model_edge_smoke.gd")

Invoke-GodotStep "Chargen smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/chargen_smoke.gd")

Invoke-GodotStep "Name policy smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/name_policy_smoke.gd")

Invoke-GodotStep "Progression smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/progression_smoke.gd")

Invoke-GodotStep "Derived stats model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/derived_stats_model_smoke.gd")

Invoke-GodotStep "Reputation model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/reputation_model_smoke.gd")

Invoke-GodotStep "Quest model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/quest_model_smoke.gd")

Invoke-GodotStep "Quest model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/quest_model_edge_smoke.gd")

Invoke-GodotStep "Quest live-flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/quest_live_flow_smoke.gd")

Invoke-GodotStep "Creature spawn model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/creature_spawn_model_smoke.gd")

Invoke-GodotStep "Creature special-attack model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/creature_special_attack_model_smoke.gd")

Invoke-GodotStep "Creature combat smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/creature_combat_smoke.gd")

Invoke-GodotStep "Vendor model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/vendor_model_smoke.gd")

Invoke-GodotStep "Economy model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/economy_model_smoke.gd")

Invoke-GodotStep "Economy model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/economy_model_edge_smoke.gd")

Invoke-GodotStep "Economy flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/economy_flow_smoke.gd")

Invoke-GodotStep "Economy floor smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/economy_floor_smoke.gd")

Invoke-GodotStep "Harvest model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/harvest_model_smoke.gd")
Invoke-GodotStep "Harvest wire smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/harvest_wire_smoke.gd")

Invoke-GodotStep "Vendor zone flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/vendor_zone_flow_smoke.gd")

Invoke-GodotStep "Death penalty model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/death_penalty_model_smoke.gd")

Invoke-GodotStep "Death penalty model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/death_penalty_model_edge_smoke.gd")

Invoke-GodotStep "Death flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/death_flow_smoke.gd")

Invoke-GodotStep "Corpse decay model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/corpse_decay_model_smoke.gd")

Invoke-GodotStep "Corpse loot wire smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/corpse_loot_wire_smoke.gd")

Invoke-GodotStep "Hostile NPC model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/hostile_npc_model_smoke.gd")

Invoke-GodotStep "Hostile NPC model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/hostile_npc_model_edge_smoke.gd")

Invoke-GodotStep "PvP rules model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_rules_model_smoke.gd")

Invoke-GodotStep "PvP rules model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_rules_model_edge_smoke.gd")

Invoke-GodotStep "PvP flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_flow_smoke.gd")

Invoke-GodotStep "PvP dodge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_dodge_smoke.gd")

Invoke-GodotStep "Downed model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/downed_model_smoke.gd")

Invoke-GodotStep "Downed softlock guard smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/downed_softlock_smoke.gd")

Invoke-GodotStep "PvP consent model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_consent_model_smoke.gd")

Invoke-GodotStep "PvP consent model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pvp_consent_model_edge_smoke.gd")

Invoke-GodotStep "Security gate smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/security_gate_smoke.gd")

Invoke-GodotStep "Pending influence smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/pending_influence_smoke.gd")

Invoke-GodotStep "Org model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/org_model_smoke.gd")

Invoke-GodotStep "Wound ladder model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/wound_ladder_model_smoke.gd")

Invoke-GodotStep "Wound escalation flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/wound_escalation_flow_smoke.gd")

Invoke-GodotStep "Recovery model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/recovery_model_smoke.gd")

Invoke-GodotStep "Force skills model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/force_skills_model_smoke.gd")

Invoke-GodotStep "Force awakening model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/force_awakening_model_smoke.gd")

Invoke-GodotStep "Force awakening model edge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/force_awakening_model_edge_smoke.gd")

Invoke-GodotStep "Force flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/force_flow_smoke.gd")

Invoke-GodotStep "Snapshot merge smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/snapshot_merge_smoke.gd")

Invoke-GodotStep "Wire roundtrip smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/wire_roundtrip_smoke.gd")

Invoke-GodotStep "Snapshot enrichment smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/snapshot_enrichment_smoke.gd")

Invoke-GodotStep "Skill attribute smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/skill_attribute_smoke.gd")

Invoke-GodotStep "Character lifecycle smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/character_lifecycle_smoke.gd")

Invoke-GodotStep "CP award smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/cp_award_smoke.gd")

Invoke-GodotStep "Zones smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/zones_smoke.gd")

Invoke-GodotStep "Equip smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/equip_smoke.gd")

Invoke-GodotStep "Chat model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/chat_model_smoke.gd")

Invoke-GodotStep "Account auth smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/account_auth_smoke.gd")

Invoke-GodotStep "Ambient sim model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/ambient_sim_model_smoke.gd")

Invoke-GodotStep "Claim flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/claim_flow_smoke.gd")

Invoke-GodotStep "Auth flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/auth_flow_smoke.gd")

Invoke-GodotStep "Heal flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/heal_flow_smoke.gd")

Invoke-GodotStep "Zone flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/zone_flow_smoke.gd")

Invoke-GodotStep "Chat flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/chat_flow_smoke.gd")

Invoke-GodotStep "Monster builder smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/monster_builder_smoke.gd")

Invoke-GodotStep "Landmark builder smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/landmark_builder_smoke.gd")

Invoke-GodotStep "NPC content smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/npc_content_smoke.gd")

Invoke-GodotStep "NPC builder smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/npc_builder_smoke.gd")
Invoke-GodotStep "Dialogue model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/dialogue_model_smoke.gd")

Invoke-GodotStep "Named NPC flow smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/named_npc_flow_smoke.gd")

Invoke-GodotStep "Dialogue NPC smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/dialogue_npc_smoke.gd")

Write-Host "`nAll checks passed."
