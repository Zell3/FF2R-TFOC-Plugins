/*
	"rage_outline"		// Ability name can use suffixes
	{
		"slot"			"0"								  // Ability Slot
    "duration"	"10.0"							// Duration of the outline
    // non-functional outline settings
    // "color"		"255 0 0 0"						// Color of the outline (RGBA format) : default is check by team
    "target"  "3"                   // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name"	"ff2r_outline"
	}

	"special_outline"
	{
    // non-functional outline settings
    // "color"		"255 0 0 0"						// Color of the outline (RGBA format) : default is check by team
    "target"  "3"                   // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name"	"ff2r_outline"
  }

  "special_onhit_outline"
  {
    // warning: do not use this ability with other outline abilities
    // for some reason i decided to make it dectect the attacker weapon item index instead of when got attacked
    "max"		     "3"
    "weapons1"   "5"	  // Weapon item index (TF2Items) to trigger the outline
    "duration1"  "10.0"	// Duration of the outline
    "color1"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

    "weapons2"   "105"	// Weapon item index (TF2Items) to trigger the outline
    "duration2" "10.0"	// Duration of the outline
    "color2"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

    "weapons3"   "105"	// Weapon item index (TF2Items) to trigger the outline
    "duration3"  "10.0"	// Duration of the outline
    "color3"	   "255 0 0 0"	// Color of the outline (RGBA format) : default is check by team

    "plugin_name"	"ff2r_outline"
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: My Stock Subplugin"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"It's a template ff2r subplugin"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "1"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXTF2PLAYERS	36

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};

public void OnPluginStart()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if(IsClientInGame(clientIdx))
		{
			OnClientPutInServer(clientIdx);
			
			BossData cfg = FF2R_GetBossData(clientIdx);	// Get boss config (known as boss index) from player
			if(cfg)
			{
				FF2R_OnBossCreated(clientIdx, cfg, false);	// If boss is valid, Hook the abilities because this subplugin is most likely late-loaded
			}
		}
	}
}

public void OnClientPutInServer(int clientIdx)
{
	// Check and apply stuff if boss abilities that can effect players is active
}

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		// Clear everything from players, because FF2:R either disabled/unloaded or this subplugin unloaded
	}
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	/*
	 * When boss created, hook the abilities etc.
	 *
	 * We no longer use RoundStart Event to hook abilities because bosses can be created trough 
	 * manually by command in other gamemodes other than Arena or create bosses mid-round.
	 *
	 */
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	 /*
	  * When boss removed (Died/Left the Game/New Round Started)
	  * 
	  * Unhook and clear ability effects from the plyaer/players
	  *
	  */
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	//Just your classic stuff, when boss raged:
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names with different plugins in boss config
		return;
	
	if(!StrContains(ability, "rage_hinttext", false))	// We want to use subffixes
	{
		static char buffer[128];
		cfg.GetString("message", buffer, sizeof(buffer));	// We use ConfigMap to Get string from "message" argument from ability
		
		if(buffer[0] != '\0') {
			PrintHintText(clientIdx, buffer);
		}
		else {
			PrintHintText(clientIdx, "fill up your \"message\" argument lol");
		}			
	}
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
	if(clientIdx <= 0 || clientIdx > MaxClients)
		return false;

	if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
		return false;

	if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
		return false;

	return true;
}