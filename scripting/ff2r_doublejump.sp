/*
  "rage_doublejump"	// Ability name can use suffixes
  {
    "slot"					"0"						// Ability Slot
    "duration"      "10.0"				// Duration
    "target"        "1"						// 0: Everyone, 1: Boss, 2: Boss Team, 3: Enemy Team, 4: Except boss
    "velocity"			"250.0"				// Velocity
    "max"		    		"1"						// Max of extra jump
    "plugin_name"		"ff2r_doublejump"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

public Plugin myinfo =
{
  name        = "[FF2R] Double Jump",
  author      = "Paegus, Zell",
  description = "Doublejump!!!!",
  version     = "1.1.0",
};

float g_flBoost[MAXPLAYERS + 1];
int   g_fLastButtons[MAXPLAYERS + 1];
int   g_fLastFlags[MAXPLAYERS + 1];
int   g_iJumps[MAXPLAYERS + 1];
int   g_iJumpMax[MAXPLAYERS + 1];
bool  g_bIsTarget[MAXPLAYERS + 1];

float g_fDuration[MAXPLAYERS + 1];

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    // Initialize all players
    g_flBoost[client]      = 0.0;
    g_fLastButtons[client] = 0;
    g_fLastFlags[client]   = 0;
    g_iJumps[client]       = 0;
    g_iJumpMax[client]     = 0;
    g_bIsTarget[client]    = false;
    g_fDuration[client]    = INACTIVE;
  }
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    // Reset all players
    g_flBoost[client]      = 0.0;
    g_fLastButtons[client] = 0;
    g_fLastFlags[client]   = 0;
    g_iJumps[client]       = 0;
    g_iJumpMax[client]     = 0;
    g_bIsTarget[client]    = false;
    g_fDuration[client]    = INACTIVE;
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    g_flBoost[i]      = 0.0;
    g_fLastButtons[i] = 0;
    g_fLastFlags[i]   = 0;
    g_iJumps[i]       = 0;
    g_iJumpMax[i]     = 0;
    g_bIsTarget[i]    = false;
    g_fDuration[i]    = INACTIVE;
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_doublejump", false) && cfg.IsMyPlugin())
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i))
      {
        g_flBoost[i]   = cfg.GetFloat("velocity", 250.0);
        g_iJumpMax[i]  = cfg.GetInt("max", 1);
        g_fDuration[i] = GetEngineTime() + cfg.GetFloat("duration", 10.0);
        g_bIsTarget[i] = IsTarget(client, i, cfg.GetInt("target", 0));
      }
    }
  }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
  if (!IsValidClient(client) || !g_bIsTarget[client] || g_fDuration[client] == INACTIVE || g_fDuration[client] < GetEngineTime())
  {
    return Plugin_Continue;
  }

  int fCurFlags = GetEntityFlags(client);

  if (g_fLastFlags[client] & FL_ONGROUND)
  {
    if (!(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[client] & IN_JUMP) && (buttons & IN_JUMP))
    {
      OriginalJump(client);
    }
  }
  else if (fCurFlags & FL_ONGROUND)
  {
    Landed(client);
  }
  else if (!(g_fLastButtons[client] & IN_JUMP) && (buttons & IN_JUMP))
  {
    ReJump(client);
  }

  g_fLastFlags[client]   = fCurFlags;
  g_fLastButtons[client] = buttons;

  return Plugin_Continue;
}

stock void OriginalJump(const int client)
{
  g_iJumps[client] = 1;  // Set to 1 instead of incrementing
}

stock void Landed(const int client)
{
  g_iJumps[client] = 0;
}

stock void ReJump(const int client)
{
  // Change condition to check if we haven't exceeded max jumps yet
  if (g_iJumps[client] < g_iJumpMax[client])
  {
    float oldVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", oldVel);

    float vVel[3];
    vVel[0] = oldVel[0];  // Preserve horizontal movement
    vVel[1] = oldVel[1];
    vVel[2] = g_flBoost[client];

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
    g_iJumps[client]++;
  }
}

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
  {
    case 1:  // if target is boss,
    {
      if (client == target) return true;
      else return false;
    }
    case 2:  // if target's team same team as boss's team
    {
      if (GetClientTeam(target) == GetClientTeam(client)) return true;
      else return false;
    }
    case 3:  // if target's team is not same team as boss's team
    {
      if (GetClientTeam(target) != GetClientTeam(client)) return true;
      else return false;
    }
    case 4:  // if target is not boss
    {
      if (client != target) return true;
      else return false;
    }
    default:  // effect everyone
    {
      return true;
    }
  }
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