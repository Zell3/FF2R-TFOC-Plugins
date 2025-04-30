/*
  "special_mann_up_lines"	// Ability name can use suffixes
  {
    "plugin_name"	"mann_up_abilities"	// Plugin Name
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
//#include "freak_fortress_2/formula_parser.sp"
#pragma semicolon 1
#pragma newdecls required

/**
 * If you want to use formula to your ability, uncomment this.
 * This file provides ParseFormula functions.
 */
//#include "freak_fortress_2/formula_parser.sp"

/**
 * After 2023-07-25 Update, we don't need to set 36.
 */
//#define MAXTF2PLAYERS MAXPLAYERS + 1

#define MANNUP_LINES "special_mann_up_lines"
bool              BossWinner      = false;

// Level Up Enabled Indicator
static const char MannUpStart[][] = {
  "vo/mvm_mann_up_mode01.mp3",
  "vo/mvm_mann_up_mode02.mp3",
  "vo/mvm_mann_up_mode03.mp3",
  "vo/mvm_mann_up_mode04.mp3",
  "vo/mvm_mann_up_mode05.mp3",
  "vo/mvm_mann_up_mode06.mp3",
  "vo/mvm_mann_up_mode07.mp3",
  "vo/mvm_mann_up_mode08.mp3",
  "vo/mvm_mann_up_mode09.mp3",
  "vo/mvm_mann_up_mode10.mp3",
  "vo/mvm_mann_up_mode11.mp3",
  "vo/mvm_mann_up_mode12.mp3",
  "vo/mvm_mann_up_mode13.mp3",
  "vo/mvm_mann_up_mode14.mp3",
  "vo/mvm_mann_up_mode15.mp3"
};

// Round Result
static const char BossIsDefeated[][] = {
  "vo/mvm_manned_up01.mp3",
  "vo/mvm_manned_up02.mp3",
  "vo/mvm_manned_up03.mp3"
};

static const char BossIsVictorious[][] = {
  "vo/mvm_game_over_loss01.mp3",
  "vo/mvm_game_over_loss02.mp3",
  "vo/mvm_game_over_loss03.mp3",
  "vo/mvm_game_over_loss04.mp3",
  "vo/mvm_game_over_loss05.mp3",
  "vo/mvm_game_over_loss06.mp3",
  "vo/mvm_game_over_loss07.mp3",
  "vo/mvm_game_over_loss08.mp3",
  "vo/mvm_game_over_loss09.mp3",
  "vo/mvm_game_over_loss10.mp3",
  "vo/mvm_game_over_loss11.mp3"
};

/**
 * Original author is J0BL3SS. But he is retired and privatize all his plugins.
 *
 * Your plugin's info. Fill it.
 */
public Plugin myinfo =
{
  name        = "[FF2R] Mannup Ability",
  author      = "zell inspired M7",
  description = "",
  version     = "1.0.1",
  url         = ""
};

public void OnPluginStart()
{
  HookEvent("arena_round_start", OnRoundStart);
  HookEvent("arena_win_panel", OnRoundEnd);
  HookEvent("player_death", OnPlayerDeath);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
  PrepareAbilities();
  char sound[256];
  // Manning Up & Round Result Lines
  for (int i = 0; i < 15; i++)
  {
    strcopy(sound, sizeof(MannUpStart[]), MannUpStart[i]);
    PrecacheSound(sound, true);
  }
  for (int i = 0; i < 3; i++)
  {
    strcopy(sound, sizeof(BossIsDefeated[]), BossIsDefeated[i]);
    PrecacheSound(sound, true);
  }
  for (int i = 0; i < 11; i++)
  {
    strcopy(sound, sizeof(BossIsVictorious[]), BossIsVictorious[i]);
    PrecacheSound(sound, true);
  }
}

public void PrepareAbilities()
{
  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsClientInGame(clientIdx))
    {
      BossData cfg = FF2R_GetBossData(clientIdx);
      if (cfg)
      {
        AbilityData ability = cfg.GetAbility("special_mann_up_lines");
        if (ability.IsMyPlugin())
          CreateTimer(6.0, AnnouncerIsReady, clientIdx, TIMER_FLAG_NO_MAPCHANGE);
      }
    }
  }
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsClientInGame(clientIdx))
    {
      BossData cfg = FF2R_GetBossData(clientIdx);
      if (cfg)
      {
        AbilityData ability = cfg.GetAbility("special_mann_up_lines");
        if (ability.IsMyPlugin())
        {
          int boss_team = GetClientTeam(clientIdx);
          if (GetEventInt(event, "winning_team") == boss_team)
            BossWinner = true;
          else if (GetEventInt(event, "winning_team") == ((boss_team == view_as<int>(TFTeam_Blue)) ? (view_as<int>(TFTeam_Red)) : (view_as<int>(TFTeam_Blue))))
            BossWinner = false;
          CreateTimer(5.0, WinnerIsAnnounced, clientIdx, TIMER_FLAG_NO_MAPCHANGE);
        }
      }
    }
  }
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
  {
    return Plugin_Continue;
  }
  return Plugin_Continue;
}

public Action AnnouncerIsReady(Handle timer, int clientIdx)
{
  char Alert[PLATFORM_MAX_PATH];
  strcopy(Alert, PLATFORM_MAX_PATH, MannUpStart[GetRandomInt(0, 14)]);
  EmitSoundToAll(Alert);
  return Plugin_Continue;
}

public Action WinnerIsAnnounced(Handle timer, int clientIdx)
{
  char RoundResult[PLATFORM_MAX_PATH];
  if (BossWinner)
    strcopy(RoundResult, PLATFORM_MAX_PATH, BossIsVictorious[GetRandomInt(0, 10)]);
  else
    strcopy(RoundResult, PLATFORM_MAX_PATH, BossIsDefeated[GetRandomInt(0, 2)]);
  EmitSoundToAll(RoundResult);
  BossWinner = false;
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