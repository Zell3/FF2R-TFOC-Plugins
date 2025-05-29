/*
  // Print To Chat
  "rage_chattext"		//Ability name can use suffixes
  {
    "slot"			"0"								// Ability Slot
    "message"		"{purple}I am Gay!" // Message to be printed
    "target" "3" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"	"ff2r_chat"		// this subplugin name
  }

  // Print To Center Of Screen
  "rage_hudtext"   //Ability name can use suffixes
  {
    "slot"         "0"                             // Ability Slot
    "message"		"I am Gay!" // Message to be printed
    "params"    "-1.0, 0.25, 3.0, 255, 255, 255, 255, 1"  // if you know how to cook this just use it, if not just leave it as is or remove this line (also beware about the commas)
    "target" "3" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"  "ff2r_chat"        // this subplugin name
  }

  // Print To hint text
  "rage_hinttext"   //Ability name can use suffixes
  {
    "slot"         "0"                             // Ability Slot
    "message"		"I am Gay!" // Message to be printed
    "target" "3" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    "plugin_name"  "ff2r_chat"        // this subplugin name
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: basic chat subplugin",
  author      = "Zell",
  description = "It's just a basic chat subplugin but for FF2:R boss",
  version     = "1.0.0",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_chattext", false))
  {
    static char buffer[128];
    cfg.GetString("message", buffer, sizeof(buffer));
    if (buffer[0] == '\0')
      return;

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsTarget(client, i, cfg.GetInt("target", 0)))
      {
        CPrintToChat(i, buffer);
      }
    }
  }
  else if (!StrContains(ability, "rage_hudtext", false))
  {
    static char message[128];
    cfg.GetString("message", message, sizeof(message));
    if (message[0] == '\0')
      return;
    char params[64];
    cfg.GetString("params", params, sizeof(params), "-1.0, 0.25, 3.0, 255, 255, 255, 255, 1");
    char  buffer[8][8];
    int   count = ExplodeString(params, ", ", buffer, sizeof(buffer), 8);
    float position[3];
    int   rgba[4];
    int   effect;
    for (int i = 0; i < count; i++)
    {
      if (i < 3)
        position[i] = StringToFloat(buffer[i]);
      else if (i < 7)
        rgba[i - 3] = StringToInt(buffer[i]);
      else
        effect = StringToInt(buffer[i]);
    }

    SetHudTextParams(position[0], position[1], position[2], rgba[0], rgba[1], rgba[2], rgba[3], effect);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsTarget(client, i, cfg.GetInt("target", 0)))
      {
        ShowHudText(i, -1, "%s", message);
      }
    }
  }
  else if (!StrContains(ability, "rage_hinttext", false))
  {
    static char buffer[128];
    cfg.GetString("message", buffer, sizeof(buffer));
    if (buffer[0] == '\0')
      return;

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsTarget(client, i, cfg.GetInt("target", 0)))
      {
        PrintHintText(i, buffer);
      }
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

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
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