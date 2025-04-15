// only adding cvar to enable/disable plugin (i wanna use for my boss plugins lmao)

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.2.0"

ConVar g_hEnabled;  // Add this line
bool   g_bThirdPersonEnabled[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = "[TF2] Thirdperson",
  author      = "DarthNinja Edit by zell",
  description = "Allows players to use thirdperson without having to enable client sv_cheats",
  version     = PLUGIN_VERSION,
  url         = "DarthNinja.com"
};

public OnPluginStart()
{
  CreateConVar("thirdperson_version", PLUGIN_VERSION, "Plugin Version", FCVAR_PLUGIN | FCVAR_NOTIFY);
  g_hEnabled = CreateConVar("thirdperson_enabled", "1", "Enables/Disables this plugin.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
  RegAdminCmd("sm_thirdperson", EnableThirdperson, 0, "Usage: sm_thirdperson");
  RegAdminCmd("tp", EnableThirdperson, 0, "Usage: sm_thirdperson");
  RegAdminCmd("sm_firstperson", DisableThirdperson, 0, "Usage: sm_firstperson");
  RegAdminCmd("fp", DisableThirdperson, 0, "Usage: sm_firstperson");
  HookEvent("player_spawn", OnPlayerSpawned);
  HookEvent("player_class", OnPlayerSpawned);
}

public Action OnPlayerSpawned(Handle event, const char[] name, bool dontBroadcast)
{
  if (!g_hEnabled.BoolValue)
  {
    return Plugin_Handled;
  }

  int userid = GetEventInt(event, "userid");
  if (g_bThirdPersonEnabled[GetClientOfUserId(userid)])
    CreateTimer(0.2, SetViewOnSpawn, userid);

  return Plugin_Continue;
}

public Action SetViewOnSpawn(Handle timer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (client != 0)  // Checked g_bThirdPersonEnabled in hook callback, dont need to do it here~
  {
    SetVariantInt(1);
    AcceptEntityInput(client, "SetForcedTauntCam");
  }
  return Plugin_Continue;
}

public Action EnableThirdperson(int client, args)
{
  if (!g_hEnabled.BoolValue)
  {
    SetVariantInt(0);
    AcceptEntityInput(client, "SetForcedTauntCam");
    PrintToChat(client, "[SM] Thirdperson is currently disabled.");
    return Plugin_Handled;
  }

  if (!IsPlayerAlive(client))
    PrintToChat(client, "[SM] Thirdperson view will be enabled when you spawn.");
  SetVariantInt(1);
  AcceptEntityInput(client, "SetForcedTauntCam");
  g_bThirdPersonEnabled[client] = true;
  return Plugin_Handled;
}

public Action DisableThirdperson(int client, args)
{
  if (!g_hEnabled.BoolValue)
  {
    SetVariantInt(0);
    AcceptEntityInput(client, "SetForcedTauntCam");
    PrintToChat(client, "[SM] Thirdperson is currently disabled.");
    return Plugin_Handled;
  }

  if (!IsPlayerAlive(client))
    PrintToChat(client, "[SM] Thirdperson view disabled!");
  SetVariantInt(0);
  AcceptEntityInput(client, "SetForcedTauntCam");
  g_bThirdPersonEnabled[client] = false;
  return Plugin_Handled;
}

public OnClientDisconnect(int client)
{
  g_bThirdPersonEnabled[client] = false;
}