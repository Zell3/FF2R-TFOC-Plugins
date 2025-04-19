/*
"hooks_for_players"
    {
        "attributes" 	""
    "quality"		""
    "level"			""
    "rank"			""
    "show"			""	// 0 = not show, 1 = show

        "team"		"1"		// Who should get a hook? (0 = Boss + Player, 1 = Players only, 2 = Boss only)

        "plugin_name"   "ff2r_special_hooks"
    }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>

#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

char             attrs[768];
int              lv;
int              rk;
int              qua;
int              show;
bool             hooksEnabled;

public Plugin myinfo =
{
  name        = "[FF2R] Abilities for Gin",
  author      = "M7 , Zell",
  description = "",
  version     = "1.5.2",
  url         = ""
};

public void OnPluginStart()
{
  HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);

  hooksEnabled = false;

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

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int clientIdx = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(clientIdx))
    return;

  if (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
    return;  // Make sure it is not deadringer

  if (hooksEnabled)
    SpawnWeapon(clientIdx, "tf_weapon_grapplinghook", attrs, 1152, lv, qua, rk, show);
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

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("hooks_for_players");
    if (ability.IsMyPlugin())
    {
      hooksEnabled = true;
      ability.GetString("attributes", attrs, sizeof(attrs));
      lv       = ability.GetInt("level");
      qua      = ability.GetInt("quality");
      rk       = ability.GetInt("rank");
      show     = ability.GetInt("show");

      int team = ability.GetInt("team");

      if (team == 2)
      {
        SpawnWeapon(clientIdx, "tf_weapon_grapplinghook", attrs, 1152, lv, qua, rk, show);
        return;
      }

      for (int client = 1; client <= MaxClients; client++)
      {
        if (!IsValidClient(client))
          continue;

        if (team == 1)
        {
          if (GetClientTeam(client) != GetClientTeam(clientIdx))
          {
            SpawnWeapon(client, "tf_weapon_grapplinghook", attrs, 1152, lv, qua, rk, show);
          }
        }
        else if (team == 0) {
          SpawnWeapon(client, "tf_weapon_grapplinghook", attrs, 1152, lv, qua, rk, show);
        }
      }
    }
  }
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 *
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx)
{
  hooksEnabled = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  // naw
}

public int SpawnWeapon(int client, char[] name, char[] attribute, int index, int level, int quality, int kills, int visible)
{
  Handle weapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
  TF2Items_SetClassname(weapon, name);
  TF2Items_SetItemIndex(weapon, index);
  TF2Items_SetLevel(weapon, level);
  TF2Items_SetQuality(weapon, quality);
  char attributes[32][32];
  int  count = ExplodeString(attribute, ";", attributes, 32, 32);
  if (count % 2 != 0)
  {
    count--;
  }

  if (count > 0)
  {
    TF2Items_SetNumAttributes(weapon, count / 2);
    int i2 = 0;
    for (int i = 0; i < count; i += 2)
    {
      int attrib = StringToInt(attributes[i]);
      if (attrib == 0)
      {
        LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i + 1]);
        return -1;
      }
      TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i + 1]));
      i2++;
    }
  }
  else
  {
    TF2Items_SetNumAttributes(weapon, 0);
  }
  if (weapon == INVALID_HANDLE)
  {
    return -1;
  }
  int entity = TF2Items_GiveNamedItem(client, weapon);

  if (kills >= 0)
    TF2Attrib_SetByDefIndex(entity, 214, view_as<float>(kills));

  CloseHandle(weapon);
  EquipPlayerWeapon(client, entity);

  // sarysa addition, since cheese's weapons are currently invisible
  if (!visible)
  {
    SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
    // SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", -1, _, 0);
    SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
  }

  return entity;
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