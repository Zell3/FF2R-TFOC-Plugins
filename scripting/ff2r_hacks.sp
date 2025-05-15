/*

   "ability_hackplayer"
   {
     // slot is ignored.
     "ragecost"    		"10.0"			// rage cost per use
     "duration"    		"10.0"			// Time being hacked - 0 means forever
     "aimbot"    			"1"					// 1-Aimbot disabled 0 - Aimbot active
     "lastman"				"1"					// 1-If only one player disable hack ability 0-No disable
     "preventtaunt"		"1"					// 1-Prevent taunt 0-Don't prevent taunt
     "plugin_name"		"ff2r_hacks"
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
  name    = "Freak Fortress 2 Rewrite: Hacks",
  author  = "Naydef, zell",
  version = "1.4",
  url     = ""
};

bool  g_bIsHacked[MAXPLAYERS + 1];      // Internal
float g_flHackTime[MAXPLAYERS + 1];     // Hacked players time
bool  g_bIsAimBot[MAXPLAYERS + 1];      // Hacked players aimbot
bool  g_bPreventTaunt[MAXPLAYERS + 1];  // 1-Prevent taunt 0-Don't prevent taunt
public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }

  HookEvent("arena_win_panel", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);

  AddCommandListener(Command_InterceptTaunt, "+taunt");
  AddCommandListener(Command_InterceptTaunt, "taunt");
}

public void OnPluginEnd()
{
  UnhookEvent("arena_win_panel", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
}

public Action Command_InterceptTaunt(int client, const char[] command, int args)
{
  if (IsValidClient(client) && g_bIsHacked[client] && g_bPreventTaunt[client])
  {
    return Plugin_Handled;
  }
  return Plugin_Continue;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;
  if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)  // Dead Ringer spies
    return;
  if (g_bIsHacked[client])
  {
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }
}

public void OnClientDisconnect_Post(int client)
{
  if (g_bIsHacked[client])
  {
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
  if (!IsValidClient(client) || !IsPlayerAlive(client))
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(client);

  if (!boss)
    return Plugin_Continue;

  AbilityData ability = boss.GetAbility("ability_hackplayer");

  if (!ability.IsMyPlugin())
    return Plugin_Continue;

  if (buttons & IN_RELOAD)
  {
    bool   lastman   = ability.GetBool("lastman", true);

    TFTeam bossTeam  = TF2_GetClientTeam(client);                             // get boss team
    TFTeam enemyTeam = (bossTeam == TFTeam_Blue) ? TFTeam_Red : TFTeam_Blue;  // get enemy team

    // prevent last team
    if (GetTeamClientAliveCount(enemyTeam) == 1 && lastman)
    {
      PrintHintText(client, "You are not allowed to hack the last player!");
      return Plugin_Continue;
    }

    float cost   = ability.GetFloat("ragecost", 0.0);
    float charge = GetBossCharge(boss, "0");

    if (charge >= cost)
    {
      int target = TraceToObject(client);
      if (IsValidClient(target) && IsPlayerAlive(target) && !g_bIsHacked[target] && TF2_GetClientTeam(target) == enemyTeam)
      {
        PrintHintText(client, "You hacked %N!", target);
        PrintCenterText(target, "You are hacked!");
        SetBossCharge(boss, "0", charge - cost);
        ConvertToTeam(target, bossTeam);

        g_bIsHacked[target]     = true;
        g_flHackTime[target]    = GetEngineTime() + ability.GetFloat("duration", 10.0);
        g_bIsAimBot[target]     = ability.GetBool("aimbot", false);
        g_bPreventTaunt[target] = ability.GetBool("preventtaunt", false);

        SDKHook(target, SDKHook_PreThink, HackPreThink);
      }
    }
    else
    {
      PrintHintText(client, "No enough rage to hack!");
    }
  }
  return Plugin_Continue;
}

public void HackPreThink(int client)
{
  if (g_flHackTime[client] < GetEngineTime())
  {
    if (IsValidClient(client) && IsPlayerAlive(client) && g_bIsHacked[client])
    {
      g_bIsHacked[client]     = false;
      g_flHackTime[client]    = INACTIVE;
      g_bIsAimBot[client]     = false;
      g_bPreventTaunt[client] = false;

      PrintCenterText(client, "You are free!");

      TFTeam team      = TF2_GetClientTeam(client);                         // get boss team
      TFTeam enemyTeam = (team == TFTeam_Blue) ? TFTeam_Red : TFTeam_Blue;  // get enemy team
      // return to original team
      ConvertToTeam(client, enemyTeam);
    }
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    return;
  }

  if (g_bPreventTaunt[client] && TF2_IsPlayerInCondition(client, TFCond_Taunting))
  {
    // Prevent taunt
    TF2_RemoveCondition(client, TFCond_Taunting);
  }

  if (g_bIsAimBot[client])
  {
    int i = GetClosestClient(client);
    if (i == -1)
      return;

    int buttons = GetClientButtons(client);
    if (buttons & IN_ATTACK)
    {
      float clientEye[3], iEye[3], clientAngle[3];
      GetClientEyePosition(client, clientEye);
      GetClientAbsOrigin(i, iEye);
      GetVectorAnglesTwoPoints(clientEye, iEye, clientAngle);
      AnglesNormalize(clientAngle);
      TeleportEntity(client, NULL_VECTOR, clientAngle, NULL_VECTOR);
    }
  }
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

public int TraceToObject(int client)
{
  float vecClientEyePos[3], vecClientEyeAng[3];
  GetClientEyePosition(client, vecClientEyePos);
  GetClientEyeAngles(client, vecClientEyeAng);

  Handle trace  = TR_TraceRayFilterEx(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayGrab, client);

  int    entity = -1;
  if (TR_DidHit(trace))
  {
    entity = TR_GetEntityIndex(trace);
  }
  delete trace;
  return entity;
}

stock float GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
  static float tmpVec[3];
  tmpVec[0] = vEndPos[0] - vStartPos[0];
  tmpVec[1] = vEndPos[1] - vStartPos[1];
  tmpVec[2] = vEndPos[2] - vStartPos[2];
  GetVectorAngles(tmpVec, vAngles);
}

public void AnglesNormalize(float vAngles[3])
{
  while (vAngles[0] > 89.0)
    vAngles[0] -= 360.0;
  while (vAngles[0] < -89.0)
    vAngles[0] += 360.0;
  while (vAngles[1] > 180.0)
    vAngles[1] -= 360.0;
  while (vAngles[1] < -180.0)
    vAngles[1] += 360.0;
}

public bool CanSeeTarget(int iClient, int iTarget, int iTeam, bool bCheckFOV)
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

public void ConvertToTeam(int client, TFTeam team)
{
  SetEntProp(client, Prop_Send, "m_lifeState", 2);
  TF2_ChangeClientTeam(client, team);
  SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

public float GetBossCharge(ConfigData cfg, const char[] slot)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  return cfg.GetFloat(buffer);
}

public void SetBossCharge(ConfigData cfg, const char[] slot, float amount)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  cfg.SetFloat(buffer, amount);
}

stock int GetTeamClientAliveCount(TFTeam team)
{
  int count = 0;
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == team)  // Fixed variable name
    {
      count++;
    }
  }
  return count;
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