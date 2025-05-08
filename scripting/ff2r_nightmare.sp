/*
  "rage_nightmare"    // this plugins will disable item drops, u can also use as silent friendly fire
  {
    "slot"			    "0"
    "duration"			"10"      // Timer of the Team confusion
    "friendlyfire"	"0"       // 0 = off , 1 = on

    "health"		    "150"	    // red team health (can't use formula)
    "models"			  "models/freak_fortress_2/nightmaresniperv3/nightmaresniperv3.mdl" //Model for the victims
    "class"			    ""        // Class the victims Example scout <- sniper,soldier,demoman,medic,heavy,pyro,spy,engineer

    "classname"			"tf_weapon_club"    // Classname of the weapon the victims get
    "index"			    "939"               // Index of the weapon the victims get
    "attributes"		"2 ; 3.0 ; 68 ; -2" // Attributes of the weapon the victims get

    "plugin_name"	  "ff2r_nightmare"
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

#define INACTIVE               100000000.0
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH  256

public Plugin myinfo =
{
  name   = "Freak Fortress 2: Nightmare Sniper's Ability",
  author = "M7 fix by Zell",
};

float       duration = INACTIVE;
TFClassType lastClass[MAXPLAYERS + 1];
int         tf_dropped_weapon_lifetime;

public void FF2R_OnBossRemoved(int clientIdx)
{
  if (duration != INACTIVE)
    duration = INACTIVE;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names
    return;

  if (!StrContains(ability, "rage_nightmare", false))
  {
    // disable item drops
    tf_dropped_weapon_lifetime = GetConVarInt(FindConVar("tf_dropped_weapon_lifetime"));
    if (tf_dropped_weapon_lifetime != 0)
    {
      HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
      SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), 0);
      UnhookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
    }

    // check if friendlyfire is enabled
    int friendlyfire = cfg.GetInt("friendlyfire", 0);
    if (friendlyfire == 1)
    {
      if (!GetConVarBool(FindConVar("mp_friendlyfire")))
      {
        HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
        SetConVarBool(FindConVar("mp_friendlyfire"), true);
        UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
      }
    }

    duration    = GetEngineTime() + cfg.GetFloat("duration", 0.0);  // Timer of the Team confusion
    int  health = cfg.GetInt("health", 0);                        // red team health (can't use formula)
    char models[PLATFORM_MAX_PATH];                               // Model for the victims
    char classname[MAX_WEAPON_NAME_LENGTH];                       // Classname of the weapon the victims get
    char attribute[MAX_WEAPON_ARG_LENGTH];                        // Attributes of the weapon the victims get

    char buffer[32];
    cfg.GetString("class", buffer, sizeof(buffer));
    TFClassType class = GetClassOfName(buffer);  // Cl

    cfg.GetString("models", models, sizeof(models));
    cfg.GetString("classname", classname, sizeof(classname));
    cfg.GetString("attributes", attribute, sizeof(attribute));
    int index = cfg.GetInt("index", 0);

    if (models[0] != '\0' && class != TFClass_Unknown)
    {
      PrecacheModel(models);
      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidLivingPlayer(i) && (GetClientTeam(i) != GetClientTeam(client)))
        {
          TF2_RemoveAllWeapons(i);
          lastClass[i] = TF2_GetPlayerClass(i);

          if (class != lastClass[i])
            TF2_SetPlayerClass(i, class, _, false);

          SpawnWeapon(i, classname, index, 5, 8, attribute);

          RemoveAllWearables(i);

          // Now setting the Model for the victims (should be the model of the boss, otherwise this RAGE is kinda useless)
          SetVariantString(models);
          AcceptEntityInput(i, "SetCustomModel");
          SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);
          SetEntityHealth(i, health);
        }
      }
    }

    SDKHook(client, SDKHook_PreThink, NightmareTick);
  }
}

public void NightmareTick(int client)
{
  if (GetEngineTime() >= duration || duration == INACTIVE)
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidLivingPlayer(i) && (GetClientTeam(i) != GetClientTeam(client)))
      {
        SetVariantString("");
        AcceptEntityInput(i, "SetCustomModel");
        SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);
        TF2_SetPlayerClass(i, lastClass[i]);
        TF2_RegeneratePlayer(i);
      }
    }

    // enable item drops
    if (tf_dropped_weapon_lifetime != 0)
    {
      HookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
      SetConVarInt(FindConVar("tf_dropped_weapon_lifetime"), tf_dropped_weapon_lifetime);
      UnhookConVarChange(FindConVar("tf_dropped_weapon_lifetime"), HideCvarNotify);
    }

    // check if friendlyfire is enabled
    bool friendlyfire = GetConVarBool(FindConVar("mp_friendlyfire"));
    if (friendlyfire)
    {
      HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
      SetConVarBool(FindConVar("mp_friendlyfire"), false);
      UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
    }

    SDKUnhook(client, SDKHook_PreThink, NightmareTick);
    duration = INACTIVE;
  }
}

public void RemoveAllWearables(int client)
{
  int entity;
  while ((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_wearable_demoshield")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_wearable_campaign_item")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_wearable_levelable_item")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_wearable_razorback")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_wearable_robot_arm")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
  while ((entity = FindEntityByClassname(entity, "tf_powerup_bottle")) != -1)
    if ((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == client)
      TF2_RemoveWearable(client, entity);
}

public void HideCvarNotify(Handle convar, const char[] oldValue, const char[] newValue)
{
  int flags = GetConVarFlags(convar);
  flags &= ~FCVAR_NOTIFY;
  SetConVarFlags(convar, flags);
}

stock bool IsValidLivingPlayer(int client)
{
  return IsValidClient(client) && IsPlayerAlive(client);
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

stock void SpawnWeapon(int client, char[] classname, int index, int level, int qual, char[] attributes)
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