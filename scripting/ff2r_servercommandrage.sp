// "rage_servercommand"
// {
//
//     "range"            "400"             // Range            (Range of effect of server command, only applicable if arg7 = 0)
//     "duration"            "7"              // Duration            (Duration in seconds between server commands. Set to 0 if not using arg5 and arg6)
//     "startcommand"            "sm_blind"    // Server Command Start            (Server command executed at start of duration)
//     "startparam"            "250"    // Optional Server Command Start Parameter             (Server command parameter used with arg3, if applicable)
//     "endcommand"            "sm_blind"    // Server Command End            (Server command executed at end of duration)
//     "endparam"            "0"    // Optional Server Command End Parameter            (Server command parameter used with arg5, if applicable)
//     "mode"            "0"   // Mode  (Use '0' for commands that are executed by the server on players (e.g. sm_blind), '1' for commands that affect the whole server (e.g. sv_gravity), '2' to execute the command on the Boss only, '3' to make the Boss execute the command.)
//     "plugin_name"     "ff2_servercommandrage"
// }

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "[FF2R] ServerCommandRage",
  author      = "frog",
  description = "rewrite version of servercommandrage",
  version     = "1.0.0",
  url         = ""
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_servercommand", false) && cfg.IsMyPlugin())
  {
    Rage_ServerCommand(client, ability, cfg);
  }
}

public void Rage_ServerCommand(int client, const char[] ability_name, AbilityData cfg)
{
  float ragedistance = cfg.GetFloat("distance", 800.0);
  float rageduration = cfg.GetFloat("duration", 5.0);
  char  startcommand[256];
  cfg.GetString("startcommand", startcommand, sizeof(startcommand));
  char startparam[256];
  cfg.GetString("startparam", startparam, sizeof(startparam));
  char endcommand[256];
  cfg.GetString("endcommand", endcommand, sizeof(endcommand));
  char endparam[256];
  cfg.GetString("endparam", endparam, sizeof(endparam));
  int   mode = cfg.GetInt("mode");

  float pos[3];
  float pos2[3];
  float distance;

  float vel[3];
  vel[2] = 20.0;
  TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

  if (mode == 0)
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (i != client && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
      {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
        distance = GetVectorDistance(pos, pos2);
        if (distance < ragedistance)
        {
          ServerCommand("%s #%i %s", startcommand, GetClientUserId(i), startparam);
          if (rageduration)
          {
            Handle pack = CreateDataPack();
            CreateTimer(rageduration, EndCommand_Timer, pack);
            WritePackCell(pack, i);
            WritePackString(pack, endcommand);
            WritePackString(pack, endparam);
            ResetPack(pack);
          }
        }
      }
    }
  }
  else if (mode == 1)
  {
    ServerCommand("%s", startcommand);
    Handle pack = CreateDataPack();
    CreateDataTimer(rageduration, EndCommandGlobal, pack);
    WritePackString(pack, endcommand);
    WritePackString(pack, endparam);
    ResetPack(pack);
  }
  else if (mode == 2)
  {
    ServerCommand("%s #%i %s", startcommand, GetClientUserId(client), startparam);
    if (rageduration)
    {
      Handle pack = CreateDataPack();
      CreateDataTimer(rageduration, EndCommand_Timer, pack);
      WritePackCell(pack, client);
      WritePackString(pack, endcommand);
      WritePackString(pack, endparam);
      ResetPack(pack);
    }
  }
  else if (mode == 3)
  {
    FakeClientCommand(client, "%s %s", startcommand, startparam);
    if (rageduration)
    {
      Handle pack = CreateDataPack();
      CreateDataTimer(rageduration, EndCommandBoss_Timer, pack);
      WritePackCell(pack, client);
      WritePackString(pack, endcommand);
      WritePackString(pack, endparam);
      ResetPack(pack);
    }
  }
}

public Action EndCommandGlobal(Handle timer, Handle pack)
{
  ResetPack(pack);
  char endcommand[PLATFORM_MAX_PATH];
  ReadPackString(pack, endcommand, sizeof(endcommand));
  char endparam[PLATFORM_MAX_PATH];
  ReadPackString(pack, endparam, sizeof(endparam));
  ServerCommand("%s %s", endcommand, endparam);
  return Plugin_Continue;
}

public Action EndCommandBoss_Timer(Handle timer, Handle pack)
{
  ResetPack(pack);
  int  Boss = ReadPackCell(pack);
  char endcommand[PLATFORM_MAX_PATH];
  ReadPackString(pack, endcommand, sizeof(endcommand));
  char endparam[PLATFORM_MAX_PATH];
  ReadPackString(pack, endparam, sizeof(endparam));

  if (IsClientInGame(Boss))
  {
    FakeClientCommand(GetClientUserId(Boss), "%s %s", endcommand, endparam);
  }
  return Plugin_Continue;
}

public Action EndCommand_Timer(Handle timer, Handle pack)
{
  ResetPack(pack);
  int  client = ReadPackCell(pack);
  char endcommand[PLATFORM_MAX_PATH];
  ReadPackString(pack, endcommand, sizeof(endcommand));
  char endparam[PLATFORM_MAX_PATH];
  ReadPackString(pack, endparam, sizeof(endparam));

  if (IsClientInGame(client))
  {
    ServerCommand("%s #%i %s", endcommand, GetClientUserId(client), endparam);
  }
  return Plugin_Continue;
}