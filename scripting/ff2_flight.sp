
#define DEBUG

#define PLUGIN_NAME           "ff2_flight"
#define FLIGHT		          "ff2_flight"
#define PLUGIN_AUTHOR         "Spookmaster"
#define PLUGIN_DESCRIPTION    "Allows hales to fly, as if they're using a jetpack."
#define PLUGIN_VERSION        "1.1"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <freak_fortress_2>
#include <tf2items>
#include <tf2_stocks>
#include <morecolors>
#include <ff2_dynamic_defaults>
#include <entity>
#include <rtd2>

#pragma semicolon 1

#define MAXTF2PLAYERS	35

float fuel[MAXTF2PLAYERS+1];
float maxFuel[MAXTF2PLAYERS+1];
float regenRate[MAXTF2PLAYERS+1];
float fuelCost[MAXTF2PLAYERS+1];
int button[MAXTF2PLAYERS+1];
float regenCD[MAXTF2PLAYERS+1];
bool KeyDown[MAXTF2PLAYERS+1];
bool isFlying[MAXTF2PLAYERS+1];
float velocity[MAXTF2PLAYERS+1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnMapStart()
{
	PrecacheSound("weapons/flame_thrower_dg_loop.wav", true);
	PrecacheSound("weapons/flame_thrower_end.wav", true);
}

public void OnPluginStart()
{
	HookEvent("arena_round_start", roundStart);
	HookEvent("teamplay_round_win", roundEnd);
	HookEvent("player_death", player_killed);
}

public void roundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			int boss = FF2_GetBossIndex(client);
			if (boss != -1)
			{
				if (FF2_HasAbility(boss, PLUGIN_NAME, FLIGHT))
				{
					maxFuel[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FLIGHT, 0, 1000.0);
					fuel[client] = maxFuel[client];
					regenRate[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FLIGHT, 1, 10.0);
					fuelCost[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FLIGHT, 2, 5.0);
					button[client] = chooseButton(boss);
					velocity[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FLIGHT, 4, 50.0);
					regenCD[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FLIGHT, 5, 3.0);
					CreateTimer(0.1, showHud, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				}
			}
		}
	}
}
public void roundEnd(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{	
	for (int client = 1; client <= MaxClients; client++)
	{
		fuel[client] = 0.0;
		maxFuel[client] = 0.0;
		regenRate[client] = 0.0;
		regenCD[client] = 0.0;
		KeyDown[client] = false;
		isFlying[client] = false;
	}
}
public Action player_killed(Event hEvent, const char[] sEvName, bool bDontBroadcast) //Controls what happens when a player dies. 
{
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (IsValidClient(victim))
	{
		fuel[victim] = 0.0;
		maxFuel[victim] = 0.0;
		regenRate[victim] = 0.0;
		regenCD[victim] = 0.0;
		KeyDown[victim] = false;
		isFlying[victim] = false;
	}
}


chooseButton(int bossIDX)
{
	switch (FF2_GetArgI(bossIDX, PLUGIN_NAME, FLIGHT, "arg3", 3, 1))
	{
		case 1:
		{
			return IN_ATTACK2;
		}
		case 2:
		{
			return IN_RELOAD;
		}
		case 3:
		{
			return IN_ATTACK3;
		}
		case 4:
		{
			return IN_JUMP;
		}
		default:
		{
			LogError("[FF2 Flight] ERROR: An invalid value was used in the boss' CFG! Defaulting to alt-fire...");
			return IN_ATTACK2;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (maxFuel[client] > 0.0 && IsPlayerAlive(client))
	{
		int boss = FF2_GetBossIndex(client);
		if(boss >= 0)
		{
			new bool:keyDown2 = (buttons & chooseButton(boss)) != 0;
			if (fuel[client] > fuelCost[client] && keyDown2 && !KeyDown[client])
			{
				static float velocityA[3];
				GetClientEyeAngles(client, velocityA);
				static float velocityB[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocityB);
				velocityB[2] += velocity[client];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocityB);
				fuel[client] = (fuel[client] - fuelCost[client]);
				isFlying[client] = true;
				for (int clientB = 1; clientB <= MaxClients; clientB++)
				{
					if (IsValidClient(clientB))
					{
						StopSound(clientB, SNDCHAN_AUTO, "weapons/flame_thrower_dg_loop.wav");
					}
				}
				EmitSoundToAll("weapons/flame_thrower_dg_loop.wav", client, _, SNDLEVEL_LIBRARY);
				regenCD[client] = FF2_GetArgF(boss, PLUGIN_NAME, FLIGHT, "arg5", 5, 3.0);
				return Plugin_Continue;
			}
			else
			{
				if (isFlying[client])
				{
					for (int clientC = 1; clientC <= MaxClients; clientC++)
					{
						if (IsValidClient(clientC))
						{
							StopSound(clientC, SNDCHAN_AUTO, "weapons/flame_thrower_dg_loop.wav");
						}
					}	
					EmitSoundToAll("weapons/flame_thrower_end.wav", client);
				}
				isFlying[client] = false;
			}
			KeyDown[client] = keyDown2;
		}
	}
	return Plugin_Continue;
}

public Action showHud(Handle dashHud, int client)
{
	if (IsValidClient(client))
	{
		if (FF2_GetRoundState() == 1 && IsPlayerAlive(client) && maxFuel[client] > 0.0)
		{
			if (!isFlying[client])
			{
				if (regenCD[client] > 0.0)
				{
					regenCD[client] = regenCD[client] - 0.1;
					if (regenCD[client] < 0.0)
					{
						regenCD[client] = 0.0;
					}
				}
				else
				{
					fuel[client] += regenRate[client];
					if (fuel[client] > maxFuel[client])
					{
						fuel[client] = maxFuel[client];
					}
				}
			}
			float fuelReserves = fuel[client]/maxFuel[client];
			if (fuelReserves >= 0.75)
			{
				SetHudTextParams(-1.0, 0.8, 0.1, 0, 0, 255, 255);
			}
			else if (fuelReserves >= 0.5 && fuelReserves < 0.75)
			{
				SetHudTextParams(-1.0, 0.8, 0.1, 65, 191, 88, 255);
			}
			else if (fuelReserves >= 0.25 && fuelReserves < 0.5)
			{
				SetHudTextParams(-1.0, 0.8, 0.1, 232, 252, 45, 255);
			}
			else if (fuelReserves >= 0.0 && fuelReserves < 0.25)
			{
				SetHudTextParams(-1.0, 0.8, 0.1, 255, 0, 0, 255);
			}
			switch(FF2_GetArgI(FF2_GetBossIndex(client), PLUGIN_NAME, FLIGHT, "arg3", 3, 1))
			{
				case 1:
				{
					ShowHudText(client, -1, "Fuel: %i/%i (Alt-Fire to Use)", RoundFloat(fuel[client]), RoundFloat(maxFuel[client]));
				}
				case 2:
				{
					ShowHudText(client, -1, "Fuel: %i/%i (Reload to Use)", RoundFloat(fuel[client]), RoundFloat(maxFuel[client]));
				}
				case 3:
				{
					ShowHudText(client, -1, "Fuel: %i/%i (Special Attack to Use)", RoundFloat(fuel[client]), RoundFloat(maxFuel[client]));
				}
				case 4:
				{
					ShowHudText(client, -1, "Fuel: %i/%i (Jump to Use)", RoundFloat(fuel[client]), RoundFloat(maxFuel[client]));
				}
				default:
				{
					ShowHudText(client, -1, "Fuel: %i/%i (Alt-Fire to Use)", RoundFloat(fuel[client]), RoundFloat(maxFuel[client]));
				}
			}
		}
		else if (FF2_GetRoundState() == 2)
		{
			KillTimer(dashHud);
		}
		else if (!IsPlayerAlive(client))
		{
			KillTimer(dashHud);
		}
		else if (maxFuel[client] <= 0.0)
		{
			KillTimer(dashHud);
		}
	}
	else
	{
		KillTimer(dashHud);
	}
}

//Stocks below. Most of these are borrowed, so I've credited their original writers as such.

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

stock bool IsInvuln(int client) //Borrowed from Batfoxkid
{
	if(!IsValidClient(client))
		return true;

	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		//TF2_IsPlayerInCondition(client, TFCond_MegaHeal) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}