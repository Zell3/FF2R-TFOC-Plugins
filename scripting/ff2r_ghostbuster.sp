/*
  "ghostbuster_medigun"
  {
    "mode"    "1"     // 0 = normal heal, 1 = take damage, 2 = stun
    // mode 0 and 1 means health amount
    // mode 2 means stun duration
    "amount"  "6.0"

    "plugin_name" "ff2r_ghostbuster"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2utils>
#include <dhooks>
#include <tf2attributes>
#include <medigun_patch>

#pragma semicolon 1
#pragma newdecls required

// Handle OnHeal;

public Plugin myinfo =
{
  name    = "FF2R : Ghostbuster",
  author  = "Naydef, Nopied, Zell",
  version = "1.0.0",
};

// ability variables
bool  g_bGhostMedigun[MAXPLAYERS + 1];  // check if player can use ability
int   g_iGhostMode[MAXPLAYERS + 1];     // 0 = normal heal, 1 = take damage, 2 = stun
float g_flGhostAmount[MAXPLAYERS + 1];  // heal amount or stun duration

float g_flLastDamgeTime[MAXPLAYERS + 1];  // interval

// dtour for CWeaponMedigun::AllowedToHealTarget from gamedata
public void OnPluginStart()
{
  GameData gamedatafile = LoadGameConfigFile("ghostbuster_defs.games");
  if (gamedatafile == null)
    SetFailState("Cannot find file ghostbuster_defs.games!");

  Address addr = gamedatafile.GetMemSig("CWeaponMedigun::AllowedToHealTarget");
  if (addr == Address_Null)
  {
    LogError("Failed to find signature for CWeaponMedigun::AllowedToHealTarget");
    delete gamedatafile;
    return;
  }

  LogMessage("Found AllowedToHealTarget signature at address: 0x%X", view_as<int>(addr));
  CreateDynamicDetour(gamedatafile, "CWeaponMedigun::AllowedToHealTarget", _, Detour_AllowedToHealTargetPost);

  delete gamedatafile;

  // OnHeal = CreateGlobalForward("TF2_OnHealTarget", ET_Hook, Param_Cell, Param_Cell, Param_CellByRef);
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
  DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
  if (detour == null)
  {
    LogError("Failed to create detour for %s - signature may be outdated", name);
    return;
  }

  bool success = true;
  if (callbackPre != INVALID_FUNCTION)
    success &= detour.Enable(Hook_Pre, callbackPre);

  if (callbackPost != INVALID_FUNCTION)
    success &= detour.Enable(Hook_Post, callbackPost);

  if (!success)
    LogError("Failed to enable detour hooks for %s", name);
}

// get data from boss cfg
public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("ghostbuster_medigun");
    if (ability.IsMyPlugin())
    {
      g_iGhostMode[client]    = ability.GetInt("mode", 1);
      g_flGhostAmount[client] = ability.GetFloat("amount", 6.0);
      g_bGhostMedigun[client] = true;
    }
  }
  else {
    // clear data at round start
    for (int i = 1; i <= MaxClients; i++)
    {
      g_flLastDamgeTime[i] = 0.0;
      g_bGhostMedigun[i]   = false;
      g_iGhostMode[i]      = 0;
      g_flGhostAmount[i]   = 0.0;
    }
  }
}

// detour for CWeaponMedigun::AllowedToHealTarget
public MRESReturn Detour_AllowedToHealTargetPost(int pThis, Handle hReturn, Handle hParams)
{
  // Invalid medigun or target
  if (pThis == -1 || DHookIsNullParam(hParams, 1))
    return MRES_Ignored;

  int owner  = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
  int target = DHookGetParam(hParams, 1);

  // Invalid owner or target
  if (!IsValidClient(owner) || !IsValidEntity(target))
    return MRES_Ignored;

  // owner is not a boss that have this ability
  if (!g_bGhostMedigun[owner])
    return MRES_Ignored;

  // Always allow healing enemies by returning true
  if (IsValidClient(target) && IsPlayerAlive(target))
  {
    if (TF2_GetClientTeam(owner) != TF2_GetClientTeam(target))
    {
      float pos[3];
      GetClientEyePosition(target, pos);

      // Handle different modes
      switch (g_iGhostMode[owner])
      {
        case 1:  // Damage
        {
          if (!(TF2_IsPlayerInCondition(target, TFCond_Ubercharged) || TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden)) && g_flLastDamgeTime[owner] < GetGameTime())
          {
            g_flLastDamgeTime[owner] = GetGameTime() + 0.15;
            SDKHooks_TakeDamage(target, owner, owner, g_flGhostAmount[owner], DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, pThis, pos, pos);
            TF2Attrib_AddCustomPlayerAttribute(owner, "heal rate penalty", 0.0, 0.25);
          }
        }
        case 2:  // Stun
        {
          if (g_flLastDamgeTime[owner] < GetGameTime())
          {
            g_flLastDamgeTime[owner] = GetGameTime() + g_flGhostAmount[owner];
            TF2_StunPlayer(target, g_flGhostAmount[owner], 0.0, TF_STUNFLAGS_SMALLBONK);
            TF2Attrib_AddCustomPlayerAttribute(owner, "heal rate penalty", 0.0, 0.25);
          }
        }
      }

      DHookSetReturn(hReturn, true);
      return MRES_Supercede;  // Changed from MRES_ChangedOverride
    }
  }

  return MRES_Ignored;
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