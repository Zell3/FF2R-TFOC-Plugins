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

#pragma semicolon 1
#pragma newdecls required

bool             IsRound;

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
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      BossData cfg = FF2R_GetBossData(client);
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);
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

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("passive_doslot");
    if (ability && ability.IsMyPlugin())
    {
      int max = ability.GetInt("max", 0);
      IsRound = true;
      for (int i = 1; i <= max; i++)
      {
        char ability_name[64];

        // delay times are 0.0, 1.0, 2.0, 3.0, etc.
        Format(ability_name, sizeof(ability_name), "delay%i", i);
        if (ability.GetFloat(ability_name, 0.0) < 0)
          continue;
        float delay = ability.GetFloat(ability_name, 0.0);
        // PrintToServer("[delay%i] delay: %f", i, delay);

        // Check if the slot is valid
        Format(ability_name, sizeof(ability_name), "doslot%i", i);
        if (ability.GetInt(ability_name, -2) == -2)
          continue;
        int      slot = ability.GetInt(ability_name, -2);
        // PrintToServer("[slot%i] slot: %f", i, slot);

        DataPack pack;
        CreateDataTimer(delay, DoSlot, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(client);
        pack.WriteCell(slot);
      }
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  IsRound = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_doslot", false) && cfg.IsMyPlugin())
  {
    IsRound = true;
    DataPack pack;
    CreateDataTimer(cfg.GetFloat("delay", 0.0), DoSlot, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);
    pack.WriteCell(cfg.GetInt("doslot"));
  }
}

public Action DoSlot(Handle timer, DataPack pack)
{
  if (!IsRound)
    return Plugin_Stop;
  pack.Reset();
  int client = pack.ReadCell();
  int slot   = pack.ReadCell();

  FF2R_DoBossSlot(client, slot);

  return Plugin_Continue;
}