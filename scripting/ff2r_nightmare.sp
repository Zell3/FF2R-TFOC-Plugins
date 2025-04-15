/*
    "nightmare_rage"
  {
    "slot"			"0"
    "duration"			"10"  //Timer of the Team confusion
    "friendlyfire"			"true"// false = off , true = on

    "health"		"150"	// red team health
    "models"			"models/freak_fortress_2/nightmaresniperv3/nightmaresniperv3.mdl" //Model for the victims
    "class"			"" //Class the victims Example scout <- sniper,soldier,demoman,medic,heavy,pyro,spy,engineer

    "weapons"			"tf_weapon_club" //Classname of the weapon the victims get
    "index"			"939" //Index of the weapon the victims get
    "attributes"			"2 ; 3.0 ; 68 ; -2" //Attributes of the weapon the victims get

    "plugin_name"	"ff2r_nightmare"
  }
*/

#include <tf2>
#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

/**
 * If you want to use formula to your ability, uncomment this.
 * This file provides ParseFormula functions.
 */
#include "freak_fortress_2/formula_parser.sp"

public Plugin myinfo =
{
  name   = "Freak Fortress 2: Nightmare Sniper's Ability",
  author = "M7 fix by Zell",
};

#define NIGHTMARE "nightmare_rage"
bool        NightmareFF;
TFClassType LastClass[MAXPLAYERS + 1];
char        NightmareModel[PLATFORM_MAX_PATH];
char        NightmareClassname[36];
char        NightmareAttributes[2048];
int         NightmareIndex;
bool        isOnAbility        = false;
int         tf_weapondrop_time = 0;

public void OnPluginStart()
{
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
  HookEvent("arena_win_panel", Event_OnRoundEnd, EventHookMode_PostNoCopy);

  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsClientInGame(clientIdx))
    {
      OnClientPutInServer(clientIdx);

      BossData cfg = FF2R_GetBossData(clientIdx);
      if (cfg)
      {
        FF2R_OnBossCreated(clientIdx, cfg, false);
      }
    }
  }
}

/**
 * Usually, SDKHook on OnTakeDamage here. But you can use nosoop's SM-TFOnTakeDamage instead.
 */
public void OnClientPutInServer(int client)
{
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("nightmare_rage");
    if (ability.IsMyPlugin())
    {
      PrepareAbilities();
    }
  }
}

public void PrepareAbilities()
{
  tf_weapondrop_time = GetConVarInt(FindConVar("tf_dropped_weapon_lifetime"));
  NightmareFF        = false;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int clientIdx = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(clientIdx))
    return;

  if (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
    return;  // Make sure it is not deadringer
  BossData boss = FF2R_GetBossData(clientIdx);
  if (boss)
    FF2R_OnBossRemoved(clientIdx);
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 *
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx)
{
  if (!isOnAbility)
    return;
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidLivingPlayer(client))
    {
      if (!FF2R_GetBossData(client) && (GetClientTeam(client) != GetClientTeam(clientIdx)))
      {
        SetVariantString("");
        AcceptEntityInput(client, "SetCustomModel");
        SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

        TF2_SetPlayerClass(client, LastClass[client]);
        TF2_RegeneratePlayer(client);
      }
    }
  }
}

/**
 * When using ability
 */
public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names
    return;

  if (!cfg.GetBool("enabled", true))  // hidden/internal bool for abilities
    return;

  if (!StrContains(ability, "nightmare_rage", false))
  {
    nightmareInvoke(client, ability, cfg);
  }
}

