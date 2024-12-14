/*
"special_revivemarker"
{
	"lifetime"	    "45.0"	//  Marker Lifetime
	"limit"		    "3"	    //  Player Revive Limit
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

bool MarkerEnable = false;
int decaytime;
char buffer[256];
int reviveMarker[MAXPLAYERS+1];
bool ChangeClass[MAXPLAYERS+1];
int reviveLimit[MAXPLAYERS+1];
int currentTeam[MAXPLAYERS+1];

bool sound;

#define MVMINTRO	"music/mvm_class_select.wav"
#define MVMINTRO_VOL	1.0
#define DEATH		"mvm/mvm_player_died.wav"
#define DEATH_VOL	1.0
#define GAMEOVER	"music/mvm_lost_wave.wav"
#define GAMEOVER_VOL	0.85

public Plugin myinfo = {
	name = "[FF2R] Standalone Revivemarker",
	author = "SHADoW93 , Zell",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	MarkerEnable = false;

	PrecacheSound(MVMINTRO, true);
	PrecacheSound(DEATH, true);
	PrecacheSound(GAMEOVER, true);

	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}

public void OnClientDisconnect(int client) 
{
	if(MarkerEnable)
	{
		if(IsValidMarker(reviveMarker[client])) 
			RemoveReanimator(client);
		currentTeam[client] = 0;
		ChangeClass[client] = false;
		reviveLimit[client] = 0;
	}
}

public Action Event_ChangeClass(Handle event, const char[] name, bool dontbroadcast) 
{
	if(MarkerEnable)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		ChangeClass[client] = true;
	}
	return Plugin_Continue;
}


public Action Event_PlayerInventory(Handle event, const char[] name, bool dontbroadcast) 
{
	if(MarkerEnable)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsValidMarker(reviveMarker[client])) 
			RemoveReanimator(client);
	}
	
	return Plugin_Continue;
}


public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("special_revivemarker");
		if (ability.IsMyPlugin()) {
			MarkerEnable = true;
			HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
			HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
			HookEvent("player_changeclass", Event_ChangeClass);
			HookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);

			decaytime = ability.GetInt("lifetime", 60); // Reanimator decay time
			sound = ability.GetBool("sound", true);
			(ability.GetString("condition", buffer, sizeof(buffer), "81 ; 0.32"));
			for(int i = 1; i <= MaxClients; i++) {
				if(!IsValidClient(i))
					continue;

				reviveLimit[i] = ability.GetInt("limit", 3); // Can Minions Revive Each Other?
				if(sound)
					EmitSoundToClient(i, MVMINTRO, _, _, _, _, MVMINTRO_VOL);
				SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
				ShowHudText(i, -1, "Medics can revive players this round!");
			}
		}
	}
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	if(MarkerEnable)
	{
		reviveLimit[client] -= 1;

		if(reviveLimit[client] == 0)
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
			ShowHudText(client, -1, "You can no longer be revived!");
		}
		else if(reviveLimit[client] == 1)
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 85, 85, 255);
			ShowHudText(client, -1, "You can be revived 1 more time");
		}
		else if(reviveLimit[client])
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 170, 170, 255);
			ShowHudText(client, -1, "You can be revived %i more times", reviveLimit[client]);
		}

		AddCondition(client, buffer);
	}
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(!MarkerEnable)
		return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
		return Plugin_Continue; // Prevent a bug with revive markers & dead ringer spies

	BossData boss = FF2R_GetBossData(client);
	if (boss)
		return Plugin_Continue;

	DropReanimator(client);

	return Plugin_Continue;
}

public void FF2R_OnBossRemoved(int clientIdx) {
	BossData cfg = FF2R_GetBossData(clientIdx);
	AbilityData ability = cfg.GetAbility("special_revivemarker");
	if (ability.IsMyPlugin()) {
		MarkerEnable = false;
		for(int client = 1; client <= MaxClients; client++) {
			if(!IsValidClient(client))
				continue;

			currentTeam[client] = 0;
			ChangeClass[client] = false;
			reviveLimit[client] = 0;
		}
		UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
		RemoveCondition(clientIdx, buffer);
	}
}

stock void DropReanimator(int client) // Drops a revive marker
{
	if(!MarkerEnable)
		return;

	if(sound) {
		if(!(reviveLimit[client] > 0))
		{
			EmitSoundToClient(client, GAMEOVER, _, _, _, _, GAMEOVER_VOL);
			return;
		}
	}

	int clientTeam = GetClientTeam(client);
	reviveMarker[client] = CreateEntityByName("entity_revive_marker");

	if (reviveMarker[client] != -1)
	{
		SetEntPropEnt(reviveMarker[client], Prop_Send, "m_hOwner", client); // client index 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nSolidType", 2); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_usSolidFlags", 8); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_fEffects", 16); 	
		SetEntProp(reviveMarker[client], Prop_Send, "m_iTeamNum", clientTeam); // client team 
		SetEntProp(reviveMarker[client], Prop_Send, "m_CollisionGroup", 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_bSimulatedEveryTick", 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nBody", view_as<int>(TF2_GetPlayerClass(client)) - 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nSequence", 1); 
		SetEntPropFloat(reviveMarker[client], Prop_Send, "m_flPlaybackRate", 1.0);  
		SetEntProp(reviveMarker[client], Prop_Data, "m_iInitialTeamNum", clientTeam);
		SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin")+4, reviveMarker[client]);
		if(GetClientTeam(client) == 3)
			SetEntityRenderColor(reviveMarker[client], 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one
		DispatchSpawn(reviveMarker[client]);
		CreateTimer(0.1, MoveMarker, client);
		
		CreateTimer(float(decaytime), TimeBeforeRemoval, client);
	} 

	if(sound)
		EmitSoundToClient(client, DEATH, _, _, _, _, DEATH_VOL);
}

stock bool IsValidMarker(int marker) // Checks if revive marker is a valid entity.
{
	if (IsValidEntity(marker)) 
	{
		char buffers[128];
		GetEntityClassname(marker, buffers, sizeof(buffers));
		if (strcmp(buffers,"entity_revive_marker",false) == 0)
			return true;
	}
	return false;
}

stock void RemoveReanimator(int client) // Removes a revive marker
{
	currentTeam[client] = GetClientTeam(client);
	ChangeClass[client] = false;
	if (IsValidMarker(reviveMarker[client])) 
		AcceptEntityInput(reviveMarker[client], "Kill");
}

public Action MoveMarker(Handle timer, int client)
{
	float position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(reviveMarker[client], position, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Continue;
}

public Action TimeBeforeRemoval(Handle timer, int client) 
{
	if(!IsValidMarker(reviveMarker[client]) || !IsValidClient(client)) 
		return Plugin_Handled;

	RemoveReanimator(client);
	return Plugin_Continue;
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

stock void AddCondition(int clientIdx, char[] conditions)
{
	char conds[32][32];
	int count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
		for (int i = 0; i < count; i+=2)
			if(!TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
				TF2_AddCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i+1]));
}

stock void RemoveCondition(int clientIdx, char[] conditions)
{
	char conds[32][32];
	int count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
		for (int i = 0; i < count; i+=2)
			if(TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
				TF2_RemoveCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])));
}