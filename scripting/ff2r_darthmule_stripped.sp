/*
  "rage_condition"	// Ability name can use suffixes
  {
    "condition" "0" // 0 = ignite, 1 = bleed, 2 = strip to melee, 3 = BONK stun
    "duration" "10"
    "distance" "9999"
    "plugin_name" "ff2r_darthmule_stripped"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name    = "Freak Fortress 2: Completely Stripped Version of Darth's Ability Pack Fix",
  author  = "Darthmule, Zell",
  version = "1.3.1",
};

bool isOnStripMelee[MAXPLAYERS + 1];  // Check if the player is on strip to melee
float g_flStripDuration[MAXPLAYERS + 1];  // Add this with other globals

public void FF2R_OnBossRemoved(int client)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i) && isOnStripMelee[i])
    {
      isOnStripMelee[i] = false;
      TF2_RegeneratePlayer(i);
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_condition", false) && cfg.IsMyPlugin())
  {
    int   ragecondition = cfg.GetInt("condition", -1);
    float rageduration  = cfg.GetFloat("duration", 10.0);
    float ragedistance  = cfg.GetFloat("distance", 9999.0);

    if (ragecondition < 0 || ragecondition > 3)
      return;

    float pos[3], pos2[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidLivingClient(i) || i == client)
        continue;

      if (GetClientTeam(i) == GetClientTeam(client))
        continue;

      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      if (GetVectorDistance(pos, pos2) < ragedistance)
      {
        if (!TF2_IsPlayerInCondition(i, TFCond_Ubercharged))
        {
          if (ragecondition == 0)
          {
            TF2_IgnitePlayer(i, client, rageduration);
          }
          else if (ragecondition == 1) {
            TF2_MakeBleed(i, client, rageduration);
          }
          else if (ragecondition == 3) {
            TF2_StunPlayer(i, rageduration, 0.0, TF_STUNFLAG_BONKSTUCK, client);
          }
        }
        else {
          if (ragecondition == 2)
          {
            StripToMelee(i, rageduration);
          }
        }
      }
    }
  }
}

public void StripToMelee(int client, float duration)
{
  isOnStripMelee[client] = true;
  g_flStripDuration[client] = GetGameTime() + duration;
  
  TF2_RemoveWeaponSlot(client, 0);
  TF2_RemoveWeaponSlot(client, 1);
  int iWeapon = GetPlayerWeaponSlot(client, 2);
  if (iWeapon > MaxClients && IsValidEntity(iWeapon))
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon, 0);
  TF2_RemoveWeaponSlot(client, 3);
  TF2_RemoveWeaponSlot(client, 4);
  
  SDKHook(client, SDKHook_PreThink, PreThink_StripMelee);
}

public void PreThink_StripMelee(int client)
{
  if (!IsValidClient(client) || !isOnStripMelee[client])
  {
    SDKUnhook(client, SDKHook_PreThink, PreThink_StripMelee);
    return;
  }
  
  if (GetGameTime() >= g_flStripDuration[client])
  {
    isOnStripMelee[client] = false;
    TF2_RegeneratePlayer(client);
    SDKUnhook(client, SDKHook_PreThink, PreThink_StripMelee);
  }
}

stock bool IsValidLivingClient(int client)  // Checks if a client is a valid living one.
{
  if (client <= 0 || client > MaxClients) return false;
  return IsValidClient(client) && IsPlayerAlive(client);
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