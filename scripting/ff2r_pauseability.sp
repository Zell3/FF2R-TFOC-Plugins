/*
  "pause" // Ability name can use suffixes
  {
    "slot"	      "0"          // Ability slot
    "duration"	  "6.0"       // Duration(in seconds) the effect will be active
    "plugin_name"	"ff2r_pauseability" // Plugin name
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

// Declarations
bool             paused;
bool             IsProxy[MAXPLAYERS + 1];


public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Pause Ability",
  author      = "Naydef, Zell (i just use new syntax and check if server sv_cheats is enabled)",
  description = "Subplugin, which can pause the whole server!",
  version     = "0.5.2",
  url         = "https://forums.alliedmods.net/showthread.php?p=2421885#post24218854"
};

public void OnPluginStart()
{
  if (FindConVar("sv_pausable") == INVALID_HANDLE)
  {
    SetFailState("sv_pausable convar not found. Subplugin disabled!!!");
  }
  AddCommandListener(Listener_PauseCommand, "pause");
  AddCommandListener(Listener_PauseCommand, "unpause");  // For safety
  // safe handle when pause command is used when boss just quit the game omg
  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

public void OnPluginEnd()
{
  RemoveCommandListener(Listener_PauseCommand, "pause");
  RemoveCommandListener(Listener_PauseCommand, "unpause");  // For safety
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

// just in case if the game is paused and the round ends, we need to unpause it
// btw this event is called it will bug our bgm sound :sob:
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  if (paused)
  {
    CreateTimer(0.1, UnPause, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "pause", false))
  {
    float duration = cfg.GetFloat("duration", 0.0);
    if (duration <= 0.0)
      duration = 6.0;  // safe handle negative and zero values

    // disable next attack for all players
    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidClient(i))
        continue;

      // just give me 1 player that can pause the game
      if (!paused)
      {
        HookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
        SetConVarInt(FindConVar("sv_cheats"), 1);
        UnhookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);

        HookConVarChange(FindConVar("sv_pausable"), HideCvarNotify);
        SetConVarBool(FindConVar("sv_pausable"), true);
        UnhookConVarChange(FindConVar("sv_pausable"), HideCvarNotify);

        IsProxy[i] = true;
        FakeClientCommand(i, "pause");
        IsProxy[i] = false;
        paused     = true;

        HookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
        SetConVarInt(FindConVar("sv_cheats"), 0);
        UnhookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
      }
      SetNextAttack(i, duration);
    }

    CreateTimer(duration, UnPause, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

// Clear ragetimer on client disconnect
public void OnClientDisconnect(int client)
{
  IsProxy[client] = false;
}

// safe handle when pause command is used by non-bosses or not from ability itself
public Action Listener_PauseCommand(int client, const char[] command, int argc)
{
  if (!IsProxy[client])
  {
    return Plugin_Handled;
  }
  return Plugin_Continue;
}

public Action UnPause(Handle hTimer)
{
  if (!paused)
    return Plugin_Stop;

  for (int i = 1; i <= MaxClients; i++)
  {
    if (!IsValidClient(i))
      continue;

    if (paused)
    {
      HookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
      SetConVarInt(FindConVar("sv_cheats"), 1);
      UnhookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);

      HookConVarChange(FindConVar("sv_pausable"), HideCvarNotify);
      SetConVarBool(FindConVar("sv_pausable"), true);
      UnhookConVarChange(FindConVar("sv_pausable"), HideCvarNotify);

      IsProxy[i] = true;
      FakeClientCommand(i, "pause");
      paused     = false;
      IsProxy[i] = false;

      HookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
      SetConVarInt(FindConVar("sv_cheats"), 0);
      UnhookConVarChange(FindConVar("sv_cheats"), HideCvarNotify);
    }

    SetNextAttack(i, 0.1);
  }

  return Plugin_Continue;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
    return false;

  if (!IsClientInGame(client) || !IsClientConnected(client))
    return false;

  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;

  return true;
}

stock void HideCvarNotify(Handle convar, const char[] oldValue, const char[] newValue)
{
  int flags = GetConVarFlags(convar);
  flags &= ~FCVAR_NOTIFY;
  SetConVarFlags(convar, flags);
}

public void SetNextAttack(int client, float duration)  // Fix prediction
{
  if (IsValidClient(client))
  {
    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + duration);
    for (int i = 0; i <= 2; i++)
    {
      int weapon = GetPlayerWeaponSlot(client, i);
      if (IsValidEntity(weapon))
      {
        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + duration);
      }
    }
  }
}
