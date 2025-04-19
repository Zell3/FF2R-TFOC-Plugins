/*
  "ability_shiranui"
  {
    // slot is ignored.
    "cost"    "10.0"              // rage cost per use
    "duration"    "10.0"              // Time being hacked - 0 means forever
    "lastman"    "1"                 // 1-If only one player disable hack ability 0-No disable

    "plugin_name"    "ff2r_shiranui"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

int  bossId;
int  PlayersAlive[4];
bool SpecTeam;

#pragma semicolon 1
#pragma newdecls required

/**
 * If you want to use formula to your ability, uncomment this.
 * This file provides ParseFormula functions.
 */
//#include "freak_fortress_2/formula_parser.sp"

/**
 * After 2023-07-25 Update, we don't need to set 36.
 */
//#define MAXTF2PLAYERS MAXPLAYERS + 1

/**
 * Original author is J0BL3SS. But he is retired and privatize all his plugins.
 *
 * Your plugin's info. Fill it.
 */
public Plugin myinfo =
{
  name        = "[FF2R] Dominated",
  author      = "NayDef but Zell fix it",
  description = "",
  version     = "1.0.0",
  url         = ""
};

bool   b_isHacked[MAXPLAYERS + 1];
ConVar CvarFriendlyFire;

public void OnPluginStart()
{
  HookEvent("player_death", PlayerDeath);
  AddCommandListener(Command_InterceptTaunt, "+taunt");
  AddCommandListener(Command_InterceptTaunt, "taunt");
  CvarFriendlyFire = FindConVar("mp_friendlyfire");

  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      b_isHacked[client] = false;
    }
  }
}

public Action Command_InterceptTaunt(int client, const char[] command, int args)
{
  if (IsValidClient(client) && b_isHacked[client])
    return Plugin_Handled;

  return Plugin_Continue;
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;
  if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)  // Dead Ringer spies
    return;
  if (b_isHacked[client])
  {
    ConvertToFriendly(client, bossId);
  }
  b_isHacked[client] = false;
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client) && FF2R_GetBossData(client))
      FF2R_OnBossRemoved(client);
  }
}

public void OnClientDisconnect_Post(int client)
{
  b_isHacked[client] = false;
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 *
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (!IsValidClient(client))
      continue;
    b_isHacked[client] = false;
  }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
  if (!IsValidClient(client))
    return Plugin_Continue;
  if (!IsPlayerAlive(client))
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(client);
  if (!boss)
    return Plugin_Continue;
  bossId              = client;
  AbilityData ability = boss.GetAbility("ability_shiranui");
  if (!ability.IsMyPlugin())
    return Plugin_Continue;

  if (buttons & IN_RELOAD)
  {
    int team = CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client);
    if (ability.GetInt("lastman", 1) && GetTotalPlayersAlive(team) == 1)
    {
      PrintHintText(client, "You are not allowed to Dominate the last player!");
      return Plugin_Continue;
    }
    float bosschargemin = ability.GetFloat("cost");
    float charge        = GetBossCharge(boss, "0");
    if (charge >= bosschargemin)
    {
      int targetclient = TraceToObject(client);
      if (IsValidClient(targetclient) && IsPlayerAlive(targetclient) && !b_isHacked[targetclient])
      {
        PrintHintText(client, "You Dominated %N!", targetclient);
        PrintCenterText(targetclient, "You Got Dominated!");

        SetBossCharge(boss, "0", charge - bosschargemin);
        ConvertToEnemy(targetclient, bossId);
        b_isHacked[targetclient] = true;

        float time               = ability.GetFloat("duration", 0.0);
        if (time > 0.01)  // I want to be sure float values don't mess up
          CreateTimer(time, Timer_BackToGood, GetClientUserId(targetclient), TIMER_FLAG_NO_MAPCHANGE);
      }
    }
    else {
      PrintHintText(client, "No enough rage to Dominated!");
    }
  }
  return Plugin_Continue;
}

public Action Timer_BackToGood(Handle htimer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (!IsValidClient(client))
    return Plugin_Continue;
  if (IsPlayerAlive(client))
  {
    ConvertToFriendly(client, bossId);
    PrintCenterText(client, "You are no longer Dominated!");
  }
  b_isHacked[client] = false;

  return Plugin_Continue;
}

