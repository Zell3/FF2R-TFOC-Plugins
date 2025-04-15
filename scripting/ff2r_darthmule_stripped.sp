/*
  "rage_condition"	// Ability name can use suffixes
  {
		"condition" "0"
		"duration" "0"
		"distance" "0"

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
  author  = "Darthmule, edit by Zell",
  version = "1.3",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_condition", false) && cfg.IsMyPlugin())
  {
    int   ragecondition = cfg.GetInt("condition");
    float rageduration  = cfg.GetFloat("duration");
    float ragedistance  = cfg.GetFloat("distance");

    float pos[3];
    float pos2[3];
    float distance;

    float vel[3];
    vel[2] = 20.0;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && !TF2_IsPlayerInCondition(i, TFCond_Ubercharged))
      {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        distance = GetVectorDistance(pos, pos2);

        if (distance < ragedistance)
        {
          if (ragecondition == 0)
          {
            TF2_IgnitePlayer(i, client);
          }
          else if (ragecondition == 1) {
            TF2_MakeBleed(i, client, rageduration);
          }
          else if (ragecondition == 2) {
            StripToMelee(i, rageduration);
          }
          else if (ragecondition == 3) {
            TF2_StunPlayer(i, rageduration, 0.0, TF_STUNFLAG_BONKSTUCK, client);
          }
        }
      }
    }
  }
}

public void StripToMelee(int client, float duration)
{
  TF2_RemoveWeaponSlot(client, 0);
  TF2_RemoveWeaponSlot(client, 1);
  int iWeapon = GetPlayerWeaponSlot(client, 2);
  if (iWeapon > MaxClients && IsValidEntity(iWeapon))
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon, 0);
  TF2_RemoveWeaponSlot(client, 3);
  TF2_RemoveWeaponSlot(client, 4);

  DataPack pack;
  CreateDataTimer(duration, returnWeapons, pack);
  pack.WriteCell(GetClientUserId(client));
}

public Action returnWeapons(Handle timer, DataPack pack)
{
  pack.Reset();
  int client = GetClientOfUserId(pack.ReadCell());

  if (IsValidLivingPlayer(client))
  {
    TF2_RegeneratePlayer(client);
  }
  return Plugin_Continue;
}

stock bool IsValidLivingPlayer(int client)
{
  if (client <= 0 || client > MaxClients)
    return false;

  return IsClientInGame(client) && IsPlayerAlive(client);
}