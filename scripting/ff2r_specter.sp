/*
   "rage_specter"
  {
    "duration" 		"6.0" 		// Duration
    "range"			"800.0" 	// Range (leave blank to use default)
    "message"		"You are now Gentmen's Henchman"
    "lastman"		"true"			// prevent to change all player team if they no more player left in their team : true = yes false = no
    "playerleft"	"3"			// how many player won't get team change (needed when lastman = true : default = 1)

    "plugin_name"	"ff2r_specter"	// Plugin Name
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
int  clientTeam;
int  bossTeam;
bool isTarget[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = "[FF2R] Specter",
  author      = "Zell",
  description = "for Specter",
  version     = "1.0.0",
  url         = ""
};

public void OnPluginStart()
{
  isActive = false;
  HookEvent("player_death", PlayerDeath);
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

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client) && FF2R_GetBossData(client))
    {
      isActive = false;
      FF2R_OnBossRemoved(client);
    }
  }
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!isActive)
    return;
  if (!IsValidClient(client))
    return;
  if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)  // Dead Ringer spies
    return;
  if (isTarget[client])
  {
    isTarget[client] = false;
    ChangeClientTeam(client, clientTeam);
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("rage_specter");
    if (ability.IsMyPlugin())
    {
      isActive   = true;
      bossTeam   = GetClientTeam(client);
      clientTeam = (bossTeam == (view_as<int>(TFTeam_Blue)) ? (view_as<int>(TFTeam_Red)) : (view_as<int>(TFTeam_Blue)))
        PrecacheSound(GENTLEMEN_START, true);
      PrecacheSound(GENTLEMEN_EXIT, true);
    }
  }
}

public void FF2R_OnBossRemoved(int client)
{
  isActive = false;
  for (int i = 1; i < MaxClients; i++)
  {
    isTarget[i] = false;
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_specter", false) && cfg.IsMyPlugin())
  {
    if (!IsValidLivingClient(client))
      return;
    if (!isActive)
      return;

    int   alivePlayer = 0;
    int   counter     = 0;
    int   playerleft  = 0;

    float pos[3], pos2[3];

    float duration = cfg.GetFloat("duration", 5.0);
    float ragedist = cfg.GetFloat("range", 1000.0);
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
    char message[256];
    cfg.GetString("message", message, sizeof(message));
    bool lastman = cfg.GetBool("lastman", true);
    int  limit   = cfg.GetInt("playerleft", 1);

    PrintToChatAll("counter %d playeralive %d", counter, alivePlayer);

    // get player in range
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidLivingClient(i) && GetClientTeam(i) == clientTeam)
      {
        alivePlayer++;  // count player alive
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        if (GetVectorDistance(pos, pos2) < ragedist && !TF2_IsPlayerInCondition(i, TFCond_Ubercharged))
        {
          isTarget[i] = true;
          counter++;  // count target
          PrintToChatAll("client %d count %d", i, counter);
        }
      }
    }

    // no one in range or no player alive
    if (counter == 0 || alivePlayer == 0)
      return;

    if (counter == alivePlayer && lastman)
    {
      PrintToChatAll("counter %d playeralive %d", counter, alivePlayer);
      while (playerleft < alivePlayer)
      {
        int pl = GetRandomInt(1, MaxClients);
        if (isTarget[pl])
        {
          isTarget[pl] = false;
          playerleft++
        }

        if (limit >= alivePlayer && playerleft == alivePlayer - 2)
          break;
      }
      counter = 0;
    }

    for (int target = 1; target <= MaxClients; target++)
    {
      if (!IsValidClient(target))
        return;
      if (!isTarget[target])
        return;

      changeTargetTeam(target, bossTeam);
      if (!IsNullString(message))
        ShowGameText(target, _, bossTeam, message, sizeof(message));
      CreateTimer(duration, turnToDefault, target);
    }
    EmitSoundToAll(GENTLEMEN_START, _, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, _, NULL_VECTOR, false, 0.0);
  }
}

public void changeTargetTeam(int target, int team)
{
  if (!isActive)
    return;

  SetEntProp(target, Prop_Send, "m_lifeState", 2);
  ChangeClientTeam(target, team);
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

public Action turnToDefault(Handle timer, int target)
{
  if (!isActive)
    return Plugin_Stop;

  if (IsValidLivingClient(target))
    changeTargetTeam(target, clientTeam);

  isTarget[target] = false;

  return Plugin_Continue;
}

stock bool IsValidLivingClient(int client)  // Checks if a client is a valid living one.
{
  if (client <= 0 || client > MaxClients) return false;
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