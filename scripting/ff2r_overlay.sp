/*
  // current
  "rage_overlay" // Ability name can use suffixes
  {
    "slot" "0"

    "path" "draqz/ff2/qwerty/overlay"
    "duration" "5.0"
    "range" "9999"
    "target" "0" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    plugin_name "ff2r_overlay"
  }
  "start_overlay"
  {
    "delay" "5.0"
    "path" "draqz/ff2/qwerty/overlay"
    "duration" "5.0"
    "range" "9999"
    "target" "0" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    plugin_name "ff2r_overlay"
  }

  // future plans if it needed
  "kill_overlay"
  {
    "path" "draqz/ff2/qwerty/overlay"
    "duration" "5.0"
    plugin_name "ff2r_overlay"
  }

  "end overlay"
  {
    "path" "draqz/ff2/qwerty/overlay"
    "duration" "5.0"
    plugin_name "ff2r_overlay"
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

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Overlay"
#define PLUGIN_AUTHOR   "Jery0987, RainBolt Dash, Naydef, Zell"
#define PLUGIN_DESC     "Ability that covers all living, non-boss team players screens with an image"

#define MAJOR_REVISION  "2"
#define MINOR_REVISION  "1"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION  MAJOR_REVISION... "." ... MINOR_REVISION... "." ... STABLE_REVISION

#define MAXTF2PLAYERS   36

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTHOR,
  description = PLUGIN_DESC,
  version     = PLUGIN_VERSION,
};

bool IsUnderOverlay[MAXTF2PLAYERS];  // Array to check if the player is under an overlay
public void OnPluginStart()
{
  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsClientInGame(clientIdx))
    {
      BossData cfg = FF2R_GetBossData(clientIdx);  // Get boss config (known as boss index) from player
      if (cfg)
      {
        FF2R_OnBossCreated(clientIdx, cfg, false);  // If boss is valid, Hook the abilities because this subplugin is most likely late-loaded
      }
    }
  }
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  // Check if the boss is valid and setup the hooks for the abilities
  if (!(!setup || FF2R_GetGamemodeType() != 2))
  {
    HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
    AbilityData ability = cfg.GetAbility("start_overlay");  // Get the ability from the boss config
    if (ability.IsMyPlugin())                               // Check if the ability is from this plugin
    {
      float delay = ability.GetFloat("delay", 3.25);
      char  path[PLATFORM_MAX_PATH];
      ability.GetString("path", path, sizeof(path));
      float    duration = ability.GetFloat("duration", 5.0);
      int      target   = ability.GetInt("target", 0);  // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
      float    range    = 9999.0;                       // 9999 is the default value for range (and it's roundstart soooo it doesn't matter)
      DataPack pack;
      CreateDataTimer(delay, Timer_StartOverlay, pack, TIMER_FLAG_NO_MAPCHANGE);
      pack.WriteCell(clientIdx);
      pack.WriteString(path);
      pack.WriteCell(duration);
      pack.WriteCell(target);
      pack.WriteCell(range);
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  // Unhook the event when the boss is removed
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && IsUnderOverlay[i])
    {
      CreateTimer(0.1, Timer_RemoveOverlay, i);  // Remove the overlay from the player
    }
  }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "rage_overlay", false))  // We want to use subffixes
  {
    float delay = 0.0;  // Delay time is 0.0 for the ability to be used instantly (go use do slot delay instead)
    char  path[PLATFORM_MAX_PATH];
    cfg.GetString("path", path, sizeof(path));
    float    duration = cfg.GetFloat("duration", 5.0);
    int      target   = cfg.GetInt("target", 0);        // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    float    range    = cfg.GetFloat("range", 9999.0);  // 9999 is the default value for range (and it's roundstart soooo it doesn't matter)
    DataPack pack;
    CreateDataTimer(delay, Timer_StartOverlay, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(clientIdx);
    pack.WriteString(path);
    pack.WriteCell(duration);
    pack.WriteCell(target);
    pack.WriteCell(range);
  }
}

public Action Timer_StartOverlay(Handle hTimer, DataPack pack)
{
  pack.Reset();
  int  clientIdx = pack.ReadCell();
  char path[PLATFORM_MAX_PATH];
  pack.ReadString(path, sizeof(path));
  float duration = pack.ReadCell();
  int   target   = pack.ReadCell();  // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
  float range    = pack.ReadCell();  // 9999 is the default value for range
  float pos[3], pos2[3];

  char  overlay[PLATFORM_MAX_PATH];
  // get boss position
  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && IsTarget(clientIdx, i, target))
    {
      // get target position
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      // check if target is in range
      if (GetVectorDistance(pos, pos2) < range)
      {
        IsUnderOverlay[i] = true;  // Set the overlay status for the target
        Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", path);
        SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
        ClientCommand(i, overlay);  // Set the screen overlay for the target
        CreateTimer(duration, Timer_RemoveOverlay, i);
        SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
      }
    }
  }

  return Plugin_Continue;
}

public Action Timer_RemoveOverlay(Handle hTimer, int clientIdx)
{
  if (IsUnderOverlay[clientIdx] == false)  // Check if the player is not under an overlay
    return Plugin_Continue;                // If not, do nothing
  IsUnderOverlay[clientIdx] = false;       // Reset the overlay status for the target
  char overlay[PLATFORM_MAX_PATH];
  Format(overlay, sizeof(overlay), "r_screenoverlay \"\"");
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
  ClientCommand(clientIdx, overlay);  // Remove the screen overlay for the target
  SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
  return Plugin_Continue;
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));

  if (!IsValidClient(client))  // Check if the client is valid and alive
    return Plugin_Continue;    // If not, do nothing

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return Plugin_Continue;  // Prevent a bug with revive markers & dead ringer spies

  if (IsUnderOverlay[client])  // Check if the client is under an overlay
    CreateTimer(0.1, Timer_RemoveOverlay, client);

  return Plugin_Continue;  // Continue the event
}

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
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

stock bool IsValidLivingClient(int client)  // Checks if a client is a valid living one.
{
  if (client <= 0 || client > MaxClients) return false;
  return IsValidClient(client) && IsPlayerAlive(client);
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