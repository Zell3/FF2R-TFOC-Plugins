/*
  "rage_chain_conditions"
  {
    "slot"               "0"
    "rage_duration"      "20.0"

    "conditions"
    {
      "0"  // First condition set
      {
        "trigger"    "24"
        "keep"       "1"
        "apply"      "-4"
        "duration"   "10.0"
      }
      "1"  // Second condition set
      {
        "trigger"    "32"
        "keep"       "0"
        "apply"      "-1"
        "duration"   "5.0"
      }
      // Add more as needed...
    }

    "plugin_name"       "ff2r_chain_conditions"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE       100000000.0
#define MAX_CONDITIONS 8

public Plugin myinfo =
{
  name    = "Freak Fortress 2: Chain Conditions",
  author  = "Zell",
  version = "1.1.0",
};

enum struct ConditionSet
{
  int   trigger;
  int   keep;
  int   apply;
  float duration;
  float lastApplied;
}

float     g_flRageDuration[MAXPLAYERS + 1];
ArrayList g_ConditionSets[MAXPLAYERS + 1];

public void OnPluginStart()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i))
    {
      g_ConditionSets[i] = new ArrayList(sizeof(ConditionSet));
    }
  }
}

public void OnClientConnected(int client)
{
  g_ConditionSets[client] = new ArrayList(sizeof(ConditionSet));
}

public void OnClientDisconnect(int client)
{
  delete g_ConditionSets[client];
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_chain_conditions", false) && cfg.IsMyPlugin())
  {
    float     rageDuration = cfg.GetFloat("rage_duration", 10.0);
    ConfigMap conditions   = cfg.GetSection("conditions");

    if (conditions == null)
      return;

    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidLivingClient(i) || TF2_GetClientTeam(i) == TF2_GetClientTeam(client))
        continue;

      g_flRageDuration[i] = GetEngineTime() + rageDuration;
      g_ConditionSets[i].Clear();

      char index[8];
      int  conditionIndex = 0;

      while (conditionIndex < MAX_CONDITIONS)
      {
        IntToString(conditionIndex, index, sizeof(index));
        ConfigMap conditionConfig = conditions.GetSection(index);

        if (conditionConfig == null)
          break;

        ConditionSet condition;
        int          defaultVal;
        float        defaultFloat;

        conditionConfig.GetInt("trigger", defaultVal);
        condition.trigger = defaultVal;

        conditionConfig.GetInt("keep", defaultVal);
        condition.keep = defaultVal;

        conditionConfig.GetInt("apply", defaultVal);
        condition.apply = defaultVal;

        conditionConfig.GetFloat("duration", defaultFloat);
        condition.duration    = defaultFloat;
        condition.lastApplied = 0.0;

        if (condition.trigger >= 0 && condition.apply >= -4)
        {
          g_ConditionSets[i].PushArray(condition);
        }

        conditionIndex++;
      }

      if (g_ConditionSets[i].Length > 0)
      {
        SDKHook(i, SDKHook_PreThink, ChainPreThink);
      }
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
      g_ConditionSets[i].Clear();
      SDKUnhook(i, SDKHook_PreThink, ChainPreThink);
    }
  }
}

public void ChainPreThink(int client)
{
  if (GetEngineTime() > g_flRageDuration[client] || g_flRageDuration[client] == INACTIVE)
  {
    g_flRageDuration[client] = INACTIVE;
    g_ConditionSets[client].Clear();
    SDKUnhook(client, SDKHook_PreThink, ChainPreThink);
    return;
  }

  if (!IsValidLivingClient(client))
    return;

  int size = g_ConditionSets[client].Length;
  for (int i = 0; i < size; i++)
  {
    ConditionSet condition;
    g_ConditionSets[client].GetArray(i, condition);

    if (TF2_IsPlayerInCondition(client, condition.trigger) && GetEngineTime() >= condition.lastApplied)
    {
      switch (condition.apply)
      {
        case -1: TF2_IgnitePlayer(client, client, condition.duration);
        case -2: TF2_MakeBleed(client, client, condition.duration);
        case -3: TF2_StunPlayer(client, condition.duration, 0.0, TF_STUNFLAGS_NORMALBONK);
        case -4: SDKHooks_TakeDamage(client, client, client, GetClientHealth(client) * 10.0, (DMG_ALWAYSGIB | DMG_CRIT | DMG_BLAST));
        default: TF2_AddCondition(client, condition.apply, condition.duration);
      }

      condition.lastApplied = GetEngineTime() + condition.duration;
      g_ConditionSets[client].SetArray(i, condition);
    }

    if (TF2_IsPlayerInCondition(client, condition.trigger) && condition.keep == 0)
    {
      TF2_RemoveCondition(client, condition.trigger);
    }
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
