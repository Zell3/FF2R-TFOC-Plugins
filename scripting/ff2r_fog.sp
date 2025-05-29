/*
* Freak Fortress 2 Rewrite: Fog Effects
* you can use something like fx and then rage on lose life because i made it always remove previous fog
* still recommended only use one fog effect at a time
* also remove "effect range" because it also applied to client when respawned
* ait was useless to have range when everyone always set to 9999.0 anyway :shrug:

  "rage_fog_fx"		// Ability name can use suffixes
  {
    "slot"			  "0"

    // delay before applying the fog effect
    "delay"			  "0"

    //colors
    "color1"		  "255 255 255"		// RGB colors
    "color2"		  "255 255 255"		// RGB colors

    // fog properties
    "blend"			  "0" 				    // blend
    "fog start"		"64.0"				  // fog start distance
    "fog end"		  "384.0"				  // fog end distance
    "fog density"	"1.0"				    // fog density

    // effect properties
    "effect type"	"0"					    // fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "duration"		"5.0"				    // fog duration 0.0 means forever

    "plugin_name"	"ff2r_fog"
  }

  "fog_fx"		// Ability name can use suffixes
  {
    // slot is ignored

    //colors
    "color1"		  "255 255 255"		// RGB colors
    "color2"		  "255 255 255"		// RGB colors

    // fog properties
    "blend"			  "0" 				    // blend
    "fog start"		"64.0"				  // fog start distance
    "fog end"		  "384.0"				  // fog end distance
    "fog density"	"1.0"				    // fog density

    // effect properties
    "effect type"	"0"					    // fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name"	"ff2r_fog"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Fog Effects",
  description = "Fog Effects System for FF2R",
  author      = "Koishi, J0BL3SS, Zell",
  version     = "1.2.0",
};

enum struct FogSettings
{
  int   controller;
  bool  isActive;
  int   effectType;
  float duration;
  char  color1[16];
  char  color2[16];
  char  blend;
  float fogStart;
  float fogEnd;
  float density;
}

FogSettings g_FogData;

float       g_flClientFogDuration[MAXPLAYERS + 1];

public void OnPluginStart()
{
  // Event hooks
  HookEvent("arena_win_panel", Event_RoundEnd);
  HookEvent("teamplay_round_win", Event_RoundEnd);
  HookEvent("player_spawn", Event_PlayerSpawn);

  g_FogData.controller = -1;

  // Initialize all clients' fog duration to INACTIVE
  for (int i = 0; i <= MaxClients; i++)
    g_flClientFogDuration[i] = INACTIVE;
}

public void OnPluginEnd()
{
  // unhook events
  UnhookEvent("arena_win_panel", Event_RoundEnd);
  UnhookEvent("teamplay_round_win", Event_RoundEnd);
  UnhookEvent("player_spawn", Event_PlayerSpawn);

  // Cleanup
  g_FogData.controller = -1;
  RemoveFog();

  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client))
    {
      SDKUnhook(client, SDKHook_PreThinkPost, Timer_FogDuration);
    }
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  // fog_fx is a passive ability
  // apply before the round starts
  if (!(!setup || FF2R_GetGamemodeType() != 2))
  {
    AbilityData passive = cfg.GetAbility("fog_fx");
    if (passive.IsMyPlugin())
    {
      LoadFogSettings(passive);
      ApplyFogEffect(client, 0.0);
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_fog_fx", false) && cfg.IsMyPlugin())
  {
    float    delay = cfg.GetFloat("delay", 0.0);
    DataPack pack;
    CreateDataTimer(delay, Timer_ApplyRageFog, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(cfg);
  }
}

// applied fog effect to the client if the client is a target
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  // check if the client is valid and if the fog is active
  if (!IsValidClient(client) || !g_FogData.isActive)
    return;

  // get the boss data for the client
  for (int boss = 1; boss <= MaxClients; boss++)
  {
    BossData cfg = FF2R_GetBossData(boss);
    if (cfg && IsTarget(boss, client))
    {
      SetFogController(client);
      break;
    }
  }
}

// remove fog when the round ends
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  RemoveFog();

  for (int client = 1; client <= MaxClients; client++)
    if (IsValidClient(client))
      SDKUnhook(client, SDKHook_PreThinkPost, Timer_FogDuration);
}

// delayed fog apply
public Action Timer_ApplyRageFog(Handle timer, DataPack pack)
{
  pack.Reset();
  int client = GetClientOfUserId(pack.ReadCell());

  if (!client)
    return Plugin_Handled;

  AbilityData cfg = pack.ReadCell();

  LoadFogSettings(cfg);
  ApplyFogEffect(client, cfg.GetFloat("duration", 0.0));
  return Plugin_Continue;
}

// load fog settings from the ability data
public void LoadFogSettings(AbilityData cfg)
{
  g_FogData.effectType = cfg.GetInt("effect type", 0);
  cfg.GetString("blend", g_FogData.blend, sizeof(FogSettings::blend), "0");
  cfg.GetString("color1", g_FogData.color1, sizeof(FogSettings::color1), "255 255 255");
  cfg.GetString("color2", g_FogData.color2, sizeof(FogSettings::color2), "255 255 255");
  g_FogData.fogStart = cfg.GetFloat("fog start", 64.0);
  g_FogData.fogEnd   = cfg.GetFloat("fog end", 384.0);
  g_FogData.density  = cfg.GetFloat("fog density", 1.0);
}

public void ApplyFogEffect(int client, float duration)
{
  if (g_FogData.controller != -1)
    RemoveFog();

  g_FogData.controller = CreateFogController();
  if (g_FogData.controller == -1)
    return;

  for (int target = 1; target <= MaxClients; target++)
  {
    if (!IsValidClient(target))
      continue;

    if (IsTarget(client, target))
      SetFogController(target);
  }

  // why you need to set fog duration more than 5 minutes when round time is around 7 minutes
  if (duration > 0.0 && duration < 300.0)
  {
    g_flClientFogDuration[client] = GetGameTime() + duration;
    SDKHook(client, SDKHook_PreThinkPost, Timer_FogDuration);  // Hook the client to check for fog duration
  }
}

// create fog controller entity
public int CreateFogController()
{
  int ent = CreateEntityByName("env_fog_controller");
  if (!IsValidEntity(ent))
    return -1;

  DispatchKeyValue(ent, "targetname", "MyFog");
  DispatchKeyValue(ent, "fogenable", "1");
  DispatchKeyValue(ent, "spawnflags", "1");
  DispatchKeyValue(ent, "fogblend", g_FogData.blend);
  DispatchKeyValue(ent, "fogcolor", g_FogData.color1);
  DispatchKeyValue(ent, "fogcolor2", g_FogData.color2);
  DispatchKeyValueFloat(ent, "fogstart", g_FogData.fogStart);
  DispatchKeyValueFloat(ent, "fogend", g_FogData.fogEnd);
  DispatchKeyValueFloat(ent, "fogmaxdensity", g_FogData.density);
  DispatchSpawn(ent);
  AcceptEntityInput(ent, "TurnOn");
  g_FogData.isActive = true;

  return ent;
}

// set fog controller to the client
public void SetFogController(int client)
{
  if (IsValidEntity(g_FogData.controller))
  {
    SetVariantString("MyFog");
    AcceptEntityInput(client, "SetFogController");
  }
}

// remove fog (when removed we should remove all fog for clients too because fog should only have one controller)
public void RemoveFog()
{
  if (!IsValidEntity(g_FogData.controller))
    return;

  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client))
    {
      SetVariantString("");
      AcceptEntityInput(client, "SetFogController");
      g_flClientFogDuration[client] = INACTIVE;  // Add this line
    }
  }

  AcceptEntityInput(g_FogData.controller, "Kill");
  g_FogData.controller = -1;
  g_FogData.isActive   = false;
}

public void Timer_FogDuration(int client)
{
  // this will be called when the duration of the fog is over and it will auto unhook if round is over
  if (GetGameTime() >= g_flClientFogDuration[client])
  {
    g_flClientFogDuration[client] = INACTIVE;
    SDKUnhook(client, SDKHook_PreThinkPost, Timer_FogDuration);
    if (g_FogData.isActive)
      RemoveFog();
  }
}

// check if the client is a target for the fog effect
stock bool IsTarget(int boss, int target)
{
  switch (g_FogData.effectType)
  {
    case 1: return boss == target;                                // Only boss
    case 2: return GetClientTeam(boss) == GetClientTeam(target);  // Same team
    case 3: return GetClientTeam(boss) != GetClientTeam(target);  // Enemy team
    case 4: return boss != target;                                // Everyone except boss
    default: return true;                                         // Everyone
  }
}

// very very useful stock i used it everywhere
stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
  {
    return false;
  }
  if (!IsClientInGame(client) || !IsClientConnected(client))
  {
    return false;
  }
  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
  {
    return false;
  }
  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
  {
    return false;
  }
  return true;
}