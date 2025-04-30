/*
  "rage_gentlemen"
  {
    "slot"        "0"		    // Slot

    "duration" 	  "6.0" 		// Duration
    "range"			  "800.0" 	// Range
    "minplayers"	"3"			  // Minimum players that must be in range to activate
    "maxplayers"	"6"			  // Maximum players that can be changed team
    "playerleft"	"1"			  // Number of players that won't be changed if there is no player left in the team

    "message"		  "You are now Gentmen's Henchman"

    "plugin_name"	"ff2r_gentlemen"
  }
*/

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

#define GENTLEMEN_START "replay\\exitperformancemode.wav"
#define GENTLEMEN_EXIT  "replay\\enterperformancemode.wav"

bool isActive = false;
bool isTarget[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = "[FF2R] Gentlemen",
  author      = "Otokiru, 93SHADoW, Zell",
  description = "Standalone Gentlemen plugin for FF2R",
  version     = "1.0.0",
};

public void OnPluginStart()
{
  PrecacheSound(GENTLEMEN_START, true);
  PrecacheSound(GENTLEMEN_EXIT, true);
}

public void FF2R_OnBossRemoved(int client)
{
  isActive = false;
  for (int i = 1; i <= MaxClients; i++)
  {
    isTarget[i] = false;
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_gentlemen", false) && cfg.IsMyPlugin())
  {
    isActive          = true;
    int   counter     = 0;

    // get alive players
    int   alivePlayer = GetAlivePlayersCount(client);

    // arguments
    float duration    = cfg.GetFloat("duration", 5.0);
    float ragedist    = cfg.GetFloat("range", 1000.0);
    int   minplayers  = cfg.GetInt("minplayers", 0);
    int   maxplayers  = cfg.GetInt("maxplayers", 0);
    int   playerleft  = cfg.GetInt("playerleft", 1);

    char  message[256];
    cfg.GetString("message", message, sizeof(message));

    float pos[3], pos2[3];

    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    // get player in range
    for (int i = 1; i <= MaxClients; i++)
    {
      // always reset isTarget[i] to false for not repetitive checks
      isTarget[i] = false;
      if (IsValidLivingClient(i) && GetClientTeam(i) != GetClientTeam(client))
      {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        if (GetVectorDistance(pos, pos2) < ragedist)
        {
          isTarget[i] = true;
          counter++;  // count target
        }
      }
    }

    // if counter is less than minplayers, return
    if (counter < minplayers)
    {
      isActive = false;
      return;
    }

    // then randomly remove players from the target list until the number of players is equal to maxplayers
    while (counter > maxplayers)
    {
      int target = GetRandomInt(1, MaxClients);
      if (isTarget[target])
      {
        isTarget[target] = false;
        counter--;
      }
    }

    // then randomly remove players from the target list if counter is greater or equal alivePlayer
    while (counter > alivePlayer - playerleft)
    {
      int target = GetRandomInt(1, MaxClients);
      if (isTarget[target])
      {
        isTarget[target] = false;
        counter--;
      }
    }

    // then change the team of the target players
    for (int target = 1; target <= MaxClients; target++)
    {
      if (isTarget[target])
      {
        if (!IsNullString(message))
          ShowGameText(target, _, GetClientTeam(client), message, sizeof(message));

        changeTargetTeam(target);
        CreateTimer(duration, turnToDefault, target);
      }
    }

    EmitSoundToAll(GENTLEMEN_START, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, _, NULL_VECTOR, false, 0.0);
  }
}

public Action turnToDefault(Handle timer, int target)
{
  if (!isActive)
    return Plugin_Stop;

  if (IsValidLivingClient(target))
    changeTargetTeam(target);

  isTarget[target] = false;

  return Plugin_Continue;
}

public void changeTargetTeam(int target)
{
  if (!isActive)
    return;

  SetEntProp(target, Prop_Send, "m_lifeState", 2);

  if (TF2_GetClientTeam(target) == TFTeam_Red)
  {
    ChangeClientTeam(target, TFTeam_Blue);
  }
  else if (TF2_GetClientTeam(target) == TFTeam_Blue)
  {
    ChangeClientTeam(target, TFTeam_Red);
  }

  SetEntProp(target, Prop_Send, "m_lifeState", 0);

  if (GetEntProp(target, Prop_Send, "m_bDucked"))
  {
    float collisionvec[3];
    collisionvec[0] = 24.0;
    collisionvec[1] = 24.0;
    collisionvec[2] = 62.0;
    SetEntPropVector(target, Prop_Send, "m_vecMaxs", collisionvec);
    SetEntProp(target, Prop_Send, "m_bDucked", 1);
    SetEntityFlags(target, FL_DUCKING);
  }

  TF2_AddCondition(target, TFCond_Ubercharged, 1.0);
}

stock int GetAlivePlayersCount(int client)
{
  int count = 0;
  for (int i = 1; i <= MaxClients; i++)
    // Check if the client is valid and alive and not the same as the client (boss)
    if (IsValidLivingClient(i) && GetClientTeam(i) != GetClientTeam(client))
      count++;

  return count;
}

stock bool IsValidLivingClient(int client)
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

stock bool ShowGameText(int client, const char[] icon = "leaderboard_streak", int color = 0, const char[] buffer, any...)
{
  BfWrite bf;
  if (!client)
    bf = view_as<BfWrite>(StartMessageAll("HudNotifyCustom"));
  else
    bf = view_as<BfWrite>(StartMessageOne("HudNotifyCustom", client));

  if (bf == null)
    return false;

  static char message[512];
  SetGlobalTransTarget(client);
  VFormat(message, sizeof(message), buffer, 5);
  ReplaceString(message, sizeof(message), "\n", "");

  bf.WriteString(message);
  bf.WriteString(icon);
  bf.WriteByte(color);
  EndMessage();
  return true;
}