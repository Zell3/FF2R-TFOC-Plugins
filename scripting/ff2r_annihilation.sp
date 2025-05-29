/*
	"rage_annihilation"	// Ability name can't use suffixes
	{
		"slot"		"0"			// Ability Slot
		"damage"	"10.0"		// Damage per second
		"range"		"600.0"		// Annihilation range
		"heal"		"false"		// Damage dealt turns into health?
		"walls"		"true"		// Can attack trough walls?
		"extend"	"true"		// Extend rage duration as long as someone in range
		"plugin_name"		"ff2r_annihilation"		// this subplugin name
	}
	
	"rage_ion_cannon"	// Ability name can use suffixes
	{
		"slot"		"0"			// Ability Slot
		"delay"		"3.0"		// Initial delay	
		"damage"	"1000.0"	// Damage at pointblank
		"range"		"600.0"		// Cannon range
		"force"		"1000.0"	// Knockback force
		"vertical"	"475.0"		// Vertical force	
		"walls"		"true"		// Can deal damage trough walls?
		"aim mode"	"0"			// 0:Stand Position, 1:Aim Position
		"plugin_name"	"ff2r_annihilation"		// this subplugin name
	}
	
	"rage_angermode"	// Ability name can use suffixes
	{
		"slot"			"0"			// Ability Slot
		"max"			"4000.0"	// Max Anger Limit
		"rate"			"1.0"		// Anger gained per damage
		"airblast"		"200.0"		// Anger gained on airblast
		"scout"			"0.75"		// Anger gained per tick when only scouts left
		"activation"	"200.0"		// Anger directly wasted upon activation
		""
		
		"discharge"	"2.0"				// Discharge rate per tick
		"damage"	"(x * 0.5) + 1.0"	// increasement on damage ratio n:player count, x:anger ratio
		"speed"		"(x * 0.5) + 1.0"	// increasement on movespeed ratio n:player count, x:anger ratio
		"attack"	""
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: My AbiltyPack"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"J0BL3SS's AbilityPack Number #1"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "3"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXTF2PLAYERS	36

int BeamEntity[MAXTF2PLAYERS][MAXTF2PLAYERS];
float g_flDamageAccumulated[MAXTF2PLAYERS];
float Annihilation_Duration[MAXTF2PLAYERS];

float ION_Delay_Duration[MAXTF2PLAYERS];
float ION_Position[MAXTF2PLAYERS][3];

float OFF_THE_MAP[3] = {16383.0, 16383.0, -16383.0};	// Kill without mayhem


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
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		for(int target = 1; target <= MaxClients; target++)
			BeamEntity[clientIdx][target] = -1;
	}
}

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		for(int target = 1; target <= MaxClients; target++)
			if(IsValidEntity(BeamEntity[clientIdx][target]))
				CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[clientIdx][target]), TIMER_FLAG_NO_MAPCHANGE);
		
		SDKUnhook(clientIdx, SDKHook_PreThink, Annihilation_PreThink);
	}
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	if(IsValidClient(clientIdx))
	{
		for(int target = 1; target <= MaxClients; target++)
			if(IsValidEntity(BeamEntity[clientIdx][target]))
				CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[clientIdx][target]), TIMER_FLAG_NO_MAPCHANGE);
		
		SDKUnhook(clientIdx, SDKHook_PreThink, Annihilation_PreThink);
	}
		
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int clientIdx = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(clientIdx))
		return;	// Make sure client is valid entity
	
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;	// Make sure it is not deadringer
	
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidEntity(BeamEntity[clientIdx][target]))
			CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[clientIdx][target]), TIMER_FLAG_NO_MAPCHANGE);
			
		if(IsValidEntity(BeamEntity[target][clientIdx]))
			CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[target][clientIdx]), TIMER_FLAG_NO_MAPCHANGE);
	}
		
	SDKUnhook(clientIdx, SDKHook_PreThink, Annihilation_PreThink);
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())
		return;
		
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "rage_annihilation", false))	// We want to use subffixes
	{
		Annihilation_Duration[clientIdx] = GetGameTime() + cfg.GetFloat("duration", 10.0);
		SDKHook(clientIdx, SDKHook_PreThink, Annihilation_PreThink);
	}
	
	if(!StrContains(ability, "rage_ion_cannon", false))	// We want to use subffixes
	{
		Rage_ION_Prepare(clientIdx, cfg);
	}
}

public void Rage_ION_Prepare(int clientIdx, AbilityData ability)
{
	GetClientAbsOrigin(clientIdx, ION_Position[clientIdx]);
	ION_Delay_Duration[clientIdx] = GetGameTime() + ability.GetFloat("delay", 3.0);
	SDKHook(clientIdx, SDKHook_PreThink, ION_Delay_PreThink);
}

public void ION_Delay_PreThink(int clientIdx)
{
	if(GetGameTime() >= ION_Delay_Duration[clientIdx])
	{
		ION_Launch(clientIdx);
		SDKUnhook(clientIdx, SDKHook_PreThink, ION_Delay_PreThink);
	}
}

public void ION_Launch(int clientIdx)
{
	if(!FF2R_GetBossData(clientIdx) || !FF2R_GetBossData(clientIdx).GetAbility("rage_ion_cannon").IsMyPlugin())
		return;
	
	
}

public void Annihilation_PreThink(int clientIdx)
{
	if(GetGameTime() >= Annihilation_Duration[clientIdx])
	{
		for(int target = 1; target <= MaxClients; target++)
			if(IsValidEntity(BeamEntity[clientIdx][target]))
				CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[clientIdx][target]), TIMER_FLAG_NO_MAPCHANGE);
				
		SDKUnhook(clientIdx, SDKHook_PreThink, Annihilation_PreThink);
	}
	
	if(!FF2R_GetBossData(clientIdx).GetAbility("rage_annihilation").IsMyPlugin())
		return;
		
	float range = FF2R_GetBossData(clientIdx).GetAbility("rage_annihilation").GetFloat("range", 600.0);
	float damage_rate = FF2R_GetBossData(clientIdx).GetAbility("rage_annihilation").GetFloat("damage", 10.0);
	float pos1[3], pos2[3];
	bool IsInRange = false;
	
	GetClientAbsOrigin(clientIdx, pos1);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target) != GetClientTeam(clientIdx))
		{
			GetClientAbsOrigin(target, pos2);
			if(GetVectorDistance(pos1, pos2) <= range)
			{
				IsInRange = true;
				
				if(!IsValidEntity(BeamEntity[clientIdx][target]))
					BeamEntity[clientIdx][target] = TF2_SpawnAndConnectMedigunBeam(clientIdx, target, 90.0);
				
				// use accumulator to allow fractional damage per tick
				g_flDamageAccumulated[target] += damage_rate * GetGameFrameTime();
				if(g_flDamageAccumulated[target] > 1.0) 
				{	
					int damageInflicted = RoundToFloor(g_flDamageAccumulated[target]);
					
					SDKHooks_TakeDamage(target, clientIdx, clientIdx, float(damageInflicted), DMG_PREVENT_PHYSICS_FORCE);
					
					if(FF2R_GetBossData(clientIdx).GetAbility("rage_annihilation").GetBool("heal", false))
						SetEntityHealth(clientIdx, GetEntProp(clientIdx, Prop_Data, "m_iHealth") + damageInflicted);
					
					g_flDamageAccumulated[target] -= damageInflicted;
				}
			}
			else
			{
				if(IsValidEntity(BeamEntity[clientIdx][target]))
					CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(BeamEntity[clientIdx][target]), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	if(IsInRange && FF2R_GetBossData(clientIdx).GetAbility("rage_annihilation").GetBool("extend", false))
	{
		Annihilation_Duration[clientIdx] = Annihilation_Duration[clientIdx] + 0.0150001;  
	}
	
	if(0.0 < Annihilation_Duration[clientIdx] - GetGameTime())
		PrintCenterText(clientIdx, "Remaining Duration: %.1f", Annihilation_Duration[clientIdx] - GetGameTime());
	else
		PrintCenterText(clientIdx, "Remaining Duration: 0.00");
}


public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
	return Plugin_Continue;
}

stock int TF2_SpawnAndConnectMedigunBeam(int healer, int target, float offset = 0.0, bool attach = true)
{
	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "effect_name", TF2_GetClientTeam(healer) == TFTeam_Red ? "medicgun_beam_red" : "medicgun_beam_blue");
	DispatchSpawn(particle);
	
	float position[3];
	GetEntPropVector(healer, Prop_Send, "m_vecOrigin", position);
	position[2] += offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
	
	char targetName1[128];
	Format(targetName1, sizeof(targetName1), "target%i", healer);
	DispatchKeyValue(healer, "targetname", targetName1);
	
	if(attach)
	{
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", healer);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", healer);		
	}
	
	SetEntPropEnt(particle, Prop_Send, "m_hControlPointEnts", target, 0);
	SetEntProp(particle, Prop_Send, "m_iControlPointParents", target, _, 0);
	
	ActivateEntity(particle);
	AcceptEntityInput(particle, "Start");

	return particle;
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