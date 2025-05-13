/*
  "rage_outline"		// Ability name can use suffixes
  {
    "slot"			  "0"				  // Ability Slot
    "duration"	  "10.0"			// Duration of the outline
    "target"      "3"         // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"	"ff2r_outline"
  }

  "special_outline"
  {
    "target"      "3"         // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"	"ff2r_outline"
  }

  "special_onhit_outline"
  {
    "max"		     "3"
    "weapons1"   "5"	        // Weapon item index (TF2Items) to trigger the outline
    "duration1"  "10.0"	      // Duration of the outline

    "weapons2"   "105"	      // Weapon item index (TF2Items) to trigger the outline
    "duration2" "10.0"	      // Duration of the outline

    "weapons3"   "105"	      // Weapon item index (TF2Items) to trigger the outline
    "duration3"  "10.0"	      // Duration of the outline

    "plugin_name"	"ff2r_outline"
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
  name        = "Freak Fortress 2 Rewrite: Outline Subplugin",
  author      = "M7, Zell",
  description = "Standalone outline abilities for FF2:R bosses borrow code from M7",
  version     = "1.0.0",
};

#define INACTIVE 100000000.0

bool  g_bSpecialOutlineActive[MAXPLAYERS + 1];
float g_fOutlineTime[MAXPLAYERS + 1];

enum struct OnHitOutline
{
  int   index;
  float duration;
}

ArrayList g_OnHitOutline[MAXPLAYERS + 1];

public void OnPluginStart()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    g_OnHitOutline[i] = new ArrayList(sizeof(OnHitOutline));
  }
  ClearEverything();
}

public void OnPluginEnd()
{
  ClearEverything();
  for (int i = 1; i <= MaxClients; i++)
  {
    delete g_OnHitOutline[i];
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_outline");
    if (ability.IsMyPlugin())
    {
      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidClient(i) && IsTarget(client, i, ability.GetInt("target", 0)))
        {
          g_bSpecialOutlineActive[i] = true;
          SDKHook(i, SDKHook_PreThink, Outline_Prethink);
        }
      }
    }

    AbilityData onhit = cfg.GetAbility("special_onhit_outline");
    if (onhit.IsMyPlugin())
    {
      g_OnHitOutline[client] = new ArrayList(sizeof(OnHitOutline));

      int max                = onhit.GetInt("max", 0);
      for (int i = 1; i <= max; i++)
      {
        OnHitOutline outline;

        char         argument[64];
        Format(argument, sizeof(argument), "weapons%d", i);
        outline.index = onhit.GetInt(argument, -1);
        if (outline.index == -1) continue;
        Format(argument, sizeof(argument), "duration%d", i);
        outline.duration = onhit.GetFloat(argument, 0.0);
        if (outline.duration == 0.0) continue;
        g_OnHitOutline[client].PushArray(outline);
      }

      for (int i = 1; i <= MaxClients; i++)
      {
        if (!IsValidClient(i)) continue;
        if (i == client) continue;
        SDKHook(i, SDKHook_OnTakeDamage, OnHit_TakeDamage);
      }
    }
  }
}

public void OnClientPutInServer(int client)
{
  if (!IsValidClient(client)) return;

  for (int i = 1; i <= MaxClients; i++)
  {
    if (!IsValidLivingClient(i)) continue;

    BossData boss = FF2R_GetBossData(i);

    if (!boss) continue;

    AbilityData special = boss.GetAbility("special_outline");
    if (special.IsMyPlugin())
    {
      if (!IsTarget(i, client, special.GetInt("target", 0))) continue;

      g_bSpecialOutlineActive[client] = true;
      SDKHook(client, SDKHook_PreThink, Outline_Prethink);
    }

    AbilityData onhit = boss.GetAbility("special_onhit_outline");
    if (onhit.IsMyPlugin())
    {
      SDKHook(client, SDKHook_OnTakeDamage, OnHit_TakeDamage);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  ClearEverything();
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin()) return;

  if (!StrContains(ability, "rage_outline", false))
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidLivingClient(i)) continue;
      if (IsTarget(client, i, cfg.GetInt("target", 0)))
      {
        if (g_fOutlineTime[i] != INACTIVE)
        {
          g_fOutlineTime[i] += cfg.GetFloat("duration", 10.0);
        }
        else
        {
          g_fOutlineTime[i] = GetEngineTime() + cfg.GetFloat("duration", 10.0);
          SDKHook(i, SDKHook_PreThink, Outline_Prethink);
        }
      }
    }
  }
}

public void Outline_Prethink(int client)
{
  // Handle rage outline
  if (g_fOutlineTime[client] != INACTIVE)
  {
    if (GetEngineTime() >= g_fOutlineTime[client])
    {
      g_fOutlineTime[client] = INACTIVE;
      if (!g_bSpecialOutlineActive[client])
      {
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
        SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
      }
    }
  }

  // Handle special outline
  if (!g_bSpecialOutlineActive[client] && g_fOutlineTime[client] == INACTIVE)
  {
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
    SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
    return;
  }

  if (IsValidLivingClient(client))
  {
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
  }
}

public Action OnHit_TakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
  if (!IsValidClient(attacker) || !IsValidClient(victim))
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(attacker);
  if (!boss)
    return Plugin_Continue;

  if (!boss.GetAbility("special_onhit_outline").IsMyPlugin())
    return Plugin_Continue;

  int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
  if (!IsValidEntity(weapon))
    return Plugin_Continue;

  int          itemIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

  OnHitOutline outline;
  for (int i = 0; i < g_OnHitOutline[attacker].Length; i++)
  {
    g_OnHitOutline[attacker].GetArray(i, outline);
    if (outline.index == itemIndex)
    {
      if (g_fOutlineTime[victim] != INACTIVE)
      {
        g_fOutlineTime[victim] = GetEngineTime() + outline.duration;
      }
      else
      {
        g_fOutlineTime[victim] = GetEngineTime() + outline.duration;
        SDKHook(victim, SDKHook_PreThink, Outline_Prethink);
      }
      break;
    }
  }

  return Plugin_Continue;
}

public void ClearEverything()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      SDKUnhook(i, SDKHook_PreThink, Outline_Prethink);
      SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
    }
    g_bSpecialOutlineActive[i] = false;
    g_fOutlineTime[i]          = INACTIVE;
    g_OnHitOutline[i].Clear();
  }
}

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
  {
    case 1:  // if target is boss,
    {
      if (client == target) return true;
      return false;
    }
    case 2:  // if target's team same team as boss's team
    {
      if (GetClientTeam(target) == GetClientTeam(client)) return true;
      return false;
    }
    case 3:  // if target's team is not same team as boss's team
    {
      if (GetClientTeam(target) != GetClientTeam(client)) return true;
      return false;
    }
    case 4:  // if target is not boss
    {
      if (client != target) return true;
      return false;
    }
    default:  // effect everyone
    {
      return true;
    }
  }
}

stock bool IsValidLivingClient(int client)
{
  if (IsValidClient(client) && IsPlayerAlive(client)) return true;
  return false;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
  if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client))) return false;
  return true;
}