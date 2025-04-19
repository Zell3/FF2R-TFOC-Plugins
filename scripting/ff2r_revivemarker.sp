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
#include <cfgmap>
#include <ff2r>

#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

bool             MarkerEnable;
int              bossIdx;
bool             IsMarkerLimit;
bool             sound;
float            decaytime;
char             condition[128];
bool             IsBoss[MAXPLAYERS + 1];
int              reviveMarker[MAXPLAYERS + 1];
int              reviveLimit[MAXPLAYERS + 1];

#define MVMINTRO     "music/mvm_class_select.wav"
#define MVMINTRO_VOL 1.0
#define DEATH        "mvm/mvm_player_died.wav"
#define DEATH_VOL    1.0
#define GAMEOVER     "music/mvm_lost_wave.wav"
#define GAMEOVER_VOL 0.85

public Plugin myinfo =
{
  name    = "[FF2R] Standalone Revivemarker",
  author  = "SHADoW93, Zell",
  version = "1.0.1"
};

public void OnPluginStart()
{
  PrecacheSound(MVMINTRO, true);
  PrecacheSound(DEATH, true);
  PrecacheSound(GAMEOVER, true);

  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

public void OnPluginEnd()
{
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);  // for non-arena maps
}

public void OnClientDisconnect(int client)
{
  if (MarkerEnable)
  {
    if (IsValidMarker(reviveMarker[client]))
    {
      RemoveReanimator(client);
      if (reviveLimit[client] > 0)
        reviveLimit[client] = 0;  // Reset revive limit on disconnect
    }
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_revivemarker");
    if (ability.IsMyPlugin())
    {
      HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
      HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);

      MarkerEnable = true;
      bossIdx      = client;                              // Boss index
      decaytime    = ability.GetFloat("lifetime", 60.0);  // Reanimator decay time
      sound        = ability.GetInt("sound", 1) == 1;
      (ability.GetString("condition", condition, sizeof(condition), "81 ; 0.32"));  // Conditions to apply on respawn

      for (int i = 1; i <= MaxClients; i++)
      {
        if (!IsValidClient(i))
          continue;

        if (FF2R_GetBossData(i))
          IsBoss[i] = true;  // Check if the client is a boss

        reviveMarker[i] = -1;  // Reset revive marker

        int limit       = ability.GetInt("limit", 0);
        if (limit > 0)
        {
          IsMarkerLimit  = true;   // Revive limit
          reviveLimit[i] = limit;  // Set revive limit
        }
        else
        {
          IsMarkerLimit  = false;  // No revive limit
          reviveLimit[i] = 0;      // Reset revive limit
        }

        if (sound)
          EmitSoundToClient(i, MVMINTRO, _, _, _, _, MVMINTRO_VOL);

        SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
        ShowHudText(i, -1, "Medics can revive players this round!");
      }
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  if (MarkerEnable)
  {
    UnhookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
    UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
    for (int client = 1; client <= MaxClients; client++)
    {
      IsBoss[client] = false;  // Reset boss check
      if (IsValidMarker(reviveMarker[client]))
      {
        RemoveReanimator(client);
        reviveLimit[client] = 0;  // Reset revive limit on round end
      }
    }
    MarkerEnable  = false;
    IsMarkerLimit = false;  // Reset revive limit
    decaytime     = 0.0;
    sound         = false;
    condition[0]  = '\0';
  }
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!MarkerEnable)
    return;

  int client = GetClientOfUserId(event.GetInt("userid"));

  // check if player is valid
  if (!IsValidClient(client))
    return;

  // remove revive marker if player is revived
  if (IsValidMarker(reviveMarker[client]))
    RemoveReanimator(client);

  // not counting the boss
  if (IsBoss[client])
    return;  // Prevents the boss from being revived by his own team

  // check if player is not same team as the boss
  if (GetClientTeam(client) == GetClientTeam(bossIdx))
    return;

  AddCondition(client, condition);

  // for debug
  // PrintToChat(client, "%i", IsMarkerLimit);
  // PrintToChat(client, "%i", reviveLimit[client]);

  if (!IsMarkerLimit)
    return;  // No revive limit

  reviveLimit[client] -= 1;  // Decrease revive limit

  // for debug
  // PrintToChat(client, "%i", reviveLimit[client]);

  if (reviveLimit[client] < 0)
    reviveLimit[client] = 0;  // Prevent negative revive limit

  if (reviveLimit[client] == 0)
  {
    SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
    ShowHudText(client, -1, "You can no longer be revived!");
    return;
  }

  if (reviveLimit[client] == 1)
  {
    SetHudTextParams(-1.0, 0.67, 4.0, 255, 85, 85, 255);
  }
  else {
    SetHudTextParams(-1.0, 0.67, 4.0, 255, 170, 170, 255);
  }
  ShowHudText(client, -1, "You can be revived %i more times", reviveLimit[client]);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!MarkerEnable)
    return;

  if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    return;  // Prevent a bug with revive markers & dead ringer spies

  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  if (IsBoss[client])
    return;

  if (GetClientTeam(client) == GetClientTeam(bossIdx))
  {
    if (GetClientTeam(bossIdx) == 3)
      ChangeClientTeam(client, 2);  // Change to RED team
    else if (GetClientTeam(bossIdx) == 2)
      ChangeClientTeam(client, 3);  // Change to BLU team
  }

  // check if player reached the revive limit
  if (IsMarkerLimit && reviveLimit[client] <= 0)
  {
    if (sound)
    {
      EmitSoundToClient(client, GAMEOVER, _, _, _, _, GAMEOVER_VOL);
      return;
    }
  }

  DropReanimator(client);
}

