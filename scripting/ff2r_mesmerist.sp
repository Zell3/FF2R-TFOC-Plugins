/*
  "mesmerist_passive"		//Ability name
  {
    "fov"			"90"            // FOV

    "plugin_name"	"ff2r_mesmerist"		// this subplugin name
  }

  "rage_strip_weapons" // Ability name can use suffixes
  {
    // swap weapons with the red team
    "slot"			"0"             // Ability Slot
    "duration"      "10.0"          // Duration
    "primary"     "0"             // swap primary weapon 1 = on, 0 = off
    "secondary"   "0"             // swap secondary weapon
    "melee"       "0"             // swap melee weapon 1 = on, 0 = off
    "random"      "0"             // random strip 1 weapon between slots that set to 1

    "plugin_name"	"ff2r_mesmerist"
  }


*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME   "The Mesmerist"
#define PLUGIN_AUTHOR "Zell"

bool IsDisabledThirdPerson;  // Check if the third person is disabled
int  passiveTarget[MAXPLAYERS + 1];
int  defaultFOV[MAXPLAYERS + 1];
int  passiveFOV;                  // Default FOV for TF2 is 90
int  tf_weapondrop_lifetime = 0;  // Default weapon drop lifetime

bool IsRound;

public Plugin myinfo =
{
  name   = PLUGIN_NAME,
  author = PLUGIN_AUTHOR,
};

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      BossData cfg = FF2R_GetBossData(client);  // Get boss config (known as boss index) from player
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);  // If boss is valid, Hook the abilities because this subplugin is most likely late-loaded
      }
    }
  }
}

// public void OnPluginEnd()
// {
//   for (int client = 1; client <= MaxClients; client++)
//   {
//     // Clear everything from players, because FF2:R either disabled/unloaded or this subplugin unloaded
//   }
// }
public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  AbilityData passive = cfg.GetAbility("mesmerist_passive");  // Get the ability from the boss config

  // Check if the boss is valid and setup the hooks for the abilities
  if (!(!setup || FF2R_GetGamemodeType() != 2))
  {
    if (passive.IsMyPlugin())  // Check if the ability is from this plugin
    {
      // disable cvar thirdperson
      if (GetConVarBool(FindConVar("thirdperson_enabled")))
      {
        HookConVarChange(FindConVar("thirdperson_enabled"), HideCvarNotify);
        SetConVarBool(FindConVar("thirdperson_enabled"), false);
        UnhookConVarChange(FindConVar("thirdperson_enabled"), HideCvarNotify);
      }

      IsDisabledThirdPerson = true;  // Set the passive round to true

      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidClient(i))  // Check if the client is valid and if the target is valid
        {
          SetVariantInt(0);
          AcceptEntityInput(i, "SetForcedTauntCam");
        }
      }
    }
  }
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    if (passive.IsMyPlugin())  // Check if the ability is from this plugin
    {
      passiveFOV = passive.GetInt("fov", 90);
      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidClient(i))  // Check if the client is valid and if the target is valid
        {
          passiveTarget[i] = true;             // Set the passive FOV target to true
          defaultFOV[i]    = GetClientFOV(i);  // Get the default  a                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                FOV of the client
          SetClientFOV(i, passiveFOV, 0);      // Set the client FOV to the passive FOV target
        }
      }
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  IsRound = false;  // Set the passive round to false

  // Remove all hooks and clear everything from players, because boss is dead or removed
  if (!IsDisabledThirdPerson)
    return;  // If the client is not valid, return

  if (!GetConVarBool(FindConVar("thirdperson_enabled")))
  {
    HookConVarChange(FindConVar("thirdperson_enabled"), HideCvarNotify);
    SetConVarBool(FindConVar("thirdperson_enabled"), true);
    UnhookConVarChange(FindConVar("thirdperson_enabled"), HideCvarNotify);
  }

  // This is called when boss dies or removed by command
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i) && passiveTarget[i])  // Check if the client is valid and if the target is valid
    {
      SetClientFOV(i, defaultFOV[i], 1);  // Set the client FOV to the default FOV target
      passiveTarget[i] = false;           // Set the passive FOV target to false
    }
  }
  IsDisabledThirdPerson = false;  // Set the passive round to false
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  // Only process abilities from this plugin and non-"rage_strip_weapons" abilities.
  if (!cfg.IsMyPlugin())
    return;

  if (StrContains(ability, "rage_strip_weapons", false))
    return;

  IsRound                = true;

  float duration         = cfg.GetFloat("duration", 0.0);
  bool  doPrimary        = (cfg.GetInt("primary", 0) != 0);
  bool  doSecondary      = (cfg.GetInt("secondary", 0) != 0);
  bool  doMelee          = (cfg.GetInt("melee", 0) != 0);
  bool  useRandom        = (cfg.GetInt("random", 0) != 0);

  tf_weapondrop_lifetime = GetConVarInt(FindConVar("tf_dropped_weapon_lifetime"));
  HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
  SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), 0);
  UnhookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && IsEnemyTeam(client, i))
    {
      if (useRandom)
      {
        // Try random selection until a valid slot is chosen.
        int randomSlot = -1;
        for (;;)
        {
          randomSlot = GetRandomInt(0, 2);
          if (randomSlot == 0 && doPrimary)
          {
            TF2_RemoveWeaponSlot(i, 0);
            break;
          }
          else if (randomSlot == 1 && doSecondary)
          {
            TF2_RemoveWeaponSlot(i, 1);
            break;
          }
          else if (randomSlot == 2 && doMelee)
          {
            TF2_RemoveWeaponSlot(i, 2);
            break;
          }
          // If the random slot is not enabled, loop again.
        }
      }
      else
      {
        if (doPrimary)
        {
          TF2_RemoveWeaponSlot(i, 0);
        }
        if (doSecondary)
        {
          TF2_RemoveWeaponSlot(i, 1);
        }
        if (doMelee)
        {
          TF2_RemoveWeaponSlot(i, 2);
        }
      }
      // Reset the client character after the specified duration.
      CreateTimer(duration, ResetCharacter, i);
    }
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

stock bool IsEnemyTeam(int client, int target)
{
  if (client <= 0 || client > MaxClients || target <= 0 || target > MaxClients)
    return false;
  if (GetClientTeam(client) != GetClientTeam(target))
    return true;
  return false;
}

stock int GetClientFOV(int client)
{
  int fov = GetEntProp(client, Prop_Send, "m_iFOV");
  if (fov == 0)
    return 90;  // Default FOV for TF2 is 90
  else
    return fov;
}

stock void SetClientFOV(int client, int fov, int include_viewpoint = 0)
{
  if (include_viewpoint)
    SetEntProp(client, Prop_Send, "m_iFOV", fov);       // include viewpoint
  SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);  // only playermodel
}

public Action ResetCharacter(Handle timer, int target)
{
  if (!IsRound)
    return Plugin_Continue;

  if (!IsValidClient(target))
    return Plugin_Continue;

  TF2_RegeneratePlayer(target);

  if (GetConVarInt(FindConVar("tf_dropped_weapon_lifetime")) == 0)
  {
    HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
    SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), tf_weapondrop_lifetime);
    UnhookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
  }

  return Plugin_Continue;
}

stock void HideCvarNotify(Handle convar, const char[] oldValue, const char[] newValue)
{
  int flags = GetConVarFlags(convar);
  flags &= ~FCVAR_NOTIFY;
  SetConVarFlags(convar, flags);
}
