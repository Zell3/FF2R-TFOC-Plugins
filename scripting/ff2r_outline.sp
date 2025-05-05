/*
  // outline abilities (outline color will always represent the team color cuz why not)

  "rage_outline"		// Ability name can use suffixes
  {
    "slot"			"0"								  // Ability Slot
    "duration"	"10.0"							// Duration of the outline
    "target"  "3"                   // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name"	"ff2r_outline"
  }

  "special_outline"
  {
    "target"  "3"                   // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"	"ff2r_outline"
  }

  // GONNA MAKE THIS ABILITY LATER
  "special_onhit_outline"
  {
    // warning: do not use this ability with other outline abilities
    // for some reason i decided to make it dectect the attacker weapon item index instead of when got attacked
    "max"		     "3"
    "weapons1"   "5"	  // Weapon item index (TF2Items) to trigger the outline
    "duration1"  "10.0"	// Duration of the outline
    "color1"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

    "weapons2"   "105"	// Weapon item index (TF2Items) to trigger the outline
    "duration2" "10.0"	// Duration of the outline
    "color2"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

    "weapons3"   "105"	// Weapon item index (TF2Items) to trigger the outline
    "duration3"  "10.0"	// Duration of the outline
    "color3"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

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

int   BossId;
bool  IsRound;
float EndOutline[MAXPLAYERS + 1];
bool  HasSpecialOutline[MAXPLAYERS + 1];

public void OnPluginStart()
{
  IsRound = false;
  for (int i = 1; i <= MaxClients; i++)
  {
    EndOutline[i] = INACTIVE;
		HasSpecialOutline[i] = false;
  }
}

public void OnPluginEnd()
{
  IsRound = false;
  for (int i = 1; i <= MaxClients; i++)
  {
    EndOutline[i] = INACTIVE;
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_outline");
    if (ability.IsMyPlugin())
    {
      IsRound = true;  // Set the round state to true (this will handle when respawn needs to be done)
			BossId = client;
			for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidLivingClient(i) && IsTarget(client, i, ability.GetInt("target", 0)))
        {
          EndOutline[i] = GetEngineTime() + ability.GetFloat("duration", 10.0);
					HasSpecialOutline[i] = true;
					SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
          SDKHook(i, SDKHook_PreThink, Outline_Prethink);
        }
      }
    }
  }
}

public void OnClientPutInServer(int client)
{
  if (IsValidClient(client) && IsRound && IsTarget(BossId, client, 0))
	{
		EndOutline[client] = INACTIVE;  // Reset the outline duration for the new player
		HasSpecialOutline[client] = false;
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
	}
  {
    SDKHook(client, SDKHook_PreThink, Outline_Prethink);
  }
}

public void FF2R_OnBossRemoved(int client)
{
  IsRound = false;  // Set the round state to false (this will handle when respawn needs to be done)
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      EndOutline[client] = INACTIVE;
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_outline", false))
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidLivingClient(i) && IsTarget(client, i, cfg.GetInt("target", 0)))
      {
        EndOutline[i] = GetEngineTime() + cfg.GetFloat("duration", 10.0);
        SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
        SDKHook(i, SDKHook_PreThink, Outline_Prethink);
      }
    }
  }
}

public void Outline_Prethink(int client)
{
  OutlineTick(client, GetEngineTime());
}

public void OutlineTick(int client, flaot gameTime)
{
  if (!IsRound) {
	  SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
    SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
	}

  if (gameTime >= EndOutline[client])
  {
    SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
    SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
  }
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

stock bool IsValidLivingClient(int client)
{
  if (IsValidClient(client) && IsPlayerAlive(client))
    return true;

  return false;
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