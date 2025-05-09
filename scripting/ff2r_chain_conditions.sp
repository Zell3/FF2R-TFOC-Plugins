/*
  "rage_chain_conditions"  // wankers & somecleantrash
  {
    "slot"               "0"               // Slot number for this rage ability
    "rage_duration"      "20.0"            // Total duration of the rage

    "condition_trigger"  "24"              // Condition to check
    "keep_condition"     "1"               // Keep original condition? 0 = remove, 1 = keep

    "condition_apply"    "-4"              // Condition to apply: -1 = ignite, -2 = bleed, -3 = BONK stun, -4 = Explode, otherwise condition id
    "condition_duration" "10.0"            // Duration of the new condition

    "plugin_name"       "ff2r_chain_conditions"
  }
*/

#include <tf2>
#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

public Plugin myinfo =
{
  name    = "Freak Fortress 2: Chain Conditions",
  author  = "Zell",
  version = "1.0.0",
};

float g_flRageDuration[MAXPLAYERS + 1];       // Rage duration for each player
int   g_iConditionTrigger[MAXPLAYERS + 1];    // Condition trigger for each player
int   g_iKeepCondition[MAXPLAYERS + 1];       // Keep original condition for each player
int   g_iConditionApply[MAXPLAYERS + 1];      // Condition to apply for each player
float g_flConditionDuration[MAXPLAYERS + 1];  // Condition duration for each player
float g_flLastApplied[MAXPLAYERS + 1];        // Last time condition was applied for each player
public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_chain_conditions", false) && cfg.IsMyPlugin())
  {
    float rageDuration      = cfg.GetFloat("rage_duration", 10.0);
    int   conditionTrigger  = cfg.GetInt("condition_trigger", -1);
    int   keepCondition     = cfg.GetInt("keep_condition", 0);
    int   conditionApply    = cfg.GetInt("condition_apply", -3);
    float conditionDuration = cfg.GetFloat("condition_duration", 10.0);

    if (conditionTrigger < 0 || conditionApply < -4)
      return;

    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidLivingClient(i) || TF2_GetClientTeam(i) == TF2_GetClientTeam(client))
        continue;

      g_iConditionTrigger[i]   = conditionTrigger;
      g_flRageDuration[i]      = GetEngineTime() + rageDuration;
      g_flConditionDuration[i] = conditionDuration;
      g_iKeepCondition[i]      = keepCondition;
      g_iConditionApply[i]     = conditionApply;

      SDKHook(i, SDKHook_PreThink, ChainPreThink);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && g_flRageDuration[i] != INACTIVE)
    {
      g_flRageDuration[i] = INACTIVE;
      g_flLastApplied[i]  = 0.0;
      SDKUnhook(i, SDKHook_PreThink, ChainPreThink);
    }
  }
}

public void ChainPreThink(int client)
{
  // unhook if not valid client or not alive
  if (!IsValidLivingClient(client))
  {
    g_flRageDuration[client] = INACTIVE;
    g_flLastApplied[client]  = 0.0;
    SDKUnhook(client, SDKHook_PreThink, ChainPreThink);
    return;
  }

  // unhook if not in rage duration or rage is inactive
  if (GetEngineTime() > g_flRageDuration[client] || g_flRageDuration[client] == INACTIVE)
  {
    g_flRageDuration[client] = INACTIVE;
    g_flLastApplied[client]  = 0.0;
    SDKUnhook(client, SDKHook_PreThink, ChainPreThink);
    return;
  }

  int   conditionTrigger  = g_iConditionTrigger[client];
  int   keepCondition     = g_iKeepCondition[client];
  int   conditionApply    = g_iConditionApply[client];
  float conditionDuration = g_flConditionDuration[client];

  // Check if enough time has passed since last application
  if (TF2_IsPlayerInCondition(client, conditionTrigger) && GetEngineTime() >= g_flLastApplied[client])
  {
    if (keepCondition == 0)
      TF2_RemoveCondition(client, conditionTrigger);

    if (conditionApply == -1)
      TF2_IgnitePlayer(client, client, conditionDuration);
    else if (conditionApply == -2)
      TF2_MakeBleed(client, client, conditionDuration);
    else if (conditionApply == -3)
      TF2_StunPlayer(client, conditionDuration, 0.0, TF_STUNFLAGS_NORMALBONK);
    else if (conditionApply == -4)
      SDKHooks_TakeDamage(client, client, client, GetClientHealth(client)*10.0, (DMG_ALWAYSGIB | DMG_CRIT | DMG_BLAST));
    else
      TF2_AddCondition(client, conditionApply, conditionDuration);

    g_flLastApplied[client] = GetEngineTime() + conditionDuration;
  }
}

stock bool IsValidLivingClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
    return false;

  if (!IsClientInGame(client) || !IsClientConnected(client))
    return false;

  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;

  if (!IsPlayerAlive(client))
    return false;

  return true;
}
