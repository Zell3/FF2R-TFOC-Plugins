/*
  "funeral_of_the_dead_butterfly"
  {
    "plugin_name"	"ff2r_funeral"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define FUNERAL_OVERLAY    "draqz/ff2/funeral/overlay"
#define FUNERAL_GLOW_COLOR { 255, 255, 255, 255 }  // White glow color
public Plugin myinfo =
{
  name        = "Funeral of Dead Butterfly Abilities",
  author      = "Zell",
  description = "applies screen overlay and glow on marked player, insta-kills if hit on marked player",
  version     = "1.0.0",
};

bool bIsFuneralRound;
bool bIsUnderOverlay[MAXPLAYERS + 1];
int  iPlayerGlowEntity[MAXPLAYERS + 1];

public void OnPluginStart()
{
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
  }
}

public void OnPluginEnd()
{
  UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
  }
}

public void OnClientPutInServer(int client)
{
  if (IsClientInGame(client))
  {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
    if (cfg.GetAbility("funeral_of_the_dead_butterfly").IsMyPlugin())
      bIsFuneralRound = true;
}

public void FF2R_OnBossRemoved(int client)
{
  if (bIsFuneralRound)
  {
    bIsFuneralRound = false;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i))
      {
        bIsUnderOverlay[i] = false;
        RemoveOverlay(i);  // Remove the overlay from the player
        SDKUnhook(i, SDKHook_PreThink, OnPlayerThink);
      }
    }

    // Remove all glow entities created by this plugin
    int index = -1;
    while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
    {
      char strName[64];
      GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
      if (StrEqual(strName, "whiteGlow"))
        AcceptEntityInput(index, "Kill");
    }
  }
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
  if (!bIsFuneralRound)
    return;

  if (!IsValidClient(client) || !IsPlayerAlive(client))
    return;

  if (FF2R_GetBossData(client).GetAbility("funeral_of_the_dead_butterfly").IsMyPlugin())
    return;

  if (condition == TFCond_MarkedForDeath)
  {
    if (!TF2_HasGlow(client))
    {
      int iGlow = TF2_CreateGlow(client);
      if (IsValidEntity(iGlow))
      {
        iPlayerGlowEntity[client] = EntIndexToEntRef(iGlow);
        bIsUnderOverlay[client]   = true;
        SDKHook(client, SDKHook_PreThink, OnPlayerThink);
      }
    }
  }
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
  if (!bIsFuneralRound)
    return;

  if (!IsValidClient(client) || !IsPlayerAlive(client))
    return;

  if (FF2R_GetBossData(client).GetAbility("funeral_of_the_dead_butterfly").IsMyPlugin())
    return;

  if (condition == TFCond_MarkedForDeath)
  {
    SDKUnhook(client, SDKHook_PreThink, OnPlayerThink);
    int iGlow = EntRefToEntIndex(iPlayerGlowEntity[client]);
    if (iGlow != INVALID_ENT_REFERENCE)
    {
      AcceptEntityInput(iGlow, "Kill");
      iPlayerGlowEntity[client] = INVALID_ENT_REFERENCE;
      bIsUnderOverlay[client]   = false;
      RemoveOverlay(client);
    }
  }
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  if (!IsValidClient(attacker) || !IsValidClient(victim))
    return Plugin_Continue;

  if (!IsPlayerAlive(attacker) || !IsPlayerAlive(victim))
    return Plugin_Continue;

  if (!bIsFuneralRound)
    return Plugin_Continue;

  if (FF2R_GetBossData(attacker).GetAbility("funeral_of_the_dead_butterfly").IsMyPlugin())
  {
    if (attacker != victim)
      if (TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeath))
        FakeClientCommand(victim, "kill");
  }
  return Plugin_Continue;
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));

  if (!IsValidClient(client))  // Check if the client is valid and alive
    return Plugin_Continue;    // If not, do nothing

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return Plugin_Continue;  // Prevent a bug with revive markers & dead ringer spies

  if (bIsFuneralRound)
  {
    SDKUnhook(client, SDKHook_PreThink, OnPlayerThink);
    if (TF2_HasGlow(client))  // Check if the client has a glow effect
    {
      int iGlow = EntRefToEntIndex(iPlayerGlowEntity[client]);
      if (iGlow != INVALID_ENT_REFERENCE)
      {
        AcceptEntityInput(iGlow, "Kill");
        iPlayerGlowEntity[client] = INVALID_ENT_REFERENCE;
      }
    }

    if (bIsUnderOverlay[client])  // Check if the client is under an overlay
    {
      bIsUnderOverlay[client] = false;
      RemoveOverlay(client);  // Remove the overlay from the player
    }
  }

  return Plugin_Continue;  // Continue the event
}

public Action OnPlayerThink(int client)
{
  if (!IsValidClient(client))
    return Plugin_Continue;

  if (!bIsFuneralRound)
    return Plugin_Continue;

  int iGlow = EntRefToEntIndex(iPlayerGlowEntity[client]);

  if (iGlow != INVALID_ENT_REFERENCE)
  {
    SetVariantColor(FUNERAL_GLOW_COLOR);
    AcceptEntityInput(iGlow, "SetGlowColor");
  }

  if (bIsUnderOverlay[client])
  {
    CreateOverlay(client);
  }

  return Plugin_Continue;
}

// Overlay effect
public void CreateOverlay(int client)
{
  if (IsValidClient(client))
  {
    char overlay[PLATFORM_MAX_PATH];
    Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", FUNERAL_OVERLAY);
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
    ClientCommand(client, overlay);  // Set the screen overlay for the target
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
  }
}

public void RemoveOverlay(int client)
{
  if (IsValidClient(client))
  {
    char overlay[PLATFORM_MAX_PATH];
    Format(overlay, sizeof(overlay), "r_screenoverlay \"\"");
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
    ClientCommand(client, overlay);  // Remove the screen overlay for the target
    SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
  }
}

// credit to Pelipoika for this glow function
// "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
stock int TF2_CreateGlow(int iEnt)
{
  char oldEntName[64];
  GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));

  char strName[126], strClass[64];
  GetEntityClassname(iEnt, strClass, sizeof(strClass));
  Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
  DispatchKeyValue(iEnt, "targetname", strName);

  int ent = CreateEntityByName("tf_glow");
  DispatchKeyValue(ent, "targetname", "whiteGlow");  // just change from rainbow glow to glow
  DispatchKeyValue(ent, "target", strName);
  DispatchKeyValue(ent, "Mode", "0");
  DispatchSpawn(ent);

  AcceptEntityInput(ent, "Enable");

  // Change name back to old name because we don't need it anymore.
  SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);

  return ent;
}

stock bool TF2_HasGlow(int iEnt)
{
  int index = -1;
  while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
    if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
      return true;
  return false;
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