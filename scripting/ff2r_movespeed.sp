/*
    "rage_movespeed" // Ability name can use suffixes
    {
      "slot" "0"

      // you can remove this if you want to use the default speed
      "boss_speed" "520.0"     // Boss Move Speed
      "boss_duration" "10"      // Boss Move Speed Duration (seconds)

      // you can remove this if you want to use the default speed
      "ally_speed" "520.0"     // Minion Move Speed
      "ally_duration" "10"      // Minion Move Speed Duration (seconds)

      // you can remove this if you want to use the default speed
      "victim_speed" "520.0"     // Victim Move Speed
      "victim_duration" "10"      // Victim Move Speed Duration (seconds)

      "range" "1000.0"    // Range (in units) to apply the effect (Only affects the victim)

      "plugin_name" "ff2r_movespeed"
    }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <ff2_dynamic_defaults>

#pragma semicolon 1
#pragma newdecls required

float            INACTIVE = 100000000.0;
float            OldSpeed[MAXPLAYERS + 1];
float            NewSpeed[MAXPLAYERS + 1];
float            NewSpeedDuration[MAXPLAYERS + 1];
bool             DSM_SpeedOverride[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name   = "Freak Fortress 2 Rewrite: Move Speed",
  author = "SHADoW NiNE TR3S Rework by Zell",
};

public void OnPluginStart()
{
  // Initialize the NewSpeedDuration array with the inactive value.
  for (int i = 1; i <= MaxClients; i++)
  {
    NewSpeedDuration[i] = INACTIVE;
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client))
    {
      DSM_SpeedOverride[client] = false;
      SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
      SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", OldSpeed[client]);
      NewSpeed[client]         = 0.0;
      NewSpeedDuration[client] = INACTIVE;
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "rage_movespeed", false))  // We want to use subffixes
  {
    // dynamic_speed_management section
    BossData    boss          = FF2R_GetBossData(client);
    AbilityData DSM           = boss.GetAbility("dynamic_speed_management");
    DSM_SpeedOverride[client] = DSM.IsMyPlugin();

    float bossSpeed           = cfg.GetFloat("boss_speed", -1.0);
    float bossDuration        = cfg.GetFloat("boss_duration", -1.0);
    float allySpeed           = cfg.GetFloat("ally_speed", -1.0);
    float allyDuration        = cfg.GetFloat("ally_duration", -1.0);
    float victimSpeed         = cfg.GetFloat("victim_speed", -1.0);
    float victimDuration      = cfg.GetFloat("victim_duration", -1.0);
    float range               = cfg.GetFloat("range", 9999.0);

    float pos[3], pos2[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    for (int i = 1; i < MaxClients; i++)
    {
      if (!IsValidClient(i))
        continue;

      if (!IsPlayerAlive(i))
        continue;

      if (NewSpeedDuration[i] == INACTIVE)
        OldSpeed[i] = GetEntPropFloat(i, Prop_Send, "m_flMaxspeed");

      if (client == i)
      {
        if (bossSpeed != -1 && bossDuration != -1)
        {
          NewSpeed[client] = bossSpeed;
          if (NewSpeedDuration[client] != INACTIVE)
          {
            NewSpeedDuration[client] += bossDuration;
          }
          else
          {
            NewSpeedDuration[client] = GetEngineTime() + bossDuration;
          }

          if (DSM_SpeedOverride[client])
            DSM_SetOverrideSpeed(client, NewSpeed[client]);
        }
      }
      else if (GetClientTeam(i) == GetClientTeam(client))
      {
        if (allySpeed != -1 && allyDuration != -1)
        {
          NewSpeed[i] = allySpeed;
          if (NewSpeedDuration[i] != INACTIVE)
          {
            NewSpeedDuration[i] += allyDuration;
          }
          else
          {
            NewSpeedDuration[i] = GetEngineTime() + allyDuration;
          }
        }
      }
      else {
        if (victimSpeed != -1 && victimDuration != -1)
        {
          GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
          float dist = GetVectorDistance(pos, pos2);

          if (dist < range)
          {
            NewSpeed[i] = victimSpeed;
            if (NewSpeedDuration[i] != INACTIVE)
            {
              NewSpeedDuration[i] += victimDuration;
            }
            else
            {
              NewSpeedDuration[i] = GetEngineTime() + victimDuration;
            }
          }
        }
      }
      SDKHook(i, SDKHook_PreThink, MoveSpeed_Prethink);
    }
  }
}

public void MoveSpeed_Prethink(int client)
{
  if (!DSM_SpeedOverride[client])
  {
    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeed[client]);
  }
  SpeedTick(client, GetEngineTime());
}

public void SpeedTick(int client, float gameTime)
{
  // Move Speed
  if (gameTime >= NewSpeedDuration[client])
  {
    if (DSM_SpeedOverride[client])
    {
      DSM_SpeedOverride[client] = false;
      DSM_SetOverrideSpeed(client, -1.0);
    }
    else {
      SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", OldSpeed[client]);
    }
    NewSpeed[client]         = 0.0;
    NewSpeedDuration[client] = INACTIVE;
    SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
  }
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