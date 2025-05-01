/*
  "scp173"
  {
    "duration"		"2.0"	// Duration of Rage
    "interval"		"5.0"	// Interval of Rage
    "freeze"	    "0"   // Does boss move freely while doesn't in rage? 0 = No, 1 = Yes
    "path"        "draqz/ff2/fpywnm/overlay"    // materials path for the overlay
    "plugin_name"	"ff2r_scp173"
  }
*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "Freak Fortress 2: SCP-173 Special Abilities",
  description = "Decompiled and Rewroten version",
  author      = "OriginalNero, Rewrite by Batfoxkid, Decompiled by Maximilian_, and port to FF2R by Zell",
  version     = "1.1.2"
};

bool  IsEnabled = false;
float duration;
float interval;
bool  freeze;
char  path[PLATFORM_MAX_PATH];

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("scp173");
    if (ability.IsMyPlugin())
    {
      IsEnabled = true;
      HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
      duration = ability.GetFloat("duration", 2.0);
      interval = ability.GetFloat("interval", 10.0);
      freeze   = ability.GetInt("freeze", 0) == 1;
      if (freeze)
      {
        TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, interval);
      }
      cfg.GetString("path", path, sizeof(path));
      CreateTimer(interval, TurnOffLights, client, TIMER_FLAG_NO_MAPCHANGE);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  if (IsEnabled)
  {
    IsEnabled = false;
    UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
    // Clean up the overlay when the boss is removed
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & -FCVAR_CHEAT);
    for (int target = 1; target <= MaxClients; target++)
    {
      if (IsValidClient(target))
      {
        ClientCommand(target, "r_screenoverlay \"\"");
      }
    }
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
  }
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));

  if (!IsValidClient(client))  // Check if the client is valid and alive
    return Plugin_Continue;    // If not, do nothing

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return Plugin_Continue;  // Prevent a bug with revive markers & dead ringer spies

  if (IsEnabled)
  {
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & -FCVAR_CHEAT);
    if (IsValidClient(client))
    {
      ClientCommand(client, "r_screenoverlay \"\"");
    }
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
  }

  return Plugin_Continue;  // Continue the event
}

public Action TurnOnLights(Handle timer, int client)
{
  if (!IsEnabled)
    return Plugin_Stop;

  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & -FCVAR_CHEAT);
  for (int target = 1; target <= MaxClients; target++)
  {
    if (IsValidClient(target))
    {
      if (GetClientTeam(target) != GetClientTeam(client) && IsPlayerAlive(target))
      {
        ClientCommand(target, "r_screenoverlay \"\"");
      }
    }
  }
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);

  if (freeze)
  {
    TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, interval);
  }
  CreateTimer(interval, TurnOffLights, client, TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

public Action TurnOffLights(Handle timer, int client)
{
  if (!IsEnabled)
    return Plugin_Stop;

  char  overlay[PLATFORM_MAX_PATH];
  Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", path);

  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & -FCVAR_CHEAT);
  for (int target = 1; target <= MaxClients; target++)
  {
    if (IsValidClient(target))
    {
      if (GetClientTeam(target) != GetClientTeam(client) && IsPlayerAlive(target))
      {
        ClientCommand(target, overlay);  // Set the screen overlay for the target
      }
    }
  }
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);

  CreateTimer(duration, TurnOnLights, client, TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

stock bool IsValidClient(int clientIdx, bool replaycheck = true)
{
  if (clientIdx <= 0 || clientIdx > MaxClients)
    return false;

  if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
    return false;

  if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
    return false;

  return true;
}