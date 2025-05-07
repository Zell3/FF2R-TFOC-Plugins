// ok  so we gonna make a plugin that allows us to steal weapons from other players when hit
// yeah this is epic scout ability (old version but more flexible)
/*
"rage_steal_next_weapon"
{
  "duration"            "5.0"         // duration of rage before it becomes wasted, 0.0 is no limit
  "lifetime"            "15.0"        // lifetime of acquired weapon. set to 0.0 to keep it forever. (or until replaced)
  "suppression"         "15.0"        // slot suppression duration for the victim

  "scout_classname"     ""            // classname of the weapon to be stolen
  "scout_attributes"    ""            // attributes of the weapon to be stolen
  "scout_index"				  ""						// Weapon index
  "scout_level"				  ""						// Weapon level
  "scout_quality"			  ""						// Weapon quality
  "scout_rank"				  ""						// Weapon strange rank
  "scout_show"				  ""						// Weapon visibility

  "soldier_classname"   ""            // classname of the weapon to be stolen
  "soldier_attributes"  ""            // attributes of the weapon to be stolen
  "soldier_index"				""					  // Weapon index
  "soldier_level"				""						// Weapon level
  "soldier_quality"			""						// Weapon quality
  "soldier_rank"				""						// Weapon strange rank
  "soldier_show"				""						// Weapon visibility
  "soldier_lifetime"    "15.0"        // lifetime of acquired weapon. set to 0.0 to keep it forever. (or until replaced)
  "soldier_suppression" "15.0"        // slot suppression duration for the victim

  // and so on for all classes
}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH  256

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Steal Next Weapon",
  author      = "Sarysa, Zell",
  description = "Steal the next weapon from a player when you hit them.",
  version     = "1.0.0",
};

// new Float : SNW_StealingUntil[MAX_PLAYERS_ARRAY];                    // internal
// new SNW_WeaponEntRef[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS];            // internal
// new Float : SNW_RemoveWeaponAt[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS];  // internal
// new SNW_SuppressedSlot[MAX_PLAYERS_ARRAY];                           // internal, note that this is used for VICTIMS, not the hale
// new Float : SNW_SlotSuppressedUntil[MAX_PLAYERS_ARRAY];              // internal, note that this is used for VICTIMS, not the hale
// new SNW_Trigger[MAX_PLAYERS_ARRAY];                                  // arg1
// new Float : SNW_StealDuration[MAX_PLAYERS_ARRAY];                    // arg2
// new Float : SNW_WeaponKeepDuration[MAX_PLAYERS_ARRAY];               // arg3
// // arg4 is used at rage time
// new Float : SNW_SlotSuppressionDuration[MAX_PLAYERS_ARRAY];  // arg5
// // args X1 to X8 also only used at rage time, except X6
// new SNW_Slot[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS];  // argX6 (16, 26, 36...96)

enum struct NewWeaponData
{
  char classname[MAX_WEAPON_NAME_LENGTH];
  char attributes[MAX_WEAPON_ARG_LENGTH];
  int  index;
  int  level;
  int  quality;
  int  rank;
  int  show;
}

ArrayList g_NewWeapons[MAXPLAYERS + 1];  // ArrayList to store NewWeapon structs for each player

enum TFClassType
{
  TFClass_Unknown = 0,
  TFClass_Scout,
  TFClass_Sniper,
  TFClass_Soldier,
  TFClass_DemoMan,
  TFClass_Medic,
  TFClass_Heavy,
  TFClass_Pyro,
  TFClass_Spy,
  TFClass_Engineer
};

public void OnPluginStart()
{
  // Initialize arrays for all possible players
  for (int client = 0; client <= MaxClients; client++)
  {
    g_NewWeapons[client] = new ArrayList(sizeof(NewWeapon));
  }
}

public void OnPluginEnd()
{
  // Clean up arrays
  for (int client = 0; client <= MaxClients; client++)
  {
    delete g_NewWeapons[client];
  }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "rage_steal_next_weapon", false))  // We want to use subffixes
  {
    g_NewWeapons[client].Clear();

    for (int i = 1; i < 9; i++)
    {
      char class[64] class = GetClassStringByIndex(i);

      NewWeaponData weapon;

      weapon.classname[0]  = '\0';  // Initialize the classname to an empty string
      weapon.attributes[0] = '\0';  // Initialize the attributes to an empty string
      weapon.index         = 0;     // Initialize the index to 0
      weapon.level         = 0;     // Initialize the level to 0
      weapon.quality       = 0;     // Initialize the quality to 0
      weapon.rank          = 0;     // Initialize the rank to 0
      weapon.show          = 0;     // Initialize the show to 0

      Format(abilityparam, sizeof(abilityparam), "%s_classname", class);
      cfg.GetString(abilityparam, weapon.classname, sizeof(weapon.classname));
      if (weapon.classname[0] == '\0')
      {
        continue;  // Skip if no classname is provided
      }

      int slot = TF2_GetClassnameSlot(weapon.classname);  // Get the slot for the weapon

      if (lifetime <= 0.0)  // remove the weapon forever
      {
        if (slot >= 0 && slot < 6)
          TF2_RemoveWeaponSlot(client, slot);
      }

      Format(abilityparam, sizeof(abilityparam), "%s_attributes", class);
      cfg.GetString(abilityparam, weapon.attributes, sizeof(weapon.attributes));

      // Get the index from the config
      Format(abilityparam, sizeof(abilityparam), "%s_index", class);
      weapon.index = cfg.GetInt(abilityparam, 0);
      if (weapon.index <= 0)
      {
        continue;  // Skip if no index is provided
      }

      Format(abilityparam, sizeof(abilityparam), "%s_level", class);
      weapon.level = cfg.GetInt(abilityparam, 101);

      Format(abilityparam, sizeof(abilityparam), "%s_quality", class);
      weapon.quality = cfg.GetInt(abilityparam, 5);

      Format(abilityparam, sizeof(abilityparam), "%s_rank", class);

      weapon.rank = cfg.GetInt(abilityparam, 21);

      Format(abilityparam, sizeof(abilityparam), "%s_show", class);
      int show = cfg.GetInt(class + "_show", 1);

      
    }
  }
}

stock void GetClassStringByIndex(int index)
{
  switch (index)
  {
    case 1:
      return "scout";
    case 2:
      return "sniper";
    case 3:
      return "soldier";
    case 4:
      return "demoman";
    case 5:
      return "medic";
    case 6:
      return "heavy";
    case 7:
      return "pyro";
    case 8:
      return "spy";
    default:
      return "unknown";  // Handle invalid index
  }
}

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

stock int GetKillsOfWeaponRank(int rank = -1, int index = 0)
{
  switch (rank)
  {
    case 0:
    {
      return GetRandomInt(0, 9);
    }
    case 1:
    {
      return GetRandomInt(10, 24);
    }
    case 2:
    {
      return GetRandomInt(25, 44);
    }
    case 3:
    {
      return GetRandomInt(45, 69);
    }
    case 4:
    {
      return GetRandomInt(70, 99);
    }
    case 5:
    {
      return GetRandomInt(100, 134);
    }
    case 6:
    {
      return GetRandomInt(135, 174);
    }
    case 7:
    {
      return GetRandomInt(175, 224);
    }
    case 8:
    {
      return GetRandomInt(225, 274);
    }
    case 9:
    {
      return GetRandomInt(275, 349);
    }
    case 10:
    {
      return GetRandomInt(350, 499);
    }
    case 11:
    {
      if (index == 656)  // Holiday Punch
      {
        return GetRandomInt(500, 748);
      }
      else
      {
        return GetRandomInt(500, 749);
      }
    }
    case 12:
    {
      if (index == 656)  // Holiday Punch
      {
        return 749;
      }
      else
      {
        return GetRandomInt(750, 998);
      }
    }
    case 13:
    {
      if (index == 656)  // Holiday Punch
      {
        return GetRandomInt(750, 999);
      }
      else
      {
        return 999;
      }
    }
    case 14:
    {
      return GetRandomInt(1000, 1499);
    }
    case 15:
    {
      return GetRandomInt(1500, 2499);
    }
    case 16:
    {
      return GetRandomInt(2500, 4999);
    }
    case 17:
    {
      return GetRandomInt(5000, 7499);
    }
    case 18:
    {
      if (index == 656)  // Holiday Punch
      {
        return GetRandomInt(7500, 7922);
      }
      else
      {
        return GetRandomInt(7500, 7615);
      }
    }
    case 19:
    {
      if (index == 656)  // Holiday Punch
      {
        return GetRandomInt(7923, 8499);
      }
      else
      {
        return GetRandomInt(7616, 8499);
      }
    }
    case 20:
    {
      return GetRandomInt(8500, 9999);
    }
    default:
    {
      return GetRandomInt(0, 9999);
    }
  }
}
