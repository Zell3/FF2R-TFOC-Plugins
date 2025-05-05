/*
  "special_timer"
  {
    // how this plugin works
    // it will count from max to min or min to max
    // if type is 1, it will count down from max to min
    // if type is 0, it will count up from min to max

    "text" 	      "%s A.M"   // %s = time left
    "min"	        "0"  // minimum time in seconds
    "max"	        "60" // maximum time in seconds
    "type"        "0"  // 1 = count down, 0 = count up
    "position"    "-1.0 0.73" // position
    "rgba"        "255 255 255 255" // remove this line if you want to use like this: green -> yellow -> red

    "trigger"     "0" // what do you do when the time reach limit : 0 = do nothing, 1 = enemy win, 2 = boss win, 3 = stalemate, above that will be do slot.

    "plugin_name"	"ff2r_timer"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <sdktools_functions>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#define FAR_FUTURE 100000000.0
float  Countdown_tick;
Handle HorrorHUD;
char   Horror_Counter[PLATFORM_MAX_PATH];
int    bossId;
int    startTime;
int    endTime;
bool   IsTimerEnabled = false;
bool   countType      = false;  // 0 = count up, 1 = count down
bool   IsStatic;
float  position[2];
int    rgba[4];
int    winType;

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Special Timer",
  author      = "M7, Zell",
  description = "Improve version of the timer plugin",
  version     = "1.0.0",
};

public void OnPluginStart()
{
  IsTimerEnabled = false;
  startTime      = 0;
  endTime        = 0;
  Countdown_tick = FAR_FUTURE;
  HorrorHUD      = null;
  ForceTeamWin();
  HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
  IsTimerEnabled = false;
  startTime      = 0;
  endTime        = 0;
  Countdown_tick = FAR_FUTURE;
  HorrorHUD      = null;
  ForceTeamWin();
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("special_timer");

    if (ability.IsMyPlugin())
    {
      HorrorHUD = CreateHudSynchronizer();
      bossId    = clientIdx;

      if (ability.GetInt("type"))
      {
        countType = true;  // 1 = count down, 0 = count up
        startTime = ability.GetInt("max");
        endTime   = ability.GetInt("min");
      }
      else {
        startTime = ability.GetInt("min");
        endTime   = ability.GetInt("max");
      }

      char positionString[64];
      char temp[2][64];
      ability.GetString("position", positionString, sizeof(positionString), "-1.0 0.73");
      ExplodeString(positionString, " ", temp, sizeof(temp), 64);
      position[0] = StringToFloat(temp[0]);
      position[1] = StringToFloat(temp[1]);

      char color[256];
      char buffer[4][4];
      ability.GetString("rgba", color, sizeof(color));
      if (color[0] != '\0')
      {
        IsStatic = true;

        ExplodeString(color, " ", buffer, sizeof(buffer), sizeof(buffer));
        rgba[0] = StringToInt(buffer[0]);
        rgba[1] = StringToInt(buffer[1]);
        rgba[2] = StringToInt(buffer[2]);
        rgba[3] = StringToInt(buffer[3]);
      }
      else {
        IsStatic = false;
      }

      ability.GetString("text", Horror_Counter, sizeof(Horror_Counter));
      ReplaceString(Horror_Counter, sizeof(Horror_Counter), "\\n", "\n");
      winType        = ability.GetInt("trigger", 0);
      Countdown_tick = GetEngineTime() + 1.0;
      IsTimerEnabled = true;
    }
  }
}

public void OnGameFrame()  // Moving some stuff here and there
{
  if (IsTimerEnabled)
  {
    if (Countdown_tick < GetEngineTime())
    {
      for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
      {
        if (!IsValidClient(clientIdx))
          continue;

        char waveTime[6];

        // this is the time left in the countdown
        if (startTime / 60 > 9)
        {
          IntToString(startTime / 60, waveTime, sizeof(waveTime));
        }
        else {
          Format(waveTime, sizeof(waveTime), "0%i", startTime / 60);
        }

        // this is the seconds left in the countdown
        if (startTime % 60 > 9)
        {
          Format(waveTime, sizeof(waveTime), "%s:%i", waveTime, startTime % 60);
        }
        else {
          Format(waveTime, sizeof(waveTime), "%s:0%i", waveTime, startTime % 60);
        }

        char countdown[PLATFORM_MAX_PATH];
        if (IsStatic)
        {
          SetHudTextParams(position[0], position[1], 1.6, rgba[0], rgba[1], rgba[2], rgba[3]);
        }
        else {
          if (countType)
          {
            if (startTime - endTime < 10)
            {
              SetHudTextParams(position[0], position[1], 1.6, 255, 0, 0, 255);
            }
            else if (startTime - endTime < 20)
            {
              SetHudTextParams(position[0], position[1], 1.6, 255, 255, 0, 255);
            }
            else {
              SetHudTextParams(position[0], position[1], 1.6, 0, 255, 0, 255);
            }
          }
          else
          {
            if (endTime - startTime < 10)
            {
              SetHudTextParams(position[0], position[1], 1.6, 255, 0, 0, 255);
            }
            else if (endTime - startTime < 20)
            {
              SetHudTextParams(position[0], position[1], 1.6, 255, 255, 0, 255);
            }
            else {
              SetHudTextParams(position[0], position[1], 1.6, 0, 255, 0, 255);
            }
          }
        }

        Format(countdown, sizeof(countdown), Horror_Counter, waveTime);
        ShowSyncHudText(clientIdx, HorrorHUD, countdown);
      }

      if (countType)
      {
        startTime--;
        if (startTime < 0)
        {
          IsTimerEnabled = false;
          startTime      = 0;
          endTime        = 0;
          Countdown_tick = FAR_FUTURE;
          HorrorHUD      = null;
          ForceTeamWin();
        }
      }
      else {
        startTime++;
        if (startTime > endTime)
        {
          IsTimerEnabled = false;
          startTime      = 0;
          endTime        = 0;
          Countdown_tick = FAR_FUTURE;
          HorrorHUD      = null;
          ForceTeamWin();
        }
      }

      Countdown_tick = GetEngineTime() + 1.0;
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  if (IsTimerEnabled)
  {
    IsTimerEnabled = false;
    startTime      = 0;
    endTime        = 0;
    Countdown_tick = FAR_FUTURE;
    HorrorHUD      = null;
  }
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

public void ForceTeamWin()
{
  int team = 0;
  if (winType == 0)
  {
    return;
  }
  else if (winType > 3)
  {
    FF2R_DoBossSlot(bossId, winType);
    return;
  }
  else if (winType == 1)
  {
    if (TF2_GetClientTeam(bossId) == TFTeam_Red)
    {
      team = TFTeam_Blue;
    }
    else if (TF2_GetClientTeam(bossId) == TFTeam_Blue)
    {
      team = TFTeam_Red;
    }
  }
  else if (winType == 2)
  {
    team = TF2_GetClientTeam(bossId);
  }
  else if (winType == 3)
  {
    team = 0;
  }

  int ent = FindEntityByClassname(-1, "team_control_point_master");
  if (ent == -1)
  {
    ent = CreateEntityByName("team_control_point_master");
    DispatchSpawn(ent);
    AcceptEntityInput(ent, "Enable");
  }

  SetVariantInt(team);
  AcceptEntityInput(ent, "SetWinner");
}