stock void DropReanimator(int client)  // Drops a revive marker
{
  int clientTeam       = GetClientTeam(client);
  reviveMarker[client] = CreateEntityByName("entity_revive_marker");

  if (reviveMarker[client] != -1)
  {
    SetEntPropEnt(reviveMarker[client], Prop_Send, "m_hOwner", client);  // client index
    SetEntProp(reviveMarker[client], Prop_Send, "m_nSolidType", 2);
    SetEntProp(reviveMarker[client], Prop_Send, "m_usSolidFlags", 8);
    SetEntProp(reviveMarker[client], Prop_Send, "m_fEffects", 16);
    SetEntProp(reviveMarker[client], Prop_Send, "m_iTeamNum", clientTeam);  // client team
    SetEntProp(reviveMarker[client], Prop_Send, "m_CollisionGroup", 1);
    SetEntProp(reviveMarker[client], Prop_Send, "m_bSimulatedEveryTick", 1);
    SetEntProp(reviveMarker[client], Prop_Send, "m_nBody", view_as<int>(TF2_GetPlayerClass(client)) - 1);
    SetEntProp(reviveMarker[client], Prop_Send, "m_nSequence", 1);
    SetEntPropFloat(reviveMarker[client], Prop_Send, "m_flPlaybackRate", 1.0);
    SetEntProp(reviveMarker[client], Prop_Data, "m_iInitialTeamNum", clientTeam);
    SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, reviveMarker[client]);
    if (GetClientTeam(client) == 3)
      SetEntityRenderColor(reviveMarker[client], 0, 0, 255);  // make the BLU Revive Marker distinguishable from the red one
    DispatchSpawn(reviveMarker[client]);
    CreateTimer(0.1, MoveMarker, client);

    CreateTimer(decaytime, TimeBeforeRemoval, client);
  }

  if (sound)
    EmitSoundToClient(client, DEATH, _, _, _, _, DEATH_VOL);
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
  if (IsValidMarker(reviveMarker[client]))
  {
    AcceptEntityInput(reviveMarker[client], "Kill");
    reviveMarker[client] = -1;
  }
}

public Action MoveMarker(Handle timer, int client)
{
  float position[3];
  GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
  if (IsValidMarker(reviveMarker[client]))
    TeleportEntity(reviveMarker[client], position, NULL_VECTOR, NULL_VECTOR);
  return Plugin_Continue;
}

public Action TimeBeforeRemoval(Handle timer, int client)
{
  if (!IsValidMarker(reviveMarker[client]) || !IsValidClient(client))
    return Plugin_Handled;

  RemoveReanimator(client);
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

stock void AddCondition(int clientIdx, char[] conditions)
{
  if (conditions[0] == '\0')
    return;

  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
    for (int i = 0; i < count; i += 2)
      if (!TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
        TF2_AddCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i + 1]));
}

stock void RemoveCondition(int clientIdx, char[] conditions)
{
  if (conditions[0] == '\0')
    return;

  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
    for (int i = 0; i < count; i += 2)
      if (TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
        TF2_RemoveCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])));
}