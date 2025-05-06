/*
  "darkrealm_damage_multiplier"
  {
    // melee damage x (1 + (melee_multiplier * kills after X kills))
    // secondary damage x (1 + (secondary_multiplier * kills after X kills))
    // primary damage x (1 + (primary_multiplier * X kills after X kills))

    "melee_multiplier"		"0.05"       // melee damage multiplier
    "melee_kills"		      "0"          // melee will be multiplied after this many kills
    "secondary_multiplier"	"0.05"     // secondary damage multiplier
    "secondary_kills"	    "0"          // secondary will be multiplied after this many kills
    "primary_multiplier"	"0.05"       // primary damage multiplier
    "primary_kills"	      "0"          // primary will be multiplied after this many kills

    "hud"	                "1"          // 0 = no hud, 1 = show hud

    "plugin_name"	"ff2r_darkrealm"	// Plugin Name
  }

  "special_darkrealm"
  {
    // how many slots this ability can have
    "max"		    "3"			// Max slot count of this ability

    // when the boss kills reach the number of kills, the slot will be auto triggered (one time only)
    "kill1"			"5"			  // How many kills need to trigger that slot
    "doslot1"		"20"			// Slot that will be trigger
    "kill2"			"12"			// How many kills need to trigger that slot
    "doslot2"		"21"			// Slot that will be trigger
    "kill3"			"20"			// How many kills need to trigger that slot
    "doslot3"		"22"			// Slot that will be trigger
    "killX"		  "0"			  // How many kills need to trigger that slot
    "doslotX"		"0"			  // Slot that will be trigger

    "plugin_name"	"ff2r_darkrealm"	// Plugin Name
  }

  "rage_darkrealm" // Ability name can use suffixes
  {
    "slot"       "0"
    "kill"       "5"                     // How many kills need to trigger that slot
    "doslot"     ""                      // Slot that will be trigger
    "plugin_name"	"ff2r_darkrealm"	// Plugin Name
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

enum struct PluginState
{
  bool multiplierEnabled;
  bool passiveEnabled;
}
static PluginState g_State;

enum struct PassiveData
{
  int slotNumber;
  int killCount;
}

enum struct MultiplierData
{
  float  meleeMultiplier;
  int    meleeKills;
  float  secondaryMultiplier;
  int    secondaryKills;
  float  primaryMultiplier;
  int    primaryKills;
  Handle hud;
}

ArrayList g_MultiplierData[MAXPLAYERS + 1];
ArrayList g_PassiveData[MAXPLAYERS + 1];

// kill count for each player
int       Killcount[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = "[FF2R] Dark Realms Erandicator Abilities",
  author      = "Zell",
  description = "related to kill count",
  version     = "1.1.0",
  url         = ""
};

public void OnPluginStart()
{
  // hook events
  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);

  // Initialize arrays for all possible players
  for (int client = 0; client <= MaxClients; client++)
  {
    g_PassiveData[client]    = new ArrayList(sizeof(PassiveData));
    g_MultiplierData[client] = new ArrayList(sizeof(MultiplierData));
  }

  g_State.passiveEnabled    = false;
  g_State.multiplierEnabled = false;
}

public void OnPluginEnd()
{
  // unhook events
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);

  // Clean up arrays
  for (int client = 0; client <= MaxClients; client++)
  {
    delete g_PassiveData[client];
    delete g_MultiplierData[client];
  }

  g_State.passiveEnabled    = false;
  g_State.multiplierEnabled = false;
}

// if player is joining the server we need to sdk hook if the boss have damage multiplier ability
public void OnClientPutInServer(int client)
{
  if (!IsValidClient(client, false))
    return;

  if (g_State.multiplierEnabled)
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
		// reset kill count
		Killcount[client] = 0;

    // Clear existing data
    g_PassiveData[client].Clear();
    g_MultiplierData[client].Clear();

    AbilityData specialAbility    = cfg.GetAbility("special_darkrealm");
    AbilityData multiplierAbility = cfg.GetAbility("darkrealm_damage_multiplier");

    if (specialAbility.IsMyPlugin())
    {
      g_State.passiveEnabled = true;
      int max                = specialAbility.GetInt("max", 0);
      for (int i = 1; i <= max; i++)
      {
        char ability_name[64];
        Format(ability_name, sizeof(ability_name), "doslot%i", i);
        int slotNum = specialAbility.GetInt(ability_name, -2);
        if (slotNum != -2)
        {
          PassiveData data;
          data.slotNumber = slotNum;
          data.killCount  = specialAbility.GetInt("kill%i", i, 0);
          g_PassiveData[client].PushArray(data);
        }
      }
    }

    if (multiplierAbility.IsMyPlugin())
    {
      g_State.multiplierEnabled = true;

      MultiplierData data;
      data.meleeMultiplier     = multiplierAbility.GetFloat("melee_multiplier", 0.0);
      data.meleeKills          = multiplierAbility.GetInt("melee_kills", 0);
      data.secondaryMultiplier = multiplierAbility.GetFloat("secondary_multiplier", 0.0);
      data.secondaryKills      = multiplierAbility.GetInt("secondary_kills", 0);
      data.primaryMultiplier   = multiplierAbility.GetFloat("primary_multiplier", 0.0);
      data.primaryKills        = multiplierAbility.GetInt("primary_kills", 0);

      if (multiplierAbility.GetBool("hud", false))
      {
        data.hud = CreateHudSynchronizer();
      }
      else {
        data.hud = INVALID_HANDLE;
      }

      g_MultiplierData[client].PushArray(data);

      // then we need to sdk hook everyone
      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidClient(i, false))
        {
          SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
      }

      // and we need to sdk hook the boss
      SDKHook(client, SDKHook_PreThink, DarkRealmMultiplier_Prethink);
    }
  }
}

// in case the round ends but we have two or more bosses with this ability
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    // reset kill count
    if (IsValidClient(client, false))
    {
      Killcount[client] = 0;
      // unhook ontake damage
      if (g_State.multiplierEnabled)
      {
        SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
      }

      if (g_PassiveData[client].Length > 0)
      {
        g_PassiveData[client].Clear();
      }
      // clear the data of that client if he is a boss
      if (g_MultiplierData[client].Length > 0)
      {
        g_MultiplierData[client].Clear();
        SDKUnhook(client, SDKHook_PreThink, DarkRealmMultiplier_Prethink);
      }
    }
  }

  // then we need to clear the state
  g_State.passiveEnabled    = false;
  g_State.multiplierEnabled = false;
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int victim   = GetClientOfUserId(GetEventInt(event, "userid"));
  int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return Plugin_Continue;

  if (attacker == victim)
    return Plugin_Continue;

  Killcount[attacker]++;

  if (g_State.passiveEnabled)
  {
    // check if the attacker is a boss and has the passive ability
    BossData boss = FF2R_GetBossData(attacker);
    if (boss && boss.GetAbility("special_darkrealm").IsMyPlugin())
    {
      // then we need to check if the kill count is equal to the one in the passive data
      int length = g_PassiveData[attacker].Length;
      for (int i = length - 1; i >= 0; i--)
      {
        PassiveData data;
        g_PassiveData[attacker].GetArray(i, data);
        if (Killcount[attacker] == data.killCount)
        {
          // then trigger the slot
          FF2R_DoBossSlot(attacker, data.slotNumber);
          g_PassiveData[attacker].Erase(i);
        }
      }
    }
  }

  return Plugin_Continue;
}

public void DarkRealmMultiplier_Prethink(int client)
{
  if (!IsValidClient(client, false) || !IsPlayerAlive(client))
    return;

  MultiplierData data;
  g_MultiplierData[client].GetArray(0, data);

  if (data.hud != INVALID_HANDLE)
  {
    // Update the HUD with the current kill count and damage multipliers
    float meleeMultiplier     = SafeCalculateMultiplier(data.meleeMultiplier, Killcount[client], data.meleeKills);
    float secondaryMultiplier = SafeCalculateMultiplier(data.secondaryMultiplier, Killcount[client], data.secondaryKills);
    float primaryMultiplier   = SafeCalculateMultiplier(data.primaryMultiplier, Killcount[client], data.primaryKills);

    SetHudTextParams(-1.0, 0.73, 0.15, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
    ShowSyncHudText(client, data.hud, "Kills: %i | Melee DMG x %.2f | Secondary DMG x %.2f | Primary DMG x %.2f",
                    Killcount[client],
                    meleeMultiplier, secondaryMultiplier, primaryMultiplier);
}
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "darkrealm_rage", false) && cfg.IsMyPlugin())
  {
    if (Killcount[client] >= cfg.GetInt("kill", 0))
    {
      int slotNum = cfg.GetInt("doslot", -2);
      if (slotNum != -2)
      {
        // then trigger the slot
        FF2R_DoBossSlot(client, slotNum);
      }
    }
  }
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  if (attacker == victim)
    return Plugin_Continue;

  if (g_State.multiplierEnabled)
  {
    // check if the attacker is a boss and has the passive ability
    BossData boss = FF2R_GetBossData(attacker);
    if (boss && boss.GetAbility("darkrealm_damage_multiplier").IsMyPlugin())
    {
      MultiplierData data;
      g_MultiplierData[attacker].GetArray(0, data);

      if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
      {
        damage *= SafeCalculateMultiplier(data.meleeMultiplier, Killcount[attacker], data.meleeKills);
      }
      else if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary))
      {
        damage *= SafeCalculateMultiplier(data.secondaryMultiplier, Killcount[attacker], data.secondaryKills);
      }
      else if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary))
      {
        damage *= SafeCalculateMultiplier(data.primaryMultiplier, Killcount[attacker], data.primaryKills);
      }
    }
  }
  return Plugin_Changed;
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

// This function is used to get the slot of a weapon based on its classname.
// credit to batfoxkid
stock int TF2_GetClassnameSlot(const char[] classname, bool econ = false)
{
  if (StrEqual(classname, "player"))
  {
    return -1;
  }
  else if (StrEqual(classname, "tf_weapon_scattergun") || StrEqual(classname, "tf_weapon_handgun_scout_primary") || StrEqual(classname, "tf_weapon_soda_popper") || StrEqual(classname, "tf_weapon_pep_brawler_blaster") || !StrContains(classname, "tf_weapon_rocketlauncher") || StrEqual(classname, "tf_weapon_particle_cannon") || StrEqual(classname, "tf_weapon_flamethrower") || StrEqual(classname, "tf_weapon_grenadelauncher") || StrEqual(classname, "tf_weapon_cannon") || StrEqual(classname, "tf_weapon_minigun") || StrEqual(classname, "tf_weapon_shotgun_primary") || StrEqual(classname, "tf_weapon_sentry_revenge") || StrEqual(classname, "tf_weapon_drg_pomson") || StrEqual(classname, "tf_weapon_shotgun_building_rescue") || StrEqual(classname, "tf_weapon_syringegun_medic") || StrEqual(classname, "tf_weapon_crossbow") || !StrContains(classname, "tf_weapon_sniperrifle") || StrEqual(classname, "tf_weapon_compound_bow"))
  {
    return TFWeaponSlot_Primary;
  }
  else if (!StrContains(classname, "tf_weapon_pistol") || !StrContains(classname, "tf_weapon_lunchbox") || !StrContains(classname, "tf_weapon_jar") || StrEqual(classname, "tf_weapon_handgun_scout_secondary") || StrEqual(classname, "tf_weapon_cleaver") || !StrContains(classname, "tf_weapon_shotgun") || StrEqual(classname, "tf_weapon_buff_item") || StrEqual(classname, "tf_weapon_raygun") || !StrContains(classname, "tf_weapon_flaregun") || !StrContains(classname, "tf_weapon_rocketpack") || !StrContains(classname, "tf_weapon_pipebomblauncher") || StrEqual(classname, "tf_weapon_laser_pointer") || StrEqual(classname, "tf_weapon_mechanical_arm") || StrEqual(classname, "tf_weapon_medigun") || StrEqual(classname, "tf_weapon_smg") || StrEqual(classname, "tf_weapon_charged_smg"))
  {
    return TFWeaponSlot_Secondary;
  }
  else if (!StrContains(classname, "tf_weapon_r"))  // Revolver
  {
    return econ ? TFWeaponSlot_Secondary : TFWeaponSlot_Primary;
  }
  else if (StrEqual(classname, "tf_weapon_sa"))  // Sapper
  {
    return econ ? TFWeaponSlot_Building : TFWeaponSlot_Secondary;
  }
  else if (!StrContains(classname, "tf_weapon_i") || !StrContains(classname, "tf_weapon_pda_engineer_d"))  // Invis & Destory PDA
  {
    return econ ? TFWeaponSlot_Item1 : TFWeaponSlot_Building;
  }
  else if (!StrContains(classname, "tf_weapon_p"))  // Disguise Kit & Build PDA
  {
    return econ ? TFWeaponSlot_PDA : TFWeaponSlot_Grenade;
  }
  else if (!StrContains(classname, "tf_weapon_bu"))  // Builder Box
  {
    return econ ? TFWeaponSlot_Building : TFWeaponSlot_PDA;
  }
  else if (!StrContains(classname, "tf_weapon_sp"))  // Spellbook
  {
    return TFWeaponSlot_Item1;
  }
  return TFWeaponSlot_Melee;
}

float SafeCalculateMultiplier(float baseMultiplier, int kills, int requiredKills)
{
  float multiplier = 1.0 + (baseMultiplier * (kills - requiredKills));
  return (multiplier < 1.0) ? 1.0 : multiplier;
}