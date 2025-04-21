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

  "sound_movespeed_start" // when move speed is start
  {
    "saxton_hale/miku/miku_awesome.mp3"  ""
    "saxton_hale/miku/miku_come_here.mp3"  ""
  }

  "sound_movespeed_finish" // when move speed is finish
  {
    "saxton_hale/miku/miku_awesome.mp3" ""
    "saxton_hale/miku/miku_come_here.mp3" ""
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

// Movespeed
float            OldSpeed[MAXPLAYERS + 1];
float            NewSpeed[MAXPLAYERS + 1];
float            NewSpeedDuration[MAXPLAYERS + 1];
bool             DSM_SpeedOverride[MAXPLAYERS + 1];
#define INACTIVE 100000000.0

public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Move Speed",
  author  = "SHADoW NiNE TR3S, Zell",
  version = "1.4.0",
};

public void OnPluginStart()
{
  HookEvent("arena_win_panel", Event_RoundEnd);
  HookEvent("teamplay_round_win", Event_RoundEnd);
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      BossData cfg = FF2R_GetBossData(client);  // Get boss config (known as boss index) from player
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);
      }
    }
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (FF2R_GetBossData(client))
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i))
      {
        DSM_SpeedOverride[i] = false;
        NewSpeed[i]         = 0.0;
        NewSpeedDuration[i] = INACTIVE;
      }
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client))
    {
      DSM_SpeedOverride[client] = false;
      SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
      NewSpeed[client]         = 0.0;
      NewSpeedDuration[client] = INACTIVE;
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_movespeed", false))
  {
    float bossSpeed         = cfg.GetFloat("boss_speed", -1.0);
    float bossDuration      = cfg.GetFloat("boss_duration", -1.0);
    float allySpeed         = cfg.GetFloat("ally_speed", -1.0);
    float allyDuration      = cfg.GetFloat("ally_duration", -1.0);
    float victimSpeed       = cfg.GetFloat("victim_speed", -1.0);
    float victimDuration    = cfg.GetFloat("victim_duration", -1.0);
    float range             = cfg.GetFloat("range", 9999.0);

    bool  isBossAfflicted   = bossSpeed >= 0.0 && bossDuration >= 0.0;
    bool  isAllyAfflicted   = allySpeed >= 0.0 && allyDuration >= 0.0;
    bool  isVictimAfflicted = victimSpeed >= 0.0 && victimDuration >= 0.0;

    char  buffer[PLATFORM_MAX_PATH];
    FF2R_EmitBossSoundToAll("sound_movespeed_start", client, buffer, client, _, SNDLEVEL_TRAFFIC);

    // boss distance calculation
    float pos[3], pos2[3], dist;
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    // this is for boss move speed
    if (isBossAfflicted)  // this is Boss
    {
      if (NewSpeedDuration[client] == INACTIVE)
      {
        NewSpeed[client]         = bossSpeed;
        NewSpeedDuration[client] = GetEngineTime() + bossDuration;
      }
      else
      {
        NewSpeedDuration[client] += bossDuration;  // Add time if rage is active?
      }

      // this is for dynamic_speed_management
      BossData    boss          = FF2R_GetBossData(client);
      AbilityData DSM           = boss.GetAbility("dynamic_speed_management");
      DSM_SpeedOverride[client] = DSM.IsMyPlugin();
      if (DSM_SpeedOverride[client])
      {
        DSM_SetOverrideSpeed(client, NewSpeed[client]);
      }
      else
      {
        OldSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
      }

      SDKHook(client, SDKHook_PreThink, MoveSpeed_Prethink);
    }

    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidClient(i))
        continue;

			if (i == client)
				continue;  // Skip the client (boss) itself

      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      dist = GetVectorDistance(pos, pos2);

      if (isAllyAfflicted && GetClientTeam(client) == GetClientTeam(i))  // this is Ally
      {
        if (NewSpeedDuration[i] == INACTIVE)
        {
          NewSpeed[i]         = allySpeed;
          NewSpeedDuration[i] = GetEngineTime() + allyDuration;
        }
        else
        {
          NewSpeedDuration[i] += allyDuration;  // Add time if rage is active?
        }
				OldSpeed[i] = GetEntPropFloat(i, Prop_Send, "m_flMaxspeed");
        SDKHook(i, SDKHook_PreThink, MoveSpeed_Prethink);
      }
      else if (dist < range && isVictimAfflicted && GetClientTeam(client) != GetClientTeam(i))  // this is Victim
      {
        if (NewSpeedDuration[i] == INACTIVE)
        {
          NewSpeed[i]         = victimSpeed;
          NewSpeedDuration[i] = GetEngineTime() + victimDuration;
        }
        else
        {
          NewSpeedDuration[i] += victimDuration;  // Add time if rage is active?
        }
				OldSpeed[i] = GetEntPropFloat(i, Prop_Send, "m_flMaxspeed");
        SDKHook(i, SDKHook_PreThink, MoveSpeed_Prethink);
      }
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
  if (gameTime >= NewSpeedDuration[client])
  {
    if (DSM_SpeedOverride[client])
    {
      DSM_SpeedOverride[client] = false;
      DSM_SetOverrideSpeed(client, -1.0);
    }

    if (FF2R_GetBossData(client))
    {
      char buffer[PLATFORM_MAX_PATH];
      FF2R_EmitBossSoundToAll("sound_movespeed_finish", client, buffer, client, _, SNDLEVEL_TRAFFIC);
    }

    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", OldSpeed[client]);
    NewSpeed[client]         = 0.0;
    NewSpeedDuration[client] = INACTIVE;
    OldSpeed[client]         = 0.0;
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