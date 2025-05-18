/*
  "rage_lag"	// Ability name can use suffixes
  {
    "slot"			"0"							// Ability Slot
    "duration"	"20.0"					// lag duration
    "target"		"0"							// 0 = everyone, 1 = only boss, 2 = on boss team, not boss team, 4 = except boss
    "plugin_name"	"ff2r_lag"	  // Plugin Name
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdktools_functions>
#include <sdktools_trace>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "[FF2R] Lag",
  author      = "Phil25, Zell",
  description = "from RTD to FF2R Ability",
  version     = "1.0.1",
  url         = ""
};

int   g_iTickTeleport[MAXPLAYERS + 1];
int   g_iTickSetPosition[MAXPLAYERS + 1];
float g_fPos[MAXPLAYERS + 1][3];
Handle g_hLagTeleportTimer[MAXPLAYERS + 1];
Handle g_hLagPositionTimer[MAXPLAYERS + 1];

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_lag", false) && cfg.IsMyPlugin())
  {
    float duration = cfg.GetFloat("duration", 10.0);
    int   target   = cfg.GetInt("target", 0);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidLivingClient(i) && IsTarget(client, i, target))
      {
        // Clear any existing timers first
        ClearLagTimers(i);

        g_iTickTeleport[i] = GetRandomInt(6, 14);
        Lag_SetPosition(i);  // sets Pos and TickSetPosition

        g_hLagTeleportTimer[i] = CreateTimer(0.1, Timer_LagTeleport, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        g_hLagPositionTimer[i] = CreateTimer(0.1, Timer_LagSetPositionCheck, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(duration, Timer_RemoveLag, i, TIMER_FLAG_NO_MAPCHANGE);
      }
    }
  }
}

// retard copy from rtd perk :D
public Action Timer_LagTeleport(Handle timer, int client)
{
  if (!IsValidLivingClient(client))
    return Plugin_Stop;

  if (--g_iTickTeleport[client] > 0)
    return Plugin_Continue;

  float fPos[3];
  fPos[0] = g_fPos[client][0];
  fPos[1] = g_fPos[client][1];
  fPos[2] = g_fPos[client][2];

  TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);

  g_iTickTeleport[client] = GetRandomInt(6, 14);

  return Plugin_Continue;
}

public Action Timer_LagSetPositionCheck(Handle timer, int client)
{
  if (!IsValidLivingClient(client))
    return Plugin_Stop;

  if (--g_iTickSetPosition[client] <= 0)
    Lag_SetPosition(client);

  return Plugin_Continue;
}

public Action Timer_RemoveLag(Handle timer, int client)
{
  ClearLagTimers(client);

  if (IsValidLivingClient(client))
    FixPotentialStuck(client);

  return Plugin_Stop;
}

void ClearLagTimers(int client)
{
  if (g_hLagTeleportTimer[client] != null)
  {
    KillTimer(g_hLagTeleportTimer[client]);
    g_hLagTeleportTimer[client] = null;
  }

  if (g_hLagPositionTimer[client] != null)
  {
    KillTimer(g_hLagPositionTimer[client]);
    g_hLagPositionTimer[client] = null;
  }
}

public void OnPluginEnd()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    ClearLagTimers(i);
  }
}

public void OnClientDisconnect(int client)
{
  ClearLagTimers(client);
}

public void Lag_SetPosition(int client)
{
  float fPos[3];

  GetClientAbsOrigin(client, fPos);

  g_fPos[client][0]          = fPos[0];
  g_fPos[client][1]          = fPos[1];
  g_fPos[client][2]          = fPos[2];

  g_iTickSetPosition[client] = GetRandomInt(3, 8);
}

stock void FixPotentialStuck(int client)
{
  if (!IsValidLivingClient(client))
    return;

  if (!IsEntityStuck(client))
    return;

  TF2_RespawnPlayer(client);
}

stock bool IsEntityStuck(int iEntity)
{
  float fPos[3], fMins[3], fMaxs[3];

  GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPos);
  GetEntPropVector(iEntity, Prop_Send, "m_vecMins", fMins);
  GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", fMaxs);

  TR_TraceHullFilter(fPos, fPos, fMins, fMaxs, MASK_SOLID, TraceFilterIgnoreSelf, iEntity);

  return TR_DidHit();
}

public bool TraceFilterIgnoreSelf(int iEntity, int iContentsMask, int iTarget)
{
  return iEntity != iTarget;
}

stock bool IsTarget(int boss, int target, int type)
{
  switch (type)
  {
    case 1: return boss == target;                                // Only boss
    case 2: return GetClientTeam(boss) == GetClientTeam(target);  // Same team
    case 3: return GetClientTeam(boss) != GetClientTeam(target);  // Enemy team
    case 4: return boss != target;                                // Everyone except boss
    default: return true;                                         // Everyone
  }
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