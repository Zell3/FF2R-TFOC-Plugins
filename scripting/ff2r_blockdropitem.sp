/*
  "blockdropitem"
  {
    "plugin_name"	"ff2r_blockdropitem"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Block Item/PowerUp dropping",
  author  = "Naydef",
  version = "1.0.1",
};

public void OnPluginStart()
{
	AddCommandListener(Command_DropItem, "dropitem");
}


public void OnPluginEnd()
{
	RemoveCommandListener(Command_DropItem, "dropitem");
}

public Action Command_DropItem(int clientIdx, const char[] command, int argc)
{
	// Check if the command is valid and if the client is alive
  if (!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
    return Plugin_Handled;

	// Check if the client is a boss
  BossData boss = FF2R_GetBossData(clientIdx);
  if (!boss)
    return Plugin_Handled;

	// Check if the boss has the ability "blockdropitem"
  AbilityData ability = boss.GetAbility("blockdropitem");
  if (!ability.IsMyPlugin())
    return Plugin_Handled;

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