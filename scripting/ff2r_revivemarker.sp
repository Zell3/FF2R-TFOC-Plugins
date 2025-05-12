/*

// in case you want to make duo or trio boss, only one of them can have this ability
"special_revivemarker"
{
  "lifetime"	    "45.0"	//  Marker Lifetime
  "limit"		    "3"	    //  Player Revive Limit // 0 = No Limit or just remove this line
  "condition"     "33 ; 3"      //  Player Conditions When Respawn
  "sound"		    "1"	    //  Play MvM Sounds

  "plugin_name"	"ff2r_revivemarker"
}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME        "[FF2R] Standalone Revivemarker"
#define PLUGIN_AUTHOR      "SHADoW93, Zell"
#define PLUGIN_VERSION     "1.0.1"
#define PLUGIN_DESCRIPTION "Adds MvM-style revive markers for FF2R"

// Constants
#define INACTIVE_TIMER     100000000.0
#define HUD_X_POS          -1.0
#define HUD_Y_POS          0.67
#define HUD_DISPLAY_TIME   4.0

// Sound constants
enum struct SoundInfo
{
  char  path[PLATFORM_MAX_PATH];
  float volume;
}

static const SoundInfo g_SoundData[] = {
  {"music/mvm_class_select.wav", 1.0 }, // SOUND_INTRO
  { "mvm/mvm_player_died.wav",   1.0 }, // SOUND_DEATH
  { "music/mvm_lost_wave.wav",   0.85}  // SOUND_GAMEOVER
};

// Plugin state
enum struct PluginState
{
  bool  enabled;
  bool  limitEnabled;
  bool  soundEnabled;
  int   bossIndex;
  float decayTime;
  char  conditions[128];
}
static PluginState g_State;

// Per-player data
enum struct PlayerData
{
  bool  isBoss;
  int   reviveMarker;
  int   reviveLimit;
  float markerTimer;
}
static PlayerData g_Players[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTHOR,
  version     = PLUGIN_VERSION,
  description = PLUGIN_DESCRIPTION,
  url         = ""
};

public void OnPluginStart()
{
  g_State.enabled      = false;
  g_State.limitEnabled = false;
  g_State.bossIndex    = -1;
  g_State.decayTime    = 0.0;

  // this for remove the revive marker when revived
  HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
  // HookEvent("post_inventory_application", Event_OnPlayerSpawn, EventHookMode_Pre);

  // this for adding the revive marker when dead
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);

  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

public void OnMapStart()
{
  // Precache sounds
  for (int i = 0; i < sizeof(g_SoundData); i++)
  {
    PrecacheSound(g_SoundData[i].path, true);
  }
}

public void OnPluginEnd()
{
  g_State.enabled      = false;
  g_State.limitEnabled = false;
  g_State.bossIndex    = -1;
  g_State.decayTime    = 0.0;

  // Unhook events
  UnhookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
  // UnhookEvent("post_inventory_application", Event_OnPlayerSpawn, EventHookMode_Pre);

  UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

public void OnClientDisconnect(int client)
{
  InitializePlayer(client);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_revivemarker");
    if (ability.IsMyPlugin())
    {
      g_State.enabled      = true;    // Enable revive marker
      g_State.bossIndex    = client;  // Set the boss index

      g_State.decayTime    = ability.GetFloat("lifetime", 60.0);  // Reanimator decay time
      g_State.soundEnabled = ability.GetInt("sound", 1) == 1;

      // Fix the condition string parsing
      char tempConditions[128];
      ability.GetString("condition", tempConditions, sizeof(tempConditions), "81 ; 0.32");
      strcopy(g_State.conditions, sizeof(g_State.conditions), tempConditions);

      int limit = ability.GetInt("limit", 0);

      for (int i = 1; i <= MaxClients; i++)
      {
        if (!IsValidClient(i))
          continue;

        if (FF2R_GetBossData(i))
          g_Players[i].isBoss = true;  // Check if the client is a boss

        g_Players[i].reviveMarker = -1;  // Reset revive marker

        if (limit > 0)
        {
          g_State.limitEnabled     = true;   // Revive limit
          g_Players[i].reviveLimit = limit;  // Set revive limit
        }
        else
        {
          g_State.limitEnabled     = false;  // No revive limit
          g_Players[i].reviveLimit = 0;      // Reset revive limit
        }

        if (g_State.soundEnabled)
          EmitSoundToClient(i, g_SoundData[0].path, _, _, _, _, g_SoundData[0].volume);

        SetHudTextParams(HUD_X_POS, HUD_Y_POS, HUD_DISPLAY_TIME, 255, 0, 0, 255);
        ShowHudText(i, -1, "Medics can revive players this round!");
      }
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    InitializePlayer(client);
  }
  g_State.bossIndex     = -1;  // Reset boss index
  g_State.enabled       = false;
  g_State.limitEnabled  = false;  // Reset revive limit
  g_State.decayTime     = 0.0;
  g_State.soundEnabled  = false;
  g_State.conditions[0] = '\0';
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!g_State.enabled)
    return;

  int client = GetClientOfUserId(event.GetInt("userid"));

  // check if player is valid
  if (!IsValidClient(client))
    return;

  // not counting the boss
  if (g_Players[client].isBoss)
    return;  // Prevents the boss from being revived by his own team

  // if post_inventory_application was called but no revive marker was created, return
  if (!IsValidMarker(g_Players[client].reviveMarker))
  {
    return;
  }

  RemoveReanimator(client);

  // check if player is not same team as the boss (handle summoned minions) so they don't count as revives
  if (TF2_GetClientTeam(client) == TF2_GetClientTeam(g_State.bossIndex))
    return;

  //  PrintToChatAll("Player %N has been revived! with conditions: %s", client, g_State.conditions);  // Print to chat that the player has been revived with conditions
  AddCondition(client, g_State.conditions); // Add conditions to the player

  if (!g_State.limitEnabled)
    return;  // No revive limit

  g_Players[client].reviveLimit -= 1;  // Decrease revive limit

  if (g_Players[client].reviveLimit < 0)
    g_Players[client].reviveLimit = 0;  // Prevent negative revive limit

  ShowReviveMessage(client, g_Players[client].reviveLimit);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!g_State.enabled)
    return;

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return;  // Prevent a bug with revive markers & dead ringer spies

  int client = GetClientOfUserId(GetEventInt(event, "userid"));

  // Return if client is invalid or is a boss
  if (!IsValidClient(client) || g_Players[client].isBoss)
    return;

  // Force players to opposite team of boss if they're on same team
  if (TF2_GetClientTeam(client) == TF2_GetClientTeam(g_State.bossIndex))
  {
    if (TF2_GetClientTeam(g_State.bossIndex) == TFTeam_Blue)
      ChangeClientTeam(client, view_as<int>(TFTeam_Red));
    else
      ChangeClientTeam(client, view_as<int>(TFTeam_Blue));
  }

  // Check revive limit
  if (g_State.limitEnabled && g_Players[client].reviveLimit <= 0)
  {
    if (g_State.soundEnabled)
    {
      EmitSoundToClient(client, g_SoundData[2].path, _, _, _, _, g_SoundData[2].volume);
      return;
    }
  }

  DropReanimator(client);
}

stock void DropReanimator(int client)  // Drops a revive marker
{
  TFTeam clientTeam              = TF2_GetClientTeam(client);
  g_Players[client].reviveMarker = CreateEntityByName("entity_revive_marker");

  if (g_Players[client].reviveMarker == -1)
    return;  // Failed to create the revive marker

  SetEntPropEnt(g_Players[client].reviveMarker, Prop_Send, "m_hOwner", client);  // client index
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_nSolidType", 2);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_usSolidFlags", 8);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_fEffects", 16);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_iTeamNum", clientTeam);  // client team
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_CollisionGroup", 1);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_bSimulatedEveryTick", 1);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_nBody", view_as<int>(TF2_GetPlayerClass(client)) - 1);
  SetEntProp(g_Players[client].reviveMarker, Prop_Send, "m_nSequence", 1);
  SetEntPropFloat(g_Players[client].reviveMarker, Prop_Send, "m_flPlaybackRate", 1.0);
  SetEntProp(g_Players[client].reviveMarker, Prop_Data, "m_iInitialTeamNum", clientTeam);
  SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, g_Players[client].reviveMarker);

  if (TF2_GetClientTeam(client) == TFTeam_Blue)
    SetEntityRenderColor(g_Players[client].reviveMarker, 0, 0, 255);  // make the BLU Revive Marker distinguishable from the red one

  g_Players[client].markerTimer = GetEngineTime() + g_State.decayTime;  // Set the timer to the current time + 0.1 seconds
  DispatchSpawn(g_Players[client].reviveMarker);
  MoveMarker(client);                                 // Move the revive marker to the player position
  SDKHook(client, SDKHook_PreThink, MarkerPrethink);  // Hook the revive marker to move with the player

  if (g_State.soundEnabled)
    EmitSoundToClient(client, g_SoundData[1].path, _, _, _, _, g_SoundData[1].volume);
}

public void MarkerPrethink(int client)
{
  if (g_Players[client].markerTimer < GetEngineTime() || g_Players[client].markerTimer == INACTIVE_TIMER)
  {
    RemoveReanimator(client);
    g_Players[client].markerTimer = INACTIVE_TIMER;       // Set the timer to inactive
    SDKUnhook(client, SDKHook_PreThink, MarkerPrethink);  // Unhook the revive marker
  }
}

stock bool IsValidMarker(int marker)  // Checks if revive marker is a valid entity.
{
  if (IsValidEntity(marker))
  {
    char buffer[128];
    GetEntityClassname(marker, buffer, sizeof(buffer));
    if (strcmp(buffer, "entity_revive_marker", false) == 0)
      return true;
  }
  return false;
}

stock void RemoveReanimator(int client)  // Removes a revive marker
{
  if (IsValidMarker(g_Players[client].reviveMarker))
  {
    AcceptEntityInput(g_Players[client].reviveMarker, "Kill");
    g_Players[client].reviveMarker = -1;
  }
}

public void MoveMarker(int client)
{
    float position[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
    
    // Add vertical offset (48.0 units is approximately player torso height)
    position[2] += 48.0;
    
    if (IsValidMarker(g_Players[client].reviveMarker))
        TeleportEntity(g_Players[client].reviveMarker, position, NULL_VECTOR, NULL_VECTOR);
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

static void InitializePlayer(int client, int reviveLimit = 0)
{
  g_Players[client].isBoss       = false;
  g_Players[client].reviveMarker = -1;
  g_Players[client].reviveLimit  = reviveLimit;
  g_Players[client].markerTimer  = INACTIVE_TIMER;
}

static void ShowReviveMessage(int client, int revivesLeft)
{
  int r, g;
  if (revivesLeft == 0)
  {
    r = 255;
    g = 0;
    // Set params before showing text
    SetHudTextParams(HUD_X_POS, HUD_Y_POS, HUD_DISPLAY_TIME, r, g, 0, 255);
    ShowHudText(client, -1, "You can no longer be revived!");
  }
  else {
    r = revivesLeft == 1 ? 255 : 255;
    g = revivesLeft == 1 ? 85 : 170;
    // Set params before showing text
    SetHudTextParams(HUD_X_POS, HUD_Y_POS, HUD_DISPLAY_TIME, r, g, 0, 255);
    ShowHudText(client, -1, "You can be revived %i more times", revivesLeft);
  }
}

stock void AddCondition(int clientIdx, char[] conditions)
{
  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  // PrintToChatAll("Adding conditions to %N: %s", clientIdx, conditions);  // Print to chat that the conditions are being added
  if (count > 0)
  {
    for (int i = 0; i < count; i += 2)
    {
      if (!TF2_IsPlayerInCondition(clientIdx, StringToInt(conds[i])))
      {
        TF2_AddCondition(clientIdx, StringToInt(conds[i]), StringToFloat(conds[i + 1]));
        // if view_as<TFCond> and plugin doesn't work then use this line instead
        // TF2_AddCondition(clientIdx, StringToInt(conds[i]), StringToFloat(conds[i + 1]));

        // PrintToChatAll("Added condition %i to %N for %f seconds", StringToInt(conds[i]), clientIdx, StringToFloat(conds[i + 1]));  // Print to chat that the condition was added
      }
    }
  }
}