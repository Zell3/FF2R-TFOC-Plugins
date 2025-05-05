/*
  "rage_nuked"		//Ability name can use suffixes
  {
    "slot"			"0"								                   // Ability Slot

    "duration"	"5"								                   // Duration time in seconds this is how long the nuke will detonate after setup time
    "range"     "1000"                                  // Range of the nuke explosion
    "damage"		"1000"								                   // Damage of the nuke explosion

    "text"			"The Nuke will drop here in %s"			 // Hinttext Message %s is replaced with the time left in seconds

    "plugin_name"	"ff2r_nuked"		// this subplugin name
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

float g_AnnotationPosition[3]; // x, y, z
char g_AnnotationText[256]; // text id

float range; // range of the nuke explosion
int damage; // damage of the nuke explosion
int duration; // duration time in seconds this is how long the


public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Nuked",
  author      = "Zell",
  description = "drop a nuke at what boss looking",
  version     = "1.0.0",
};

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
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "rage_nuked", false))  // We want to use subffixes
  {
		duration = cfg.GetInt("duration", 5);
		range = cfg.GetInt("range", 1000);
		damage = cfg.GetInt("damage", 1000);
		cfg.GetString("text", g_AnnotationText, sizeof(g_AnnotationText)); // We use ConfigMap to Get string from "message" argument from ability

		SDKHook(clientIdx, SDKHook_PreThink, Nuked_PreThink);
	}
}

public void Nuked_PreThink(int client)
{
	
}

public void ShowAnnotation(int client)
{
	Handle event = CreateEvent("show_annotation");
	if (event == INVALID_HANDLE) return;
	
	SetEventFloat(event, "worldPosX", g_AnnotationPosition[0]);
	SetEventFloat(event, "worldPosY", g_AnnotationPosition[1]);
	SetEventFloat(event, "worldPosZ", g_AnnotationPosition[2]);
	SetEventFloat(event, "lifetime", 99999.0);

	SetEventString(event, "text", g_AnnotationText);
	SetEventInt(event, "visibilityBitfield", (1 << client));
	FireEvent(event);
	
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