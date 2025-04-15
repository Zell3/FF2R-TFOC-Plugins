/*
  "rage_fog_fx"		// Ability name can use suffixes
  {
    "slot"			"0"

    "dalay"			"0"

    //colors
    "color1"		"255 255 255"		// RGB colors
    "color2"		"255 255 255"		// RGB colors

    // fog properties
    "blend"			"0" 				// blend
    "fog start"		"64.0"				// fog start distance
    "fog end"		"384.0"				// fog end distance
    "fog density"	"1.0"				// fog density

    // effect properties
    "effect type"	"0"					// fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "duration"		"5.0"				// fog duration

    "plugin_name"	"ff2r_fog"
  }

  "fog_fx"			// Ability name can't use suffixes
  {
    "slot"			"0"

    //colors
    "color1"		"255 255 255"		// RGB colors
    "color2"		"255 255 255"		// RGB colors

    // fog properties
    "blend"			"0" 				// blend
    "fog start"		"64.0"				// fog start distance
    "fog end"		"384.0"				// fog end distance
    "fog density"	"1.0"				// fog density

    // effect properties
    "effect type"	"0"					// fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"	"ff2r_fog"
  }

*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

#define VERSION_NUMBER "1.0.6"
public Plugin myinfo =
{
  name        = "Freak Fortress 2: Fog Effects",
  description = "Fog Effects, Darken Has Come",  //"フォグ効果" Sorry Shadow. We really need something universal that everyone can understand
  author      = "Koishi, J0BL3SS, Zell",
  version     = VERSION_NUMBER,
};

int   envFog = -1;
bool  IsFogActive;
bool  IsRound;
int   effectboss;
float fogDuration[MAXPLAYERS + 1];


public void OnPluginStart()
{
  HookEvent("arena_win_panel", Event_RoundEnd);
  HookEvent("teamplay_round_win", Event_RoundEnd);  // for non-arena maps
  HookEvent("player_spawn", Event_PlayerSpawn);  // reanimator respawn - no fog bug fix

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

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int target = GetClientOfUserId(GetEventInt(event, "userid"));
  if (!IsValidClient(target))
    return;

  if (IsFogActive)
  {
    for (int client = 1; client <= MaxClients; client++)
    {
      BossData boss = FF2R_GetBossData(client);
      if (boss)
      {
        if (FogEffectType(client, target))
        {
            SetVariantString("MyFog");
            AcceptEntityInput(target, "SetFogController");
        }
      }
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  KillFog(envFog);

  for (int client = 1; client <= MaxClients; client++)
  {
    if (!IsValidClient(client))
      continue;

    SDKUnhook(client, SDKHook_PreThinkPost, FogTimer);
  }
  IsRound = false;
  envFog = -1;
}

// if (!setup || FF2R_GetGamemodeType() != 2)
public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!(!setup || FF2R_GetGamemodeType() != 2))
  {
    AbilityData passive = cfg.GetAbility("fog_fx");
    if (passive.IsMyPlugin())
      PrepareFog(client, "fog_fx", passive);
  }
  if (!setup || FF2R_GetGamemodeType() != 2)
    IsRound = true;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!IsRound)
    return;

  if (!StrContains(ability, "rage_fog_fx", false) && cfg.IsMyPlugin())
  {
    float    delay = cfg.GetFloat("delay", 0.0);
    DataPack pack;
    CreateDataTimer(delay, FogDelay, pack);
    pack.WriteCell(client);
    pack.WriteString(ability);
    pack.WriteCell(cfg);
  }
}

public Action FogDelay(Handle timer, DataPack pack)
{
  pack.Reset();
  int  client = pack.ReadCell();
  char buffer[1024];
  pack.ReadString(buffer, 1024);
  AbilityData cfg = pack.ReadCell();

  PrepareFog(client, buffer, cfg);

  return Plugin_Continue;
}

public void PrepareFog(int client, const char[] ability_name, AbilityData ability)
{
  char  colors[3][16];
  float distance;
  ability.GetString("blend", colors[0], 16);
  ability.GetString("color1", colors[1], 16);
  ability.GetString("color2", colors[2], 16);
  effectboss = ability.GetInt("effect type", 0);
  distance   = 9999.0;

  if (!StrContains(ability_name, "rage_fog_fx", false))  // add time and proper range if its normal fog
    distance = ability.GetFloat("effect range", 9999.0);

  envFog = CreateFog(colors[0], colors[1], colors[2],
                     ability.GetFloat("fog start", 64.0), ability.GetFloat("fog end", 384.0), ability.GetFloat("fog density", 1.0));

  float pos1[3], pos2[3];
  GetClientAbsOrigin(client, pos1);

  for (int target = 1; target <= MaxClients; target++)
  {
    if (IsValidClient(target))
    {
      GetClientAbsOrigin(target, pos2);
      if (GetVectorDistance(pos1, pos2) <= distance)
      {
        if (FogEffectType(client, target))
        {
          if (!StrContains(ability_name, "rage_fog_fx", false))
          {
            if (IsFogActive)
            {
              fogDuration[target] += ability.GetFloat("duration", 8.0);
            }
            else
            {
              fogDuration[target] = GetGameTime() + ability.GetFloat("duration", 8.0);
              SDKHook(target, SDKHook_PreThinkPost, FogTimer);
            }
          }

          SetVariantString("MyFog");
          AcceptEntityInput(target, "SetFogController");
        }
      }
    }
  }
}

public void FogTimer(int client)
{
  if (GetGameTime() >= fogDuration[client])
  {
    KillFog(envFog);
    IsFogActive = false;
    SDKUnhook(client, SDKHook_PreThinkPost, FogTimer);
    envFog = -1;
  }
}

stock int CreateFog(char[] fogblend, char[] fogcolor1, char[] fogcolor2, float fogstart = 64.0, float fogend = 384.0, float fogdensity = 1.0)
{
  int iFog = CreateEntityByName("env_fog_controller");
  if (IsValidEntity(iFog))
  {
    DispatchKeyValue(iFog, "targetname", "MyFog");
    DispatchKeyValue(iFog, "fogenable", "1");
    DispatchKeyValue(iFog, "spawnflags", "1");
    DispatchKeyValue(iFog, "fogblend", fogblend);
    DispatchKeyValue(iFog, "fogcolor", fogcolor1);
    DispatchKeyValue(iFog, "fogcolor2", fogcolor2);
    DispatchKeyValueFloat(iFog, "fogstart", fogstart);
    DispatchKeyValueFloat(iFog, "fogend", fogend);
    DispatchKeyValueFloat(iFog, "fogmaxdensity", fogdensity);
    DispatchSpawn(iFog);
    AcceptEntityInput(iFog, "TurnOn");
    IsFogActive = true;
  }
  return iFog;
}

stock void KillFog(int iEnt)
{
  if (IsValidEdict(iEnt) && iEnt > MaxClients)
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i))
      {
        SetVariantString("");
        AcceptEntityInput(i, "SetFogController");
      }
    }
    AcceptEntityInput(iEnt, "Kill");
    iEnt        = -1;
    IsFogActive = false;
  }
}

stock bool FogEffectType(int client, int target)
{
  switch (effectboss)
  {
    case 1:  // if target is boss,
    {
      if (client == target)
        return true;
      else return false;
    }
    case 2:  // if target's team same team as boss's team
    {
      if (GetClientTeam(target) == GetClientTeam(client))
        return true;
      else return false;
    }
    case 3:  // if target's team is not same team as boss's team
    {
      if (GetClientTeam(target) != GetClientTeam(client))
        return true;
      else return false;
    }
    case 4:  // if target is not boss
    {
      if (client != target)
        return true;
      else return false;
    }
    default:  // effect everyone
    {
      return true;
    }
  }
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
    return false;

  if (!IsClientInGame(client) || !IsClientConnected(client))
    return false;

  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;

  return true;
}