/*
  "rage_corrupted_energy"				// Ability name (can use suffixes)
  {
    "slot" 							"0"			// Ability Slot (set as needed)
    "model" 						"models/props_badlands/quarry_rockpike.mdl" // (optional) Model to spawn
    "count" 						"12"		// (optional) Number of rocks to spawn in a line
    "distance" 					"50.0"	// (optional) Distance between each model (hammer units)
    "duration" 					"7.0"		// (optional) Duration in seconds for rocks to stay
    "damage_radius" 		"100.0"	// (optional) Radius in which RED players take damage (hammer units from the rock)
    "damage_per_tick" 	"5.0"		// (optional) Damage dealt to RED players per tick
    "tick_interval" 		"0.2"		// (optional) Interval in seconds between damage ticks
    "plugin_name"				"ff2r_forsaken_script"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Forsaken Script",
  author      = "pu_shitcake, Zell",
  description = "John Doe's Corrupted Energy Ability from Forsaken, adapted for FF2R",
  version     = "1.0.1",
};

public void FF2R_OnBossRemoved(int client)
{
  // When the boss is removed, we need to clean up any rocks they spawned
  for (int i = 1; i <= MaxClients; i++)
  {
    if (i == client || !IsValidClient(i)) continue;

    // Check if the client has any rocks spawned
    int rock = FindEntityByClassname(-1, "prop_dynamic");
    while (rock != -1)
    {
      int owner = GetEntProp(rock, Prop_Send, "m_hOwnerEntity");
      if (owner == client)
      {
        AcceptEntityInput(rock, "Kill");  // Remove the rock
      }
      rock = FindEntityByClassname(rock, "prop_dynamic");
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_corrupted_energy", false))
  {
    SpawnRockLine(client, cfg);
  }
}

// Spawns a line of rocks in front of the boss
void SpawnRockLine(int client, AbilityData cfg)
{
  float origin[3], angles[3], vecForward[3];
  GetClientAbsOrigin(client, origin);
  GetClientAbsAngles(client, angles);
  GetAngleVectors(angles, vecForward, NULL_VECTOR, NULL_VECTOR);

  char model[PLATFORM_MAX_PATH];
  cfg.GetString("models", model, sizeof(model));
  // if no model use default rock model
  if (model[0] == '\0')
    Format(model, sizeof(model), "models/props_badlands/quarry_rockpike.mdl");

  PrecacheModel(model);  // precache the model

  int   rockCount     = cfg.GetInt("count", 12);               // Number of rocks to spawn
  float rockDistance  = cfg.GetFloat("distance", 50.0);        // Distance between
  float duration      = cfg.GetFloat("duration", 7.0);         // Duration for rocks to stay
  float damageRadius  = cfg.GetFloat("damage_radius", 100.0);  // Damage radius
  float damagePerTick = cfg.GetFloat("damage_per_tick", 5.0);
  float tickInterval  = cfg.GetFloat("tick_interval", 0.2);  // Damage tick interval

  for (int i = 0; i < rockCount; i++)
  {
    float pos[3];
    pos[0]   = origin[0] + vecForward[0] * (rockDistance * (i + 1));
    pos[1]   = origin[1] + vecForward[1] * (rockDistance * (i + 1));
    pos[2]   = origin[2];

    int rock = CreateEntityByName("prop_dynamic");
    if (rock != -1)
    {
      SetEntityModel(rock, model);
      TeleportEntity(rock, pos, NULL_VECTOR, NULL_VECTOR);
      DispatchSpawn(rock);

      CreateTimer(duration, Timer_RemoveRocksAndDamage, rock, TIMER_FLAG_NO_MAPCHANGE);

      DataPack rockDamagePack;
      CreateDataTimer(tickInterval, Timer_RockDamageTick, rockDamagePack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
      rockDamagePack.WriteCell(rock);
      rockDamagePack.WriteFloat(damagePerTick);
      rockDamagePack.WriteFloat(damageRadius);
      rockDamagePack.WriteCell(client);
    }
  }
}

// Timer callback to deal damage to RED players near rocks
public Action Timer_RockDamageTick(Handle timer, DataPack pack)
{
  // Reset the pack position and read the stored values
  pack.Reset();
  int   rock          = pack.ReadCell();
  float damagePerTick = pack.ReadFloat();
  float damageRadius  = pack.ReadFloat();
  int   client        = pack.ReadCell();

  // Check if the rock entity is valid
  if (rock <= 0 || !IsValidEntity(rock))
    return Plugin_Stop;

  // Get the position of the rock
  float rockPos[3];
  GetEntPropVector(rock, Prop_Send, "m_vecOrigin", rockPos);

  // Apply damage to RED players near the rock
  for (int i = 1; i <= MaxClients; i++)
  {
    if (client == i) continue;                            // Skip the owner of the rock
    if (!IsValidClient(i) && IsPlayerAlive(i)) continue;  // Check if the client is valid and live

    float playerPos[3];
    GetClientAbsOrigin(i, playerPos);

    if (GetVectorDistance(playerPos, rockPos) < damageRadius)
      SDKHooks_TakeDamage(i, rock, client, damagePerTick, DMG_GENERIC);
  }
  return Plugin_Continue;
}

// Timer callback to remove rocks
public Action Timer_RemoveRocksAndDamage(Handle timer, int rock)
{
  // Remove the rock entity
  if (rock > 0 && IsValidEntity(rock))
    AcceptEntityInput(rock, "Kill");

  return Plugin_Continue;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
  if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client))) return false;
  return true;
}