void ConvertToEnemy(int client, int bossId)
{
  SetEntProp(client, Prop_Send, "m_lifeState", 2);
  ChangeClientTeam(client, GetClientTeam(bossId));
  SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

void ConvertToFriendly(int client, int bossId)
{
  SetEntProp(client, Prop_Send, "m_lifeState", 2);
  ChangeClientTeam(client, (GetClientTeam(bossId) == 3) ? 2 : 3);
  SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

public int TraceToObject(int client)
{
  float vecClientEyePos[3], vecClientEyeAng[3];
  GetClientEyePosition(client, vecClientEyePos);
  GetClientEyeAngles(client, vecClientEyeAng);
  TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayGrab, client);
  return TR_GetEntityIndex(null);
}

float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  return cfg.GetFloat(buffer, defaul);
}

void SetBossCharge(ConfigData cfg, const char[] slot, float amount)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  cfg.SetFloat(buffer, amount);
}

stock int GetClosestClient(int client)
{
  float vPos1[3], vPos2[3];
  GetClientEyePosition(client, vPos1);

  int   iTeam             = GetClientTeam(client);
  int   iClosestEntity    = -1;
  float flClosestDistance = -1.0;
  float flEntityDistance;

  for (int i = 1; i <= MaxClients; i++)
    if (IsValidClient(i))
    {
      if (GetClientTeam(i) != iTeam && IsPlayerAlive(i) && i != client)
      {
        GetClientEyePosition(i, vPos2);
        flEntityDistance = GetVectorDistance(vPos1, vPos2);
        if ((flEntityDistance < flClosestDistance) || flClosestDistance == -1.0)
        {
          if (CanSeeTarget(client, i, iTeam, false))
          {
            flClosestDistance = flEntityDistance;
            iClosestEntity    = i;
          }
        }
      }
    }
  return iClosestEntity;
}

bool CanSeeTarget(int iClient, int iTarget, int iTeam, bool bCheckFOV)
{
  float flStart[3], flEnd[3];
  GetClientEyePosition(iClient, flStart);
  GetClientEyePosition(iTarget, flEnd);

  TR_TraceRayFilter(flStart, flEnd, MASK_SOLID, RayType_EndPoint, TraceRayFilterClients, iTarget);
  if (TR_GetEntityIndex() == iTarget)
  {
    if (TF2_GetPlayerClass(iTarget) == TFClass_Spy)
    {
      if (TF2_IsPlayerInCondition(iTarget, TFCond_Cloaked) || TF2_IsPlayerInCondition(iTarget, TFCond_Disguised))
      {
        if (TF2_IsPlayerInCondition(iTarget, TFCond_CloakFlicker)
            || TF2_IsPlayerInCondition(iTarget, TFCond_OnFire)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Jarated)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Milked)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Bleeding))
        {
          return true;
        }

        return false;
      }
      if (TF2_IsPlayerInCondition(iTarget, TFCond_Disguised) && GetEntProp(iTarget, Prop_Send, "m_nDisguiseTeam") == iTeam)
      {
        return false;
      }

      return true;
    }

    if (TF2_IsPlayerInCondition(iTarget, TFCond_Ubercharged)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedHidden)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedCanteen)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedOnTakeDamage)
        || TF2_IsPlayerInCondition(iTarget, TFCond_PreventDeath)
        || TF2_IsPlayerInCondition(iTarget, TFCond_Bonked))
    {
      return false;
    }
    if (bCheckFOV)
    {
      return true;
    }

    return true;
  }
  return false;
}

public void FF2R_OnAliveChanged(const int alive[4], const int total[4])
{
  for (int i; i < 4; i++)
  {
    PlayersAlive[i] = alive[i];
  }

  SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

int GetTotalPlayersAlive(int team = -1)
{
  int amount;
  for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++)
  {
    if (i != team)
      amount += PlayersAlive[i];
  }

  return amount;
}

public bool TraceRayFilterClients(int iEntity, int iMask, any hData)
{
  if (iEntity > 0 && iEntity <= MaxClients)
  {
    if (iEntity == hData)
    {
      return true;
    }
    else
    {
      return false;
    }
  }
  return true;
}

public bool TraceRayGrab(int entityhit, int mask, any self)
{
  if (entityhit > 0 && entityhit <= MaxClients)
  {
    if (IsPlayerAlive(entityhit) && entityhit != self)
    {
      return true;
    }
    else
    {
      return false;
    }
  }
  else
  {
    char classname[32];
    if (GetEntityClassname(entityhit, classname, sizeof(classname)) && (StrEqual(classname, "prop_physics") || StrEqual(classname, "tf_ammo_pack") || !StrContains(classname, "tf_projectil")))
    {
      return true;
    }
  }
  return false;
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