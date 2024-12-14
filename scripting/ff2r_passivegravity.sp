
#define DEBUG

#define PLUGIN_NAME           "ff2_passivegravity"
#define GRAVITY				  "ff2_passivegravity"
#define PLUGIN_AUTHOR         "Spookmaster, Zell"
#define PLUGIN_DESCRIPTION    "Basic FF2 subplugin that sets the hale's gravity to a passive value at the start of the round."
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <morecolors>
#include <ff2_dynamic_defaults>
#include <entity>
#include <rtd2>

#pragma semicolon 1


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	HookEvent("arena_round_start", roundStart);
	//HookEvent("teamplay_round_win", roundEnd);
	//HookEvent("player_death", player_killed);
}

public void roundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			if (FF2_GetBossIndex(client) != -1)
			{
				if (FF2_HasAbility(FF2_GetBossIndex(client), PLUGIN_NAME, GRAVITY))
				{
					float gravMult =  FF2_GetArgF(FF2_GetBossIndex(client), PLUGIN_NAME, GRAVITY, "arg0", 0, 0.5);
					int gravType =  FF2_GetArgI(FF2_GetBossIndex(client), PLUGIN_NAME, GRAVITY, "arg1", 1, 0);
					switch (gravType)
					{
						case 0:
						{
							SetEntityGravity(client, gravMult);
						}
						case 1:
						{
							for (int clientB = 1; clientB <= MaxClients; clientB++)
							{
								if (IsValidClient(clientB))
								{
									 SetEntityGravity(clientB, gravMult);
								}
							}
						}
						case 2:
						{
							for (int clientC = 1; clientC <= MaxClients; clientC++)
							{
								if (IsValidClient(clientC))
								{
									if (TF2_GetClientTeam(clientC) != TF2_GetClientTeam(client))
									{
										SetEntityGravity(clientC, gravMult);
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
stock bool IsValidClient(int client, bool replaycheck=true, bool onlyrealclients=true) //Function borrowed from Nolo001, credit goes to him.
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	//if(onlyrealclients)                    Commented out for testing purposes
	//{
	//	if(IsFakeClient(client))
	//		return false;
	//}

	return true;
}