public void nightmareInvoke(int clientIdx, const char[] ability, AbilityData cfg)
{
  isOnAbility    = true;
  float duration = cfg.GetFloat("duration");
  NightmareFF    = cfg.GetBool("friendlyfire", false);
  char NightmareHealth[768];
  cfg.GetString("health", NightmareHealth, sizeof(NightmareHealth));
  cfg.GetString("models", NightmareModel, sizeof(NightmareModel));

  cfg.GetString("weapons", NightmareClassname, sizeof(NightmareClassname));
  NightmareIndex = cfg.GetInt("index");
  cfg.GetString("attributes", NightmareAttributes, sizeof(NightmareAttributes));

  HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);

  HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);

  // block drop weapons
  SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), 0);

  // And now proceed to rage
  for (int i = 1; i <= MaxClients; i++)
  {
    if ((IsValidClient(i) && IsPlayerAlive(i)) && (GetClientTeam(i) != GetClientTeam(clientIdx)))
    {
      // First, Remove all weapons
      TF2_RemoveAllWeapons(i);

      // Then set the class to whatever class you want and give them a custom weapon (it should be the bosses weapon and class, otherwise it would kinda destroy the purpose of this RAGE)
      static char buffers[40][256];

      LastClass[i] = TF2_GetPlayerClass(i);

      // change data from scout -> TFClass_Scout
      TFClassType forceClass;
      if (cfg.GetString("class", buffers[0], sizeof(buffers[])))
        forceClass = GetClassOfName(buffers[0]);

      // change player class
      if (forceClass != TFClass_Unknown && forceClass != LastClass[i])
        TF2_SetPlayerClass(i, forceClass, _, false);

      SpawnWeapon(i, NightmareClassname, NightmareIndex, 5, 8, NightmareAttributes);

      int entity;
      while ((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
        if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) <= MaxClients && i > 0 && GetClientTeam(i) != GetClientTeam(clientIdx))
          TF2_RemoveWearable(i, entity);
      while ((entity = FindEntityByClassname(entity, "tf_wearable_demoshield")) != -1)
        if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) <= MaxClients && i > 0 && GetClientTeam(i) != GetClientTeam(clientIdx))
          TF2_RemoveWearable(i, entity);
      while ((entity = FindEntityByClassname(entity, "tf_powerup_bottle")) != -1)
        if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) <= MaxClients && i > 0 && GetClientTeam(i) != GetClientTeam(clientIdx))
          TF2_RemoveWearable(i, entity);

      // Now setting the Model for the victims (should be the model of the boss, otherwise this RAGE is kinda useless)
      PrecacheModel(NightmareModel);
      SetVariantString(NightmareModel);
      AcceptEntityInput(i, "SetCustomModel");
      SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);

      int health = RoundToFloor(ParseFormula(NightmareHealth, clientIdx));
      if (health)
      {
        SetEntityHealth(i, health);
      }

      // Since it should confuse players, we need FriendlyFire aswell
      if (NightmareFF)
      {
        if (!GetConVarBool(FindConVar("mp_friendlyfire")))
        {
          SetConVarBool(FindConVar("mp_friendlyfire"), true);
        }
      }

      DataPack pack1;
      CreateDataTimer(duration, NightmareTick, pack1);
      pack1.WriteCell(GetClientUserId(i));
    }
  }
}

public Action NightmareTick(Handle timer, DataPack pack1)
{
  isOnAbility = false;
  pack1.Reset();
  int client = GetClientOfUserId(pack1.ReadCell());

  if (IsValidClient(client))
  {
    if (GetConVarBool(FindConVar("mp_friendlyfire")))
    {
      SetConVarBool(FindConVar("mp_friendlyfire"), false);
      UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
    }
    SetVariantString("");
    AcceptEntityInput(client, "SetCustomModel");
    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

    TF2_SetPlayerClass(client, LastClass[client]);
    TF2_RegeneratePlayer(client);

    DataPack pack;
    CreateDataTimer(2.0, EnableBlockDropWeapon, pack);
    pack.WriteCell(GetClientUserId(client));
  }
  return Plugin_Continue;
}

public Action EnableBlockDropWeapon(Handle timer, DataPack pack)
{
  pack.Reset();
  int client = GetClientOfUserId(pack.ReadCell());

  if (IsValidClient(client))
  {
    if (GetConVarInt(FindConVar("tf_dropped_weapon_lifetime")) == 0)
    {
      SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), tf_weapondrop_time);
      UnhookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);

      TF2_SetPlayerClass(client, LastClass[client]);
      TF2_RegeneratePlayer(client);
    }
  }
  return Plugin_Continue;
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

public void HideCvarNotify(Handle convar, const char[] oldValue, const char[] newValue)
{
  int flags = GetConVarFlags(convar);
  flags &= ~FCVAR_NOTIFY;
  SetConVarFlags(convar, flags);
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  // Make sure that Friendlyfire is disabled
  if (NightmareFF && GetConVarBool(FindConVar("mp_friendlyfire")))
  {
    SetConVarBool(FindConVar("mp_friendlyfire"), false);
    UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
  }

  if (NightmareFF)
  {
    NightmareFF = false;
  }
}

stock bool IsValidLivingPlayer(int client)
{
  if (client <= 0 || client > MaxClients)
    return false;

  return IsClientInGame(client) && IsPlayerAlive(client);
}

stock void SpawnWeapon(int client, char classname[36], int index, int level, int qual, char attributes[2048])
{
  Handle item   = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
  int    entity = -1;
  TF2Items_SetClassname(item, classname);
  TF2Items_SetItemIndex(item, index);
  TF2Items_SetLevel(item, level);
  TF2Items_SetQuality(item, qual);
  char atts[32][32];
  int  count = ExplodeString(attributes, " ; ", atts, 32, 32);
  if (count > 0)
  {
    TF2Items_SetNumAttributes(item, count / 2);
    int i2 = 0;
    for (int i = 0; i < count; i += 2)
    {
      TF2Items_SetAttribute(item, i2, StringToInt(atts[i]), StringToFloat(atts[i + 1]));
      i2++;
    }
  }
  else
    LogError("[Boss] Bad weapon attribute passed in Nightmare Abilities");
  entity = TF2Items_GiveNamedItem(client, item);
  CloseHandle(item);
  SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
  SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);

  EquipPlayerWeapon(client, entity);
}

TFClassType GetClassOfName(const char[] buffer)
{
  TFClassType class = view_as<TFClassType>(StringToInt(buffer));
  if (class == TFClass_Unknown)
    class = TF2_GetClass(buffer);

  return class;
}