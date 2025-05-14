/*
  "rage_staring_at_sexiness"
  {
    "distance"	"9999.0"
    "duration"	"5.0"
    "aimlock"   "0"			// 0 = no aimlock, 1 = aimlock (force look at boss), 2 = aimlock (force look at closest boss)
    "speed"		  "0.0"	  // Victim Move Speed (please dont use this with rage movespeed, remove this line if you want to use default movespeed)
    "block"		  "1"			// 0 = no block, 1 = prevent attacking
    "strip"		  "1"			// 0 = no strip, 1 = strip to melee

    "plugin_name"	"ff2r_special_stipper"
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

float g_fDistance[MAXPLAYERS + 1];
float g_fRageTime[MAXPLAYERS + 1];
int   g_iAimLock[MAXPLAYERS + 1];
float g_fSpeed[MAXPLAYERS + 1];
int   g_iBlock[MAXPLAYERS + 1];
int   g_iStrip[MAXPLAYERS + 1];
bool  g_bIsInRange[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Ability for Sexy Hoovy",
  author  = "M7, Zell",
  version = "1.1",
};

public void OnPluginStart()
{
  HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);

  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsInRange[client] = false;
    g_fDistance[client]  = 9999.0;
    g_fRageTime[client]  = INACTIVE;
    g_fSpeed[client]     = -1.0;
    g_iBlock[client]     = 0;
    g_iStrip[client]     = 0;
  }
}

public void OnPluginEnd()
{
  UnhookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);

  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsInRange[client] = false;
    g_fDistance[client]  = 9999.0;
    g_fRageTime[client]  = INACTIVE;
    g_fSpeed[client]     = -1.0;
    g_iBlock[client]     = 0;
    g_iStrip[client]     = 0;
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (cfg.IsMyPlugin() && !StrContains(ability, "rage_staring_at_sexiness", false))
  {
    g_fDistance[client] = cfg.GetFloat("distance", 9999.0);
    g_fRageTime[client] = GetEngineTime() + cfg.GetFloat("duration", 5.0);
    g_iAimLock[client]  = cfg.GetInt("aimlock", 0);
    g_fSpeed[client]    = cfg.GetFloat("speed", -1.0);
    g_iBlock[client]    = cfg.GetInt("block", 1);
    g_iStrip[client]    = cfg.GetInt("strip", 1);

    SDKHook(client, SDKHook_PreThink, SexiThink);
  }
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (g_bIsInRange[client])
    {
      g_bIsInRange[client] = false;
      ClearSexiness(client);
    }
    g_fDistance[client] = 9999.0;
    g_fRageTime[client] = INACTIVE;
    g_fSpeed[client]    = -1.0;
    g_iBlock[client]    = 0;
    g_iStrip[client]    = 0;
  }
}

public void SexiThink(int client)
{
  if (GetEngineTime() > g_fRageTime[client] || g_fRageTime[client] == INACTIVE)
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (g_bIsInRange[i])
      {
        g_bIsInRange[i] = false;
        ClearSexiness(i);
      }
    }
    SDKUnhook(client, SDKHook_PreThink, SexiThink);
    return;
  }

  float pos[3], pos2[3];
  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && GetClientTeam(i) != GetClientTeam(client))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      float dist = GetVectorDistance(pos, pos2);
      if (dist <= g_fDistance[client])
      {
        g_bIsInRange[i] = true;
        ForceSexiness(client, i);
      }
      else
      {
        if (g_bIsInRange[i])
        {
          g_bIsInRange[i] = false;
          ClearSexiness(i);
        }
      }
    }
  }
}

public void ForceSexiness(int client, int target)
{
  if (g_iBlock[client] == 1)
  {
    int weapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
    if (weapon && IsValidEdict(weapon))
    {
      SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 10);
      SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 10);
    }
    SetEntPropFloat(target, Prop_Send, "m_flNextAttack", GetGameTime() + 10);
    SetEntPropFloat(target, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + 10);
  }

  if (g_iStrip[client] == 1)
  {
    int meleeWeapon = GetPlayerWeaponSlot(target, TFWeaponSlot_Melee);
    if (meleeWeapon != -1)  // Check if melee weapon exists first
    {
      TF2_AddCondition(target, TFCond_RestrictToMelee, 999.0);
      int currentWeapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");

      if (currentWeapon != meleeWeapon)
      {
        SetEntPropEnt(target, Prop_Send, "m_hActiveWeapon", meleeWeapon);
      }
    }
  }

  if (g_fSpeed[client] != -1.0)
  {
    float speed = g_fSpeed[client];
    SetEntPropFloat(target, Prop_Data, "m_flMaxspeed", speed);
  }

  if (g_iAimLock[client] != 0)
  {
    int iClosest = client;

    if (g_iAimLock[client] == 2)
      iClosest = GetClosestBoss(target);

    if (iClosest == -1)
      return;

    float flClosestLocation[3], flClientEyePosition[3], flVector[3], flCamAngle[3];
    GetClientEyePosition(target, flClientEyePosition);
    GetClientEyePosition(iClosest, flClosestLocation);
    flClosestLocation[2] -= 2.0;

    MakeVectorFromPoints(flClosestLocation, flClientEyePosition, flVector);
    GetVectorAngles(flVector, flCamAngle);
    flCamAngle[0] *= -1.0;
    flCamAngle[1] += 180.0;

    ClampAngle(flCamAngle);
    TeleportEntity(target, NULL_VECTOR, flCamAngle, NULL_VECTOR);
  }
}

public void ClearSexiness(int target)
{
  int weapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
  if (weapon && IsValidEdict(weapon))
  {
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
    SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime());
  }
  SetEntPropFloat(target, Prop_Send, "m_flNextAttack", GetGameTime());
  SetEntPropFloat(target, Prop_Send, "m_flStealthNextChangeTime", GetGameTime());

  if (TF2_IsPlayerInCondition(target, TFCond_RestrictToMelee))
  {
    TF2_RemoveCondition(target, TFCond_RestrictToMelee);
  }

  float speed = GetDefaultClassMoveSpeed(TF2_GetPlayerClass(target));
  SetEntPropFloat(target, Prop_Data, "m_flMaxspeed", speed);
}

stock int GetClosestBoss(int client)
{
  float fClientLocation[3], fEntityOrigin[3];
  GetClientAbsOrigin(client, fClientLocation);

  int   iClosestEntity   = -1;
  float fClosestDistance = -1.0;
  for (int i = 1; i < MaxClients; i++)
  {
    if (!IsValidLivingClient(i))
      continue;

    if (GetClientTeam(i) != GetClientTeam(client) && i != client)
    {
      GetClientAbsOrigin(i, fEntityOrigin);
      float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
      if ((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
      {
        fClosestDistance = fEntityDistance;
        iClosestEntity   = i;
      }
    }
  }
  return iClosestEntity;
}

stock void ClampAngle(float flAngles[3])
{
  while (flAngles[0] > 89.0)
    flAngles[0] -= 360.0;
  while (flAngles[0] < -89.0)
    flAngles[0] += 360.0;
  while (flAngles[1] > 180.0)
    flAngles[1] -= 360.0;
  while (flAngles[1] < -180.0)
    flAngles[1] += 360.0;
}

stock bool IsValidLivingClient(int clientIdx, bool replaycheck = true)
{
  if (clientIdx <= 0 || clientIdx > MaxClients)
    return false;

  if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
    return false;

  if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
    return false;

  if (!IsPlayerAlive(clientIdx))
    return false;

  return true;
}

stock float GetDefaultClassMoveSpeed(TFClassType class)
{
  switch (class)
  {
    case TFClass_Scout:
      return 400.0;
    case TFClass_Soldier:
      return 240.0;
    case TFClass_Pyro:
      return 300.0;
    case TFClass_DemoMan:
      return 280.0;
    case TFClass_Heavy:
      return 230.0;
    case TFClass_Engineer:
      return 300.0;
    case TFClass_Medic:
      return 320.0;
    case TFClass_Sniper:
      return 300.0;
    case TFClass_Spy:
      return 200.0;
    default:
      return 250.0;
  }
}