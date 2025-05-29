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

  "rage_charge_doslot"      // Ability name can use suffixes
  {
    "slot"		            "0"			  // Ability Slot
    "doslot"		          "20"		  // Trigger Slot (example: 20 is ion cannon)
    "amount"		          "3"	      // Amount of charge to use
    "cooldown"		        "3.0"		  // Cooldown time before using the ability again
    "bottonmode"	        "1"		    // ActivationKey  (1 = RightClick. 2 = ReloadButton. 3 = Special)
    "hud_message"	        "%d Ion Cannon Left Press Reload to use"		// Show HUD message when ability is used
    "hud_message_color"	  "0 ; 255 ; 0"	// HUD message color (RGB format)
    "hud_cooldown_color"	"255 ; 0 ; 0"	// HUD cooldown color (RGB format)
    "plugin_name"         "ff2r_doslot"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <tf2>
#include <tf2_stocks>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

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

enum struct ChargeSlotData
{
  int   charges;
  float nextUse;
  int   slotNumber;
  int   buttonMode;
  char  hudMessage[128];
  int   hudColor[3];
  int   cooldownColor[3];
  float cooldown;
}

// Dynamic arrays to store slot data for each player
ArrayList   g_PassiveSlots[MAXPLAYERS + 1];
ArrayList   g_RageSlots[MAXPLAYERS + 1];
ArrayList   g_OnKillClassSlot[MAXPLAYERS + 1];
ArrayList   g_ChargeSlots[MAXPLAYERS + 1];

// interval
bool        g_HasChargeAbility[MAXPLAYERS + 1];
float       g_OnKill_Cooldown[MAXPLAYERS + 1];

// HUD synchronizer handle
Handle      g_ChargeHUD[MAXPLAYERS + 1][3];  // Support up to 3 charge slots per player

float       g_NextHudUpdate[MAXPLAYERS + 1];
const float HUD_UPDATE_INTERVAL = 0.1;  // Update HUD every 0.1 seconds

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
    g_ChargeSlots[client]     = new ArrayList(sizeof(ChargeSlotData));
    g_OnKillClassSlot[client] = new ArrayList(sizeof(OnKillClassSlotData));
    g_OnKill_Cooldown[client] = 0.0;

    // Create HUD synchronizers for each slot
    for (int slot = 0; slot < 3; slot++)
    {
      g_ChargeHUD[client][slot] = CreateHudSynchronizer();
    }
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
    delete g_ChargeSlots[client];
    delete g_OnKillClassSlot[client];
    g_OnKill_Cooldown[client] = 0.0;

    // Close HUD synchronizer handles
    for (int slot = 0; slot < 3; slot++)
    {
      CloseHandle(g_ChargeHUD[client][slot]);
    }
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
    g_ChargeSlots[client].Clear();
    g_HasChargeAbility[client] = false;
    AbilityData ability        = cfg.GetAbility("passive_doslot");
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
      g_ChargeSlots[client].Clear();
      g_OnKillClassSlot[client].Clear();
      g_OnKill_Cooldown[client]  = 0.0;
      g_HasChargeAbility[client] = false;
      SDKUnhook(client, SDKHook_PreThink, DoSlot_Prethink);
      break;
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_doslot", false))
  {
    SlotData data;
    data.slotNumber = cfg.GetInt("doslot", 0);
    data.timer      = GetEngineTime() + cfg.GetFloat("delay", 0.0);

    g_RageSlots[client].PushArray(data);
  }
  else if (!StrContains(ability, "rage_charge_doslot", false))
  {
    ChargeSlotData data;
    data.charges    = cfg.GetInt("amount", 3);
    data.slotNumber = cfg.GetInt("doslot", 20);
    data.buttonMode = cfg.GetInt("bottonmode", 1);
    data.cooldown   = cfg.GetFloat("cooldown", 3.0);
    data.nextUse    = 0.0;

    cfg.GetString("hud_message", data.hudMessage, sizeof(data.hudMessage), "");

    char colorStr[32];
    cfg.GetString("hud_message_color", colorStr, sizeof(colorStr), "0 255 0");
    ParseColorString(colorStr, data.hudColor);

    cfg.GetString("hud_cooldown_color", colorStr, sizeof(colorStr), "255 0 0");
    ParseColorString(colorStr, data.cooldownColor);

    g_ChargeSlots[client].PushArray(data);
    g_HasChargeAbility[client] = true;
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

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
  if (!g_HasChargeAbility[client] || !IsValidClient(client) || !IsPlayerAlive(client))
    return Plugin_Continue;

  if (g_ChargeSlots[client].Length == 0)
  {
    g_HasChargeAbility[client] = false;
    return Plugin_Continue;
  }

  ChargeSlotData data;
  float          currentTime = GetEngineTime();

  // Handle button inputs for each charge slot
  for (int i = g_ChargeSlots[client].Length - 1; i >= 0; i--)
  {
    g_ChargeSlots[client].GetArray(i, data);

    // Skip if on cooldown
    if (data.nextUse > currentTime)
      continue;

    // Check button press based on button mode
    bool buttonPressed = false;
    switch (data.buttonMode)
    {
      case 1: buttonPressed = (buttons & IN_ATTACK2) != 0;  // Right click
      case 2: buttonPressed = (buttons & IN_RELOAD) != 0;   // Reload
      case 3: buttonPressed = (buttons & IN_ATTACK3) != 0;  // Special attack
    }

    if (buttonPressed && data.charges > 0)
    {
      // Use the ability
      FF2R_DoBossSlot(client, data.slotNumber);

      // Update charges and cooldown
      data.charges--;
      data.nextUse = currentTime + data.cooldown;
      g_ChargeSlots[client].SetArray(i, data);
    }
  }

  return Plugin_Continue;
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

stock void ParseColorString(const char[] colorStr, int color[3])
{
  char splits[3][8];
  ExplodeString(colorStr, " ; ", splits, sizeof(splits), sizeof(splits[]));

  for (int i = 0; i < 3; i++)
  {
    color[i] = StringToInt(splits[i]);
  }
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

public void OnGameFrame()
{
  float currentTime = GetEngineTime();

  for (int client = 1; client <= MaxClients; client++)
  {
    if (!g_HasChargeAbility[client] || !IsValidClient(client) || !IsPlayerAlive(client))
      continue;

    // Only update HUD at specified intervals
    if (currentTime < g_NextHudUpdate[client])
      continue;

    g_NextHudUpdate[client] = currentTime + HUD_UPDATE_INTERVAL;

    // Update HUD for each charge slot
    for (int i = g_ChargeSlots[client].Length - 1; i >= 0; i--)
    {
      ChargeSlotData data;
      g_ChargeSlots[client].GetArray(i, data);

      // Check if the slot has no charges left and cooldown is done
      if (data.charges <= 0 && data.nextUse <= currentTime)
      {
        g_ChargeSlots[client].Erase(i);
        continue;
      }

      // Position HUD messages vertically based on slot index
      float yPos = 0.21 + (0.03 * i);

      if (data.hudMessage[0] != '\0')
      {
        // Only show HUD if we have charges or are on cooldown
        if (data.charges > 0)
        {
          // Set color based on whether ability is on cooldown
          SetHudTextParams(-1.0, yPos, HUD_UPDATE_INTERVAL + 0.1,
                           data.nextUse > currentTime ? data.cooldownColor[0] : data.hudColor[0],
                           data.nextUse > currentTime ? data.cooldownColor[1] : data.hudColor[1],
                           data.nextUse > currentTime ? data.cooldownColor[2] : data.hudColor[2],
                           255, 0, 0.0, 0.0, 0.0);

          // Show cooldown timer if ability is on cooldown
          if (data.nextUse > currentTime && data.charges > 0)
          {
            char formattedMessage[128];
            Format(formattedMessage, sizeof(formattedMessage), data.hudMessage, data.charges);
            ShowSyncHudText(client, g_ChargeHUD[client][i], "%s (%.1fs)", formattedMessage, data.nextUse - currentTime);
          }
          else if (data.charges > 0)
          {
            ShowSyncHudText(client, g_ChargeHUD[client][i], data.hudMessage, data.charges);
          }
        }
      }
    }
  }
}