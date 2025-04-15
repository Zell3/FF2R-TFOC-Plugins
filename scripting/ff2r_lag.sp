/*
  "rage_lag"	// Ability name can use suffixes
  {
    "slot"			"0"							// Ability Slot
    "duration"		"20.0"						// lag duration
    "target"		"0"							// 0 = everyone, 1 = only boss, 2 = on boss team, not boss team, 4 = except boss
    "plugin_name"	"ff2r_lag"	// Plugin Name
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdktools_functions>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "[FF2R] Lag",
  author      = "Zell",
  description = "why this game so lagging",
  version     = "1.0.0",
  url         = ""
};

bool  isActive = false;
int   targetType;
int   TickTeleport[MAXPLAYERS + 1];
int   TickSetPosition[MAXPLAYERS + 1];
float targetPos[MAXPLAYERS + 1][3];

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      BossData cfg = FF2R_GetBossData(client);
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);
      }
    }
  }
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client) && FF2R_GetBossData(client))
    {
      FF2R_OnBossRemoved(client);
    }
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("rage_lag");
    if (ability.IsMyPlugin())
    {
      isActive = false;
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  isActive = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_lag", false) && cfg.IsMyPlugin())
  {
    float duration = cfg.GetFloat("duration", 10.0);
    targetType     = cfg.GetInt("target", 0);
    isActive       = true;
    PrintToServer("test2");

    CreateTimer(duration, Lag_Remove, client, TIMER_FLAG_NO_MAPCHANGE);

    for (int target = 1; target <= MaxClients; target++)
    {
      PrintToServer("test13456");
      if (!IsValidLivingClient(target))
        continue;

      if (TargetType(client, target))
      {
        TickTeleport[client]    = GetRandomInt(6, 14);
        TickSetPosition[client] = GetRandomInt(3, 8);

        CreateTimer(0.1, Lag_SetPosition, target, TIMER_REPEAT);
        CreateTimer(0.1, Lag_Teleport, target, TIMER_REPEAT);
      }
    }
  }
}

public Action Lag_Teleport(Handle timer, const int client)
{
  PrintToServer("test3");
  if (!isActive)
    return Plugin_Stop;

  if (!IsValidLivingClient(client))
    return Plugin_Continue;

  if (TickTeleport[client] - GetRandomInt(6, 14) > 0)
    return Plugin_Continue;

  float fPos[3];
  fPos[0] = targetPos[client][0];
  fPos[1] = targetPos[client][1];
  fPos[2] = targetPos[client][2];

  TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);

  TickTeleport[client] = GetRandomInt(6, 14);

  return Plugin_Continue;
}

public Action Lag_SetPosition(Handle timer, const int client)
{
  PrintToServer("test4");
  if (!isActive)
    return Plugin_Stop;

  if (!IsValidLivingClient(client))
    return Plugin_Continue;

  if (TickSetPosition[client] - GetRandomInt(3, 8) > 0)
    return Plugin_Continue;

  float fPos[3];
  GetClientAbsOrigin(client, fPos);

  targetPos[client][0]    = fPos[0];
  targetPos[client][1]    = fPos[1];
  targetPos[client][2]    = fPos[2];

  TickSetPosition[client] = GetRandomInt(3, 8);

  return Plugin_Continue;
}

public Action Lag_Remove(Handle timer, int client)
{
  PrintToServer("test53");
  isActive = false;
  return Plugin_Stop;
}

stock bool IsValidLivingClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
    return false;

  if (!IsClientInGame(client) || !IsClientConnected(client))
    return false;

  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;

  if (!IsPlayerAlive(client))
    return false;

  return true;
}

stock bool TargetType(int client, int target)
{
  switch (targetType)
  {
    case 1:  // if target is boss,
    {
      if (client == target)
        return true;
      else return false;
    }
    case 2:  // if target's team same team as boss's team
    {
      if (GetClientTeam(target) == GetClientTeam(client))
        return true;
      else return false;
    }
    case 3:  // if target's team is not same team as boss's team
    {
      if (GetClientTeam(target) != GetClientTeam(client))
        return true;
      else return false;
    }
    case 4:  // if target is not boss
    {
      if (client != target)
        return true;
      else return false;
    }
    default:  // effect everyone
    {
      return true;
    }
  }
}