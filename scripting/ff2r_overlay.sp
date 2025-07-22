/*
  "rage_overlay" // Ability name can use suffixes
  {
    "slot"        "0"

    "path"        "draqz/ff2/qwerty/overlay"
    "duration"    "5.0"
    "range"       "9999.0"
    "target"      "0" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name" "ff2r_overlay"
  }

  "intro_overlay"
  {
    "path"	      "draqz/ff2/qwerty/overlay"
    "delay"	      "3.5"
    "duration"    "5.0"
    "target"      "0" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name" "ff2r_overlay"
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

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Overlay"
#define PLUGIN_AUTHOR  "Jery0987, RainBolt Dash, Naydef, Zell"
#define PLUGIN_DESC    "Ability that covers all living, non-boss team players screens with an image"
#define PLUGIN_VERSION "2.1.2"

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTHOR,
  description = PLUGIN_DESC,
  version     = PLUGIN_VERSION,
};

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (setup && FF2R_GetGamemodeType() == 2)
  {
    AbilityData ability = cfg.GetAbility("intro_overlay");
    if (ability.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    {
      float    delay = ability.GetFloat("delay", 3.499999825);
      DataPack pack;
      CreateDataTimer(delay, Timer_StartOverlay, pack, TIMER_FLAG_NO_MAPCHANGE);
      pack.WriteCell(client);
      pack.WriteCell(ability);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      AddOverlay(i, "");
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_overlay", false))
  {
    DataPack pack;
    CreateDataTimer(0.0, Timer_StartOverlay, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);
    pack.WriteCell(cfg);
  }
}

public Action Timer_StartOverlay(Handle hTimer, DataPack pack)
{
  pack.Reset();
  int         client = pack.ReadCell();
  AbilityData cfg    = pack.ReadCell();

  char        path[PLATFORM_MAX_PATH];
  cfg.GetString("path", path, sizeof(path), "");
  float duration   = cfg.GetFloat("duration", 5.0);
  int   targetType = cfg.GetInt("target", 3);
  float range      = cfg.GetFloat("range", 9999.0);

  float pos[3], pos2[3];
  GetClientAbsOrigin(client, pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i) && IsPlayerAlive(i) && IsTarget(client, i, targetType))
    {
      GetClientAbsOrigin(i, pos2);
      if (GetVectorDistance(pos, pos2) < range)
      {
        AddOverlay(i, path);
        CreateTimer(duration, Timer_RemoveOverlay, i, TIMER_FLAG_NO_MAPCHANGE);
      }
    }
  }

  return Plugin_Continue;
}

public Action Timer_RemoveOverlay(Handle hTimer, any client)
{
  if (IsValidClient(client))
  {
    AddOverlay(client, "");
  }
  return Plugin_Continue;
}

public void AddOverlay(int client, const char[] path)
{
  char overlay[PLATFORM_MAX_PATH];
  Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", path);
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
  ClientCommand(client, overlay);
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
}

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
  {
    case 1:  // if target is boss,
      return client == target;
    case 2:  // if target's team same team as boss's team
      return GetClientTeam(target) == GetClientTeam(client);
    case 3:  // if target's team is not same team as boss's team
      return GetClientTeam(target) != GetClientTeam(client);
    case 4:  // if target is not boss
      return (client != target);
    default:  // effect everyone
      return true;
  }
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