/*
  "aimbot"
  {
    "duration"	"8.0"	// time of ambotakam
    "plugin_name"	"ff2r_aimbot"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE       100000000.0

public Plugin myinfo =
{
  name        = "[FF2R] AimBot",
  author      = "Deatharus, Zell",
  description = "MLG SNIPER",
  version     = "1.0.1",
};

float            duration[MAXPLAYERS + 1];  // Time of aimbot

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    duration[client] = INACTIVE;
  }
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (duration[client] != INACTIVE)
    {
      duration[client] = INACTIVE;
    }
    if (IsClientInGame(client) && FF2R_GetBossData(client))
    {
      FF2R_OnBossRemoved(client);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  SDKUnhook(client, SDKHook_PreThink, AimThink);
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "aimbot", false) && cfg.IsMyPlugin())  // We want to use subffixes
  {
    duration[client] = cfg.GetFloat("duration") + GetEngineTime();
    SDKHook(client, SDKHook_PreThink, AimThink);
  }
}

public void AimThink(int client)
{
  if (GetEngineTime() >= duration[client] || duration[client] == INACTIVE)
    SDKUnhook(client, SDKHook_PreThink, AimThink);

  int   i = GetClosestClient(client);
  float clientEye[3], iEye[3], clientAngle[3];
  GetClientEyePosition(client, clientEye);
  GetClientEyePosition(i, iEye);
  GetVectorAnglesTwoPoints(clientEye, iEye, clientAngle);
  AnglesNormalize(clientAngle);
  TeleportEntity(client, NULL_VECTOR, clientAngle, NULL_VECTOR);
}

stock int GetClosestClient(int client)
{
  float fClientLocation[3];
  float fEntityOrigin[3];
  GetClientAbsOrigin(client, fClientLocation);

  int   iClosestEntity   = -1;
  float fClosestDistance = -1.0;
  for (int i = 1; i < MaxClients; i++)
  {
    if (IsValidClient(i) && GetClientTeam(i) != GetClientTeam(client) && IsPlayerAlive(i) && i != client)
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

stock void AnglesNormalize(float vAngles[3])
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

stock void GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
  static float tmpVec[3];
  tmpVec[0] = vEndPos[0] - vStartPos[0];
  tmpVec[1] = vEndPos[1] - vStartPos[1];
  tmpVec[2] = vEndPos[2] - vStartPos[2];
  GetVectorAngles(tmpVec, vAngles);
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