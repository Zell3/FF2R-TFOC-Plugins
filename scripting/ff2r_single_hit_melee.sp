/*
  "rage_temp_melee"
  {
    "slot"				"0"								// Ability slot
    "classname"			"tf_weapon_knife"				// Weapon classname
    "attributes"		"2 ; 3.0 ; 6 ; 0.5 ; 37 ; 0.0"	// Weapon attributes (Values can be formulas)
    "index"				"1005"							// Weapon index
    "level"				"101"							// Weapon level
    "quality"			"5"								// Weapon quality
    "preserve"			"false"							// Preserve weapon attributes
    "rank"				"19"							// Weapon strange rank
    "show"				"true"							// Weapon visibility
    "worldmodel"		""								// Weapon worldmodel
    "alpha"				"255"							// Weapon alpha
    "red"				"255"							// Weapon red
    "green"				"255"							// Weapon green
    "blue"				"255"							// Weapon blue
    "class"				""								// Override class setup

    "weapon duration"	"10.0"							// Duration before weapon decays
    "remove on hit"		"true"							// Remove weapon upon landing a hit

    "do slot on hit low"		"11"					// Activate a slot upon landing a hit
    "do slot on hit high"		"11"					// Activate a slot upon landing a hit

    "plugin_name"	"ff2r_timed_melee"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#undef REQUIRE_PLUGIN
#tryinclude < tf2utils>
#tryinclude < tf_custom_attributes>

#include "freak_fortress_2/formula_parser.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Single Hit Melee"
#define PLUGIN_AUTHOR   "J0BL3SS"
#define PLUGIN_DESC     "Melee Weapon with customization"

#define MAJOR_REVISION  "1"
#define MINOR_REVISION  "0"
#define STABLE_REVISION "1"
#define PLUGIN_VERSION  MAJOR_REVISION... "." ... MINOR_REVISION... "." ... STABLE_REVISION

#define PLUGIN_URL      ""

#define MAXTF2PLAYERS   MAXPLAYERS + 1

int        PlayersAlive[4];
bool       SpecTeam;
ConVar     CvarFriendlyFire;
bool       CanHit[MAXTF2PLAYERS] = { false, ... };
ConfigData Ability_Data[MAXTF2PLAYERS];
int        WeaponEnt[MAXTF2PLAYERS];

#define TCA_LIBRARY "tf2custattr"

#if defined __tf_custom_attributes_included
bool        TCALoaded;
#endif

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTHOR,
  description = PLUGIN_DESC,
  version     = PLUGIN_VERSION,
  url         = PLUGIN_URL,
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
#if defined __tf_custom_attributes_included
  MarkNativeAsOptional("TF2CustAttr_SetString");
#endif
  return APLRes_Success;
}

public void OnPluginStart()
{
  CvarFriendlyFire = FindConVar("mp_friendlyfire");

  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsValidClient(clientIdx))
    {
      OnClientPutInServer(clientIdx);
    }
  }
}

public void OnPluginEnd()
{
  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    CanHit[clientIdx] = false;
    SDKUnhook(clientIdx, SDKHook_OnTakeDamage, Wep_OnTakeDamage);
  }
}

public void OnClientPutInServer(int clientIdx)
{
  SDKHook(clientIdx, SDKHook_OnTakeDamage, Wep_OnTakeDamage);
}

public void OnLibraryAdded(const char[] name)
{
#if defined __tf_custom_attributes_included
  if (!TCALoaded && StrEqual(name, TCA_LIBRARY))
    TCALoaded = true;
#endif
}

public void OnLibraryRemoved(const char[] name)
{
#if defined __tf_custom_attributes_included
  if (TCALoaded && StrEqual(name, TCA_LIBRARY))
    TCALoaded = false;
#endif
}

public Action Wep_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  if (IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
  {
    if (CanHit[attacker])
    {
      CanHit[attacker] = false;

      CreateTimer(0.1, Timer_RestoreWeapon, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);

      if (Ability_Data[attacker])
      {
        int slot = Ability_Data[attacker].GetInt("do slot on hit high", Ability_Data[attacker].GetInt("do slot on hit low"));
        FF2R_DoBossSlot(attacker, Ability_Data[attacker].GetInt("do slot on hit low", slot), slot);
      }
    }
  }
  return Plugin_Continue;
}

public Action Timer_RestoreWeapon(Handle timer, int userid)
{
  int attacker = GetClientOfUserId(userid);
  if (attacker && IsValidClient(attacker) && IsPlayerAlive(attacker) && IsValidEntity(WeaponEnt[attacker]) && WeaponEnt[attacker] != -1)
  {
    BossData boss = FF2R_GetBossData(attacker);
    if (boss)
    {
      if (WeaponEnt[attacker] == GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee))
      {
        char buffer[64];
        for (int i = 0; i <= 16; i++)
        {
          GetConfigWeapon(i, buffer, sizeof(buffer));
          ConfigData wep = boss.GetSection(buffer);
          if (wep)
            Rage_NewWeapon(attacker, wep, buffer, false);
        }
      }
    }
  }

  return Plugin_Continue;
}

stock int GetIndexOfWeaponSlot(int iClient, int iSlot)
{
  return GetWeaponIndex(GetPlayerWeaponSlot(iClient, iSlot));
}

stock int GetWeaponIndex(int iWeapon)
{
  return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock bool IsValidEnt(int iEnt)
{
  return iEnt > MaxClients && IsValidEntity(iEnt);
}

public void GetConfigWeapon(int count, char[] buffer, int maxlenght)
{
  switch (count)
  {
    case 1: Format(buffer, maxlenght, "tf_weapon_bat");
    case 2: Format(buffer, maxlenght, "tf_weapon_bat_fish");
    case 3: Format(buffer, maxlenght, "tf_weapon_bat_giftwrap");
    case 4: Format(buffer, maxlenght, "tf_weapon_bat_wood");
    case 5: Format(buffer, maxlenght, "tf_weapon_katana");
    case 6: Format(buffer, maxlenght, "tf_weapon_breakable_sign");
    case 7: Format(buffer, maxlenght, "tf_weapon_slap");
    case 8: Format(buffer, maxlenght, "tf_weapon_bottle");
    case 9: Format(buffer, maxlenght, "tf_weapon_sword");
    case 10: Format(buffer, maxlenght, "tf_weapon_stickbomb");
    case 11: Format(buffer, maxlenght, "tf_weapon_fists");
    case 12: Format(buffer, maxlenght, "tf_weapon_wrench");
    case 13: Format(buffer, maxlenght, "tf_weapon_roboarm");
    case 14: Format(buffer, maxlenght, "tf_weapon_bonesaw");
    case 15: Format(buffer, maxlenght, "tf_weapon_fireaxe");
    case 16: Format(buffer, maxlenght, "tf_weapon_club");
    default: Format(buffer, maxlenght, "tf_weapon_knife");
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  CanHit[clientIdx] = false;
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!cfg.GetBool("enabled", true))  // hidden/internal bool for abilities
    return;

  if (!StrContains(ability, "rage_temp_melee", false))  // We want to use subffixes
  {
    Rage_NewWeapon(clientIdx, cfg, ability);
  }
}

void Rage_NewWeapon(int client, ConfigData cfg, const char[] ability, bool reset = true)
{
  static char classname[36], attributes[2048];
  if (!cfg.GetString("classname", classname, sizeof(classname)))
    cfg.GetString("name", classname, sizeof(classname), ability);

  cfg.GetString("attributes", attributes, sizeof(attributes));

  TFClassType class = TF2_GetPlayerClass(client);
  GetClassWeaponClassname(class, classname, sizeof(classname));
  bool wearable = StrContains(classname, "tf_weap") != 0;

  if (!wearable)
  {
    int slot = cfg.GetInt("weapon slot", -99);
    if (slot == -99)
      slot = TF2_GetClassnameSlot(classname);

    if (slot >= 0 && slot < 6)
      TF2_RemoveWeaponSlot(client, slot);
  }

  int  index    = cfg.GetInt("index");
  int  level    = cfg.GetInt("level", -1);
  int  quality  = cfg.GetInt("quality", 5);
  bool preserve = cfg.GetBool("preserve");

  int  kills    = cfg.GetInt("rank", -99);
  if (kills == -99 && level == -1)
    kills = GetURandomInt() % 21;

  if (kills >= 0)
    kills = GetKillsOfWeaponRank(kills, index);

  if (level < 0 || level > 127)
    level = 101;

  static char buffers[40][256];

  TFClassType forceClass;
  if (cfg.GetString("class", buffers[0], sizeof(buffers[])))
    forceClass = GetClassOfName(buffers[0]);

  if (forceClass != TFClass_Unknown)
    TF2_SetPlayerClass(client, forceClass, _, false);

  int count = ExplodeString(attributes, " ; ", buffers, sizeof(buffers), sizeof(buffers));

  if (count % 2)
    count--;

  int alive = GetTotalPlayersAlive(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client));
  int attribs;
  int entity = -1;
  if (wearable)
  {
    entity = CreateEntityByName(classname);
    if (IsValidEntity(entity))
    {
      SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
      SetEntProp(entity, Prop_Send, "m_bInitialized", true);
      SetEntProp(entity, Prop_Send, "m_iEntityQuality", quality);
      SetEntProp(entity, Prop_Send, "m_iEntityLevel", level);

      DispatchSpawn(entity);
    }
    else
    {
      FF2R_GetBossData(client).GetString("filename", buffers[0], sizeof(buffers[]));
      LogError("[Boss] Invalid classname '%s' for '%s' in '%s'", classname, buffers[0], ability);
    }
  }
  else
  {
    Handle item = TF2Items_CreateItem(preserve ? (OVERRIDE_ALL | FORCE_GENERATION | PRESERVE_ATTRIBUTES) : (OVERRIDE_ALL | FORCE_GENERATION));
    TF2Items_SetClassname(item, classname);
    TF2Items_SetItemIndex(item, index);
    TF2Items_SetLevel(item, level);
    TF2Items_SetQuality(item, quality);
    TF2Items_SetNumAttributes(item, count / 2 > 14 ? 15 : count / 2);
    for (level = 0; attribs < count && level < 16; attribs += 2)
    {
      int attrib = StringToInt(buffers[attribs]);
      if (attrib)
      {
        TF2Items_SetAttribute(item, level++, attrib, ParseFormula(buffers[attribs + 1], alive));
      }
      else
      {
        FF2R_GetBossData(client).Get("filename", attributes, sizeof(attributes));
        LogError("[Boss] Bad weapon attribute passed for '%s' on '%s': %s ; %s in '%s'", attributes, classname, buffers[attribs], buffers[attribs + 1], ability);
      }
    }

    entity = TF2Items_GiveNamedItem(client, item);
    delete item;
  }

  if (entity != -1)
  {
    EquipPlayerWeapon(client, entity);

    if (forceClass != TFClass_Unknown)
      TF2_SetPlayerClass(client, class, _, false);

    for (; attribs < count; attribs += 2)
    {
      int attrib = StringToInt(buffers[attribs]);
      if (attrib)
      {
        TF2Attrib_SetByDefIndex(entity, attrib, ParseFormula(buffers[attribs + 1], alive));
      }
      else
      {
        FF2R_GetBossData(client).Get("filename", attributes, sizeof(attributes));
        LogError("[Boss] Bad weapon attribute passed for '%s' on '%s': %s ; %s in '%s'", attributes, classname, buffers[attribs], buffers[attribs + 1], ability);
      }
    }

#if defined __tf_custom_attributes_included
    if (TCALoaded)
    {
      ConfigData custom = cfg.GetSection("custom");
      if (custom)
        ApplyCustomAttributes(entity, custom);
    }
#endif

    if (kills >= 0)
      TF2Attrib_SetByDefIndex(entity, 214, view_as<float>(kills));

    if (cfg.GetBool("show", true))
    {
      if (cfg.GetString("worldmodel", buffers[0], sizeof(buffers[])))
      {
        index = StringToInt(buffers[0]);
        if (!index)
          index = PrecacheModel(buffers[0]);

        SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", index);
        for (level = 0; level < 4; level++)
        {
          SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", index, _, level);
        }
      }

      GetEntityNetClass(entity, attributes, sizeof(attributes));
      int offset = FindSendPropInfo(attributes, "m_iItemIDHigh");

      SetEntData(entity, offset - 8, 0);  // m_iItemID
      SetEntData(entity, offset - 4, 0);  // m_iItemID
      SetEntData(entity, offset, 0);      // m_iItemIDHigh
      SetEntData(entity, offset + 4, 0);  // m_iItemIDLow

      SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", true);
    }
    else
    {
      SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
      SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
    }

    level = cfg.GetInt("alpha", 255);
    index = cfg.GetInt("red", 255);
    kills = cfg.GetInt("green", 255);
    count = cfg.GetInt("blue", 255);

    if (level != 255 || index != 255 || kills != 255 || count != 255)
    {
      SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
      SetEntityRenderColor(entity, index, kills, count, level);
    }

    SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));

    if (!wearable)
    {
      if (cfg.GetBool("force switch", true))
      {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", entity);
      }
      else
      {
        FakeClientCommand(client, "use %s", classname);
      }
    }

    if (cfg.GetBool("remove on hit", true) && reset)
      CanHit[client] = true;

    Ability_Data[client] = cfg;
    WeaponEnt[client]    = entity;

    CreateTimer(cfg.GetFloat("weapon duration", 5.0), Timer_RestoreWeapon, client, TIMER_FLAG_NO_MAPCHANGE);

    int victims;
    int[] victim = new int[MaxClients - 1];
    for (int target = 1; target <= MaxClients; target++)
    {
      if (IsValidClient(target))
      {
        victim[victims++] = target;
      }
    }

    if (victims)
    {
      char buffer[128];
      Format(buffer, sizeof(buffer), "sound_%s", ability);
      FF2R_EmitBossSound(victim, victims, buffer, client);
    }
  }
  else if (forceClass != TFClass_Unknown)
  {
    TF2_SetPlayerClass(client, class, _, false);
  }

  // return entity;
}

int TF2_GetClassnameSlot(const char[] classname, bool econ = false)
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

public void FF2R_OnAliveChanged(const int alive[4], const int total[4])
{
  for (int i; i < 4; i++)
  {
    PlayersAlive[i] = alive[i];
  }

  SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

int GetTotalPlayersAlive(int team = -1)
{
  int amount;
  for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++)
  {
    if (i != team)
      amount += PlayersAlive[i];
  }

  return amount;
}

#if defined __tf_custom_attributes_included
void        ApplyCustomAttributes(int entity, ConfigData cfg)
{
  StringMapSnapshot snap    = cfg.Snapshot();

  int               entries = snap.Length;
  for (int i; i < entries; i++)
  {
    int length = snap.KeyBufferSize(i) + 1;

    char[] key = new char[length];
    snap.GetKey(i, key, length);

    static PackVal attribute;
    cfg.GetArray(key, attribute, sizeof(attribute));
    if (attribute.tag == KeyValType_Value)
      TF2CustAttr_SetString(entity, key, attribute.data);
  }

  delete snap;
}
#endif

int GetKillsOfWeaponRank(int rank = -1, int index = 0)
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

TFClassType GetClassOfName(const char[] buffer)
{
  TFClassType class = view_as<TFClassType>(StringToInt(buffer));
  if (class == TFClass_Unknown)
    class = TF2_GetClass(buffer);

  return class;
}

void GetClassWeaponClassname(TFClassType class, char[] name, int length)
{
  if (!StrContains(name, "saxxy"))
  {
    switch (class)
    {
      case TFClass_Scout: strcopy(name, length, "tf_weapon_bat");
      case TFClass_Pyro: strcopy(name, length, "tf_weapon_fireaxe");
      case TFClass_DemoMan: strcopy(name, length, "tf_weapon_bottle");
      case TFClass_Heavy: strcopy(name, length, "tf_weapon_fists");
      case TFClass_Engineer: strcopy(name, length, "tf_weapon_wrench");
      case TFClass_Medic: strcopy(name, length, "tf_weapon_bonesaw");
      case TFClass_Sniper: strcopy(name, length, "tf_weapon_club");
      case TFClass_Spy: strcopy(name, length, "tf_weapon_knife");
      default: strcopy(name, length, "tf_weapon_shovel");
    }
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