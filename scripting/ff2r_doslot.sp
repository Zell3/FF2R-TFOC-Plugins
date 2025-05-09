/*
  "passive_doslot"
  {
    "max"		      "3"			// Max slot count of this ability

    "delay1"		  "3.0"		// Delay before using slot ability
    "doslot1"		  "20"		// Trigger Slot

    "delay2"		  "3.0"		// Delay before using slot ability
    "doslot2"		  "20"		// Trigger Slot

    "delay3"		  "3.0"		// Delay before using slot ability
    "doslot3"		  "20"		// Trigger Slot

    "plugin_name"	"ff2r_doslot"
  }

  "rage_doslot"	// Ability name can use suffixes
  {
    "slot"		    "0"			// Ability Slot
    "delay"		    "3.0"		// Delay before first use
    "doslot"		  "20"		// Trigger Slot

    "plugin_name"	"ff2r_doslot"
  }

  "kill_class_doslot"
  {
    "scout"    "20"
    "soldier"  "21"
    "pyro"     "22"
    "demoman"  "23"
    "heavy"    "24"
    "medic"    "25"
    "sniper"   "26"
    "engineer" "27"
    "spy"      "28"
    "cooldown" "3.0"

    "plugin_name"	"ff2r_doslot"
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

// Create structures to hold slot data
enum struct SlotData
{
  int   slotNumber;
  float timer;
}

enum struct OnKillClassSlotData
{
  TFClassType classType;
  int         slotNumber;
}

// Dynamic arrays to store slot data for each player
ArrayList g_PassiveSlots[MAXPLAYERS + 1];
ArrayList g_RageSlots[MAXPLAYERS + 1];
ArrayList g_OnKillClassSlot[MAXPLAYERS + 1];

// interval
float     g_OnKill_Cooldown[MAXPLAYERS + 1] = { 0.0 };

public Plugin myinfo =
{
  name        = "[FF2R] Do Slot",
  author      = "Zell Copy Batfox code like a pro",
  description = "Do ability slot and have it delay",
  version     = "1.1.0",
  url         = ""
};

public void OnPluginStart()
{
  HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

  // Initialize arrays for all possible players
  for (int client = 0; client <= MAXPLAYERS; client++)
  {
    g_PassiveSlots[client]    = new ArrayList(sizeof(SlotData));
    g_RageSlots[client]       = new ArrayList(sizeof(SlotData));
    g_OnKillClassSlot[client] = new ArrayList(sizeof(OnKillClassSlotData));
    g_OnKill_Cooldown[client] = 0.0;
  }
}

public void OnPluginEnd()
{
  // unhook events
  UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

  // Clean up arrays
  for (int client = 0; client <= MaxClients; client++)
  {
    delete g_PassiveSlots[client];
    delete g_RageSlots[client];
    delete g_OnKillClassSlot[client];
    g_OnKill_Cooldown[client] = 0.0;
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    // Clear existing data
    g_PassiveSlots[client].Clear();
    g_RageSlots[client].Clear();
    g_OnKillClassSlot[client].Clear();
    g_OnKill_Cooldown[client] = 0.0;

    AbilityData ability       = cfg.GetAbility("passive_doslot");
    if (ability.IsMyPlugin())
    {
      int max = ability.GetInt("max", 0);

      for (int i = 1; i <= max; i++)
      {
        char ability_name[64];

        Format(ability_name, sizeof(ability_name), "doslot%i", i);
        int slotNum = ability.GetInt(ability_name, -2);

        if (slotNum != -2)
        {
          Format(ability_name, sizeof(ability_name), "delay%i", i);
          float    delay = ability.GetFloat(ability_name);

          SlotData data;
          data.slotNumber = slotNum;
          data.timer      = GetEngineTime() + delay;

          g_PassiveSlots[client].PushArray(data);
        }
      }
    }

    // Handle on-kill class slots
    ability = cfg.GetAbility("kill_class_doslot");
    if (ability.IsMyPlugin())
    {
      for (int i = 1; i <= 9; i++)  // 1-9 because 0 is unknown class
      {
        char class[32];
        GetClassStringByIndex(i, class, sizeof(class));

          int slotNum = ability.GetInt(class, -2);
        if (slotNum != -2)
        {
          OnKillClassSlotData data;
          data.classType  = view_as<TFClassType>(i);
          data.slotNumber = slotNum;

          g_OnKillClassSlot[client].PushArray(data);
        }
      }
    }
    SDKHook(client, SDKHook_PreThink, DoSlot_Prethink);
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (FF2R_GetBossData(client))
    {
      g_PassiveSlots[client].Clear();
      g_RageSlots[client].Clear();
      g_OnKillClassSlot[client].Clear();
      g_OnKill_Cooldown[client] = 0.0;
      SDKUnhook(client, SDKHook_PreThink, DoSlot_Prethink);
      break;
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_doslot", false) && cfg.IsMyPlugin())
  {
    SlotData data;
    data.slotNumber = cfg.GetInt("doslot", 0);
    data.timer      = GetEngineTime() + cfg.GetFloat("delay", 0.0);

    g_RageSlots[client].PushArray(data);
  }
}

public void DoSlot_Prethink(int client)
{
  DoSlot(client, GetEngineTime());
}

public void DoSlot(int client, float gameTime)
{
  // Handle passive slots
  int passiveCount = g_PassiveSlots[client].Length;
  for (int i = passiveCount - 1; i >= 0; i--)
  {
    SlotData data;
    g_PassiveSlots[client].GetArray(i, data);

    if (data.timer <= gameTime)
    {
      FF2R_DoBossSlot(client, data.slotNumber, data.slotNumber);
      g_PassiveSlots[client].Erase(i);
    }
  }

  // Handle rage slots
  int rageCount = g_RageSlots[client].Length;
  for (int i = rageCount - 1; i >= 0; i--)
  {
    SlotData data;
    g_RageSlots[client].GetArray(i, data);

    if (data.timer <= gameTime)
    {
      FF2R_DoBossSlot(client, data.slotNumber, data.slotNumber);
      g_RageSlots[client].Erase(i);
    }
  }
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int victim   = GetClientOfUserId(GetEventInt(event, "userid"));
  int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return Plugin_Continue;

  if (attacker == victim)
    return Plugin_Continue;

  if (!IsValidClient(victim) || !IsValidClient(attacker))
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(attacker);
  if (!boss)
    return Plugin_Continue;

  AbilityData ability = boss.GetAbility("kill_class_doslot");
  if (!ability.IsMyPlugin())
    return Plugin_Continue;

  // then we need to check if the kill class equal to the one in the on kill class data
  int length = g_OnKillClassSlot[attacker].Length;
  for (int i = length - 1; i >= 0; i--)
  {
    OnKillClassSlotData data;
    g_OnKillClassSlot[attacker].GetArray(i, data);
    if (data.classType == TF2_GetPlayerClass(victim))
    {
      // Set the cooldown to the current time + the cooldown value
      if (GetEngineTime() > g_OnKill_Cooldown[attacker])
      {
        g_OnKill_Cooldown[attacker] = GetEngineTime() + boss.GetAbility("kill_class_doslot").GetFloat("cooldown", 0.0);
        // then trigger the slot
        FF2R_DoBossSlot(attacker, data.slotNumber);
      }
    }
  }

  return Plugin_Continue;
}

// Change the function to use a char array parameter instead of returning a string directly
stock void GetClassStringByIndex(int index, char[] buffer, int maxlen)
{
  switch (index)
  {
    case 1:
      strcopy(buffer, maxlen, "scout");
    case 2:
      strcopy(buffer, maxlen, "sniper");
    case 3:
      strcopy(buffer, maxlen, "soldier");
    case 4:
      strcopy(buffer, maxlen, "demoman");
    case 5:
      strcopy(buffer, maxlen, "medic");
    case 6:
      strcopy(buffer, maxlen, "heavy");
    case 7:
      strcopy(buffer, maxlen, "pyro");
    case 8:
      strcopy(buffer, maxlen, "spy");
    case 9:
      strcopy(buffer, maxlen, "engineer");
    default:
      strcopy(buffer, maxlen, "unknown");
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