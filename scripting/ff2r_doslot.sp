/*

  "passive_doslot"
  {
    "max"		    "3"			// Max slot count of this ability

    "delay1"		    "3.0"		// Delay before using slot ability
    "doslot1"		"20"		// Trigger Slot

    "delay2"		    "3.0"		// Delay before using slot ability
    "doslot2"		"20"		// Trigger Slot

    "delay3"		    "3.0"		// Delay before using slot ability
    "doslot3"		"20"		// Trigger Slot

    "plugin_name"	"ff2r_doslot"	// Plugin Name
  }

  "rage_doslot"	// Ability name can use suffixes
  {
    "slot"		    "0"			// Ability Slot
    "delay"		    "3.0"		// Delay before first use
    "doslot"		"20"		// Trigger Slot

    "plugin_name"	"ff2r_doslot"	// Plugin Name
  }

  "doslot_on_killclass"
  {
    "scout" "20"
    "soldier" "21"
    "pyro" "22"
    "demoman" "23"
    "interval" "3.0"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

// Create structures to hold slot data
enum struct SlotData
{
  int   slotNumber;
  float timer;
}

// Dynamic arrays to store slot data for each player
ArrayList g_PassiveSlots[MAXPLAYERS + 1];
ArrayList g_RageSlots[MAXPLAYERS + 1];

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
  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

  // Initialize arrays for all possible players
  for (int client = 0; client <= MAXPLAYERS; client++)
  {
    g_PassiveSlots[client] = new ArrayList(sizeof(SlotData));
    g_RageSlots[client]    = new ArrayList(sizeof(SlotData));
  }
}

public void OnPluginEnd()
{
  // unhook events
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

  // Clean up arrays
  for (int client = 0; client <= MaxClients; client++)
  {
    delete g_PassiveSlots[client];
    delete g_RageSlots[client];
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    // Clear existing data
    g_PassiveSlots[client].Clear();
    g_RageSlots[client].Clear();

    AbilityData ability = cfg.GetAbility("passive_doslot");
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
    SDKHook(client, SDKHook_PreThink, DoSlot_Prethink);
  }
}

// public void FF2R_OnBossRemoved(int client)
// {
//   g_PassiveSlots[client].Clear();
//   g_RageSlots[client].Clear();
//   SDKUnhook(client, SDKHook_PreThink, DoSlot_Prethink);
// }

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (FF2R_GetBossData(client))
    {
      g_PassiveSlots[client].Clear();
      g_RageSlots[client].Clear();
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