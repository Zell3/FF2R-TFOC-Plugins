/*
"special_blackholerockets"
  {
    "damage"		"30"
    "range"			"200.0"
    "duration"		"3.0"
    "force"			""
    "plugin_name"	"ff2r_bhrocket"
    }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#tryinclude < tf2utils>

#pragma semicolon 1
#pragma newdecls required

float            BH_Radius;
float            BH_Damage;
float            BH_Duration;
float            BH_Force;

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
  name        = "[FF2R] Special Blackholes",
  author      = "noobis port by Zell",
  description = "replace boss rocket by blackhole",
  version     = "1.0.0",
  url         = ""
};

public void OnPluginStart()
{
  /**
   * Most subplugins are late-loaded by ff2r main plugin.
   * So we need to make late-load support for ability.
   *
   * If you don't need late-load support, remove this.
   */
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      OnClientPutInServer(client);

      BossData cfg = FF2R_GetBossData(client);
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);
        FF2R_OnBossEquipped(client, true);
      }
    }
  }
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client) && FF2R_GetBossData(client))
    {
      FF2R_OnBossRemoved(client);
    }
  }
}

public void OnClientPutInServer(int client)
{
}

public void FF2R_OnBossEquipped(int client, bool weapons)
{
}

public void FF2R_OnBossRemoved(int clientIdx)
{
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_blackholerockets");
    if (ability.IsMyPlugin())
    {
      BH_Damage   = ability.GetFloat("damage", 5.0);
      BH_Radius   = ability.GetFloat("range", 800.0);
      BH_Duration = ability.GetFloat("duration", 8.0);
      BH_Force    = ability.GetFloat("force", -200.0);
    }
  }
}

public void OnEntityDestroyed(int entity)
{
  char sClassName[96];
  if (GetEntityClassname(entity, sClassName, sizeof(sClassName)))
  {
    if (!strcmp(sClassName, "tf_projectile_rocket", true))
    {
      int         iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", 0);
      BossData    boss    = FF2R_GetBossData(iClient);
      AbilityData ability = boss.GetAbility("special_blackholerockets");
      if (boss && ability.IsMyPlugin())
      {
        char  sOutput[64];
        int   iParticle;
        float vPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos, 0);
        iParticle = CreateEntityByName("info_particle_system", -1);
        TeleportEntity(iParticle, vPos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(iParticle, "effect_name", "eb_tp_vortex01");
        DispatchSpawn(iParticle);
        ActivateEntity(iParticle);
        AcceptEntityInput(iParticle, "Start", -1, -1, 0);
        Format(sOutput, 64, "OnUser1 !self:Kill::%.1f:1", BH_Duration);
        SetVariantString(sOutput);
        AcceptEntityInput(iParticle, "AddOutput", -1, -1, 0);
        AcceptEntityInput(iParticle, "FireUser1", -1, -1, 0);
        iParticle = CreateEntityByName("info_particle_system", -1);
        TeleportEntity(iParticle, vPos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(iParticle, "effect_name", "raygun_projectile_blue_crit");
        DispatchSpawn(iParticle);
        ActivateEntity(iParticle);
        AcceptEntityInput(iParticle, "Start", -1, -1, 0);
        Format(sOutput, 64, "OnUser1 !self:Kill::%.1f:1", BH_Duration);
        SetVariantString(sOutput);
        AcceptEntityInput(iParticle, "AddOutput", -1, -1, 0);
        AcceptEntityInput(iParticle, "FireUser1", -1, -1, 0);
        iParticle = CreateEntityByName("info_particle_system", -1);
        TeleportEntity(iParticle, vPos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(iParticle, "effect_name", "eyeboss_vortex_blue");
        DispatchSpawn(iParticle);
        ActivateEntity(iParticle);
        AcceptEntityInput(iParticle, "Start", -1, -1, 0);
        Format(sOutput, 64, "OnUser1 !self:Kill::%.1f:1", BH_Duration);
        SetVariantString(sOutput);
        AcceptEntityInput(iParticle, "AddOutput", -1, -1, 0);
        AcceptEntityInput(iParticle, "FireUser1", -1, -1, 0);
        DataPack hPack;
        CreateDataTimer(0.1, Timer_Pull, hPack, TIMER_REPEAT);
        hPack.WriteFloat(BH_Duration + GetEngineTime());
        hPack.WriteFloat(vPos[0]);
        hPack.WriteFloat(vPos[1]);
        hPack.WriteFloat(vPos[2]);
      }
    }
  }
}

public Action Timer_Pull(Handle timer, DataPack hPack)
{
  hPack.Reset();
  if (GetEngineTime() >= hPack.ReadFloat())
  {
    return Plugin_Stop;
  }

  float vPos[3];
  vPos[0] = hPack.ReadFloat();
  vPos[1] = hPack.ReadFloat();
  vPos[2] = hPack.ReadFloat();
  int iAttacker;
  int i = 1;
  while (i <= MaxClients)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i))
    {
      BossData boss = FF2R_GetBossData(i);
      if (!boss)
      {
        float vPos2[3];
        GetClientAbsOrigin(i, vPos2);
        float fDistance = GetVectorDistance(vPos, vPos2, false);
        if (fDistance <= BH_Radius)
        {
          float vVelocity[3];
          MakeVectorFromPoints(vPos, vPos2, vVelocity);
          NormalizeVector(vVelocity, vVelocity);
          ScaleVector(vVelocity, BH_Force);
          TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vVelocity);

          SDKHooks_TakeDamage(i, iAttacker, iAttacker, BH_Damage, _, _, _, _, false);

          if (!IsPlayerAlive(i))
          {
            int iRagdoll = GetEntPropEnt(i, Prop_Send, "m_hRagdoll", 0);
            if (IsValidEntity(iRagdoll))
            {
              AcceptEntityInput(iRagdoll, "Kill", -1, -1, 0);
            }
          }
        }
      }
      else {
        iAttacker = i;
      }
    }
    i++;
  }
  return Plugin_Continue;
}