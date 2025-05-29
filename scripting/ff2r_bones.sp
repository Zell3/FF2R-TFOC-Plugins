/*
	"rage_tornado"	                 											// Ability name can use suffixes                   
	{	
		"slot"					"0"												// Ability slot				
		
		"duration"				"1.0"											// Ability duration
		"damage per tick"	    "0.2"											// Damage per tick			
		"range"				    "128.0"											// Range of tornado  			
		"ignore invuln"		    "false"											// Ignore uber? (true = yes, false = no)				
		
		"plugin_name"	        "ff2r_bones"
	}
	
	"rage_mortis"	                											// Ability name can use suffixes                                                           
	{
		"slot"					"0"												// Ability slot			                                                
		
		"duration"				"8.0"					                        // Ability duration
		"damage"		        "500.0"					                        // Damage                 
		"range"	                "512.0"					                        // Range for mortis		
		"model"				    "models/props_halloween/hammer_mechanism.mdl"	// Model for mortis 				                             
		
		"plugin_name"	        "ff2r_bones"
	}
	
	"rage_calcium_repossession"	                        						// Ability name can use suffixes
	{
		"slot"					"0"												// Ability slot						
		
		"duration"	    		"8.0"											// Ability duration
		"effect damage"	        "-1.0"					 						// Damage (if -1.0 = always max damage, i think so)
		"stun duration"         "3.0"											// Stun after hitting someone 
		"effect range"		    "512.0"											// Range for calcium effect	
		"spawn skeletons"	    "false"											// Spawn skeletons after hitting someone? (true = yes, false = no)
		
		"plugin_name"	        "ff2r_bones"
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Spookmaster Bones Abilities"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Bad to the Bone"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS   MAXPLAYERS+1

#define SPRITE_BEAM 	"materials/sprites/lgtning.vmt"
#define SPRITE_HALO 	"materials/sprites/halo01.vmt"

float Tornado_Duration[MAXTF2PLAYERS];
float Tornado_DamagePerTick[MAXTF2PLAYERS];
float Tornado_Range[MAXTF2PLAYERS];
bool Tornado_IgnoreInvuln[MAXTF2PLAYERS];
bool IsTornadoActive[MAXTF2PLAYERS];

float Mortis_Duration[MAXTF2PLAYERS];
float Mortis_Damage[MAXTF2PLAYERS];
float Mortis_Range[MAXTF2PLAYERS];
float Mortis_Position[MAXTF2PLAYERS][3];
int Mortis_Hammer[MAXTF2PLAYERS];

bool Mortis_Init[MAXTF2PLAYERS] = { false, ... };
bool Mortis_InUse[MAXTF2PLAYERS] = { false, ... };
bool Mortis_Enabled[MAXTF2PLAYERS] = { false, ... };

bool Calcium_CanHit[MAXTF2PLAYERS];
Handle CalciumTimer[MAXTF2PLAYERS] = { null, ... };
float Calcium_EffectDamage[MAXTF2PLAYERS];
float Calcium_EffectDuration[MAXTF2PLAYERS];
float Calcium_EffectRange[MAXTF2PLAYERS];
bool Calcium_SpawnSkeleton[MAXTF2PLAYERS];
int CAL_BeamSprite = 0;
int	CAL_HaloSprite = 0;

float OFF_THE_MAP[3] = {16383.0, 16383.0, -16383.0};	// Kill without mayhem

int Souls_ParticleIndex = -1;

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public void OnPluginStart()
{
	OnMapStart();
	
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if(IsClientInGame(clientIdx))
		{
			OnClientPutInServer(clientIdx);
		}
	}
}

public void OnMapStart()
{
	CAL_BeamSprite = PrecacheModel(SPRITE_BEAM);
	CAL_HaloSprite = PrecacheModel(SPRITE_HALO);
	
	PrecacheSound("misc/halloween/strongman_fast_swing_01.wav");
	PrecacheSound("ambient/explosions/explode_1.wav");
	PrecacheSound("misc/halloween/strongman_fast_impact_01.wav");
	PrecacheSound("misc/halloween/merasmus_disappear.wav");
}

public void OnClientPutInServer(int clientIdx)
{
	SDKHook(clientIdx, SDKHook_OnTakeDamage, Calcium_OnTakeDamage);
}

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{		
		Calcium_CanHit[clientIdx] = false;
		SDKUnhook(clientIdx, SDKHook_OnTakeDamage, Calcium_OnTakeDamage);
		
		SDKUnhook(clientIdx, SDKHook_PreThink, Tornado_PreThink);
		SDKUnhook(clientIdx, SDKHook_PreThink, Mortis_PreThink);
		
		CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(Souls_ParticleIndex), TIMER_FLAG_NO_MAPCHANGE);
		
		if(IsTornadoActive[clientIdx])
			SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 5);
			
		Mortis_Init[clientIdx] = false;
		Mortis_Enabled[clientIdx] = false;
	}
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	//when boss created; hook the abilities etc. 
	//We no longer use RoundStart Event to hook abilities because bosses can be created trough 
	//manually by command or in other gamemodes other than Arena.
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	Calcium_CanHit[clientIdx] = false;
	
	SDKUnhook(clientIdx, SDKHook_PreThink, Tornado_PreThink);
	if(IsTornadoActive[clientIdx])
		SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 5);
		
	SDKUnhook(clientIdx, SDKHook_PreThink, Mortis_PreThink);
	Mortis_Init[clientIdx] = false;
	
	if((IsValidEntity(Souls_ParticleIndex) || IsValidEdict(Souls_ParticleIndex)) && Souls_ParticleIndex != -1)
		CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(Souls_ParticleIndex), TIMER_FLAG_NO_MAPCHANGE);
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
	
	if(!StrContains(ability, "rage_tornado", false))
	{
		Rage_Bone_Tornado(clientIdx, ability, cfg);
	}
	if(!StrContains(ability, "rage_calcium_repossession"))
	{
		CreateTimer(cfg.GetFloat("duration", 8.0), Timer_RemoveCalcium, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
		Calcium_EffectDamage[clientIdx] = cfg.GetFloat("effect damage", -1.0);
		Calcium_EffectDuration[clientIdx] = cfg.GetFloat("stun duration", 3.0);
		Calcium_EffectRange[clientIdx] = cfg.GetFloat("effect range", 512.0);
		Calcium_SpawnSkeleton[clientIdx] = cfg.GetBool("spawn skeletons", false);
		
		Calcium_CanHit[clientIdx] = true;
	}
	if(!StrContains(ability, "rage_mortis"))
	{
		Mortis_Hammer[clientIdx] = CreateEntityByName("prop_dynamic");
		if(IsValidEntity(Mortis_Hammer[clientIdx]))
		{
			DispatchKeyValue(Mortis_Hammer[clientIdx], "model", "models/props_halloween/hammer_mechanism.mdl");
			SetEntityRenderMode(Mortis_Hammer[clientIdx], view_as<RenderMode>(2));
			SetEntityRenderColor(Mortis_Hammer[clientIdx], 0, 255, 200, 180);
			DispatchSpawn(Mortis_Hammer[clientIdx]);
		}
		
		Mortis_Duration[clientIdx] = cfg.GetFloat("duration", 8.0) + GetGameTime();
		Mortis_Damage[clientIdx] = cfg.GetFloat("damage", 500.0);
		Mortis_Range[clientIdx] = cfg.GetFloat("range", 512.0);
		SDKHook(clientIdx, SDKHook_PreThink, Mortis_PreThink);
		Mortis_Enabled[clientIdx] = true;
	}
	if(!StrContains(ability, "special_souls_rising"))
	{
		if(IsValidEntity(Souls_ParticleIndex) || IsValidEdict(Souls_ParticleIndex))
			CreateTimer(0.0, Timer_RemoveEntity, EntIndexToEntRef(Souls_ParticleIndex), TIMER_FLAG_NO_MAPCHANGE);
		
		float pos[3];
		GetClientAbsOrigin(clientIdx, pos);
		Souls_ParticleIndex = CreateParticle("hammer_souls_rising", pos);
	}
}

public void Mortis_PreThink(int clientIdx)
{
	if(GetGameTime() >= Mortis_Duration[clientIdx] || !IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
	{
		SDKUnhook(clientIdx, SDKHook_PreThink, Mortis_PreThink);
		EmitSoundToAll("misc/halloween/merasmus_disappear.wav", _, _, _, _, 1.0, _, _, Mortis_Position[clientIdx]);
		
		if(IsValidEntity(Mortis_Hammer[clientIdx]))
			CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(Mortis_Hammer[clientIdx]), TIMER_FLAG_NO_MAPCHANGE);
			
		Mortis_Init[clientIdx] = false;
		Mortis_Enabled[clientIdx] = false;
		
		if(!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
			FF2R_OnBossRemoved(clientIdx);
	}
	
	if(Mortis_Init[clientIdx])
		return;
	
	float flPos[3], flAng[3];
	GetClientEyePosition(clientIdx, flPos);
	GetClientEyeAngles(clientIdx, flAng);
	
	Handle trace = TR_TraceRayFilterEx(flPos, flAng, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(flPos, trace);
		CloseHandle(trace);
	}
	
	Mortis_Position[clientIdx][0] = flPos[0];
	Mortis_Position[clientIdx][1] = flPos[1];
	Mortis_Position[clientIdx][2] = flPos[2];
	
	float highpos[3];
	if(flPos[0] > 0.0)
	{
		highpos[0] = flPos[0] - Mortis_Range[clientIdx];
	}
	else
	{
		highpos[0] = flPos[0] + Mortis_Range[clientIdx];
	}
	
	if(flPos[1] > 0.0)
	{
		highpos[1] = flPos[1] + Mortis_Range[clientIdx];
	}
	else
	{
		highpos[1] = flPos[1] - Mortis_Range[clientIdx];
	}
	
	
	highpos[1] = flPos[1];
	highpos[2] = flPos[2] + 360.0;
	
	
	int beam_colors[4];
	switch(GetClientTeam(clientIdx))
	{
		case view_as<int>(TFTeam_Blue):
		{
			beam_colors[0] = 0;
			beam_colors[1] = 255;
			beam_colors[2] = 200;
			beam_colors[3] = 255;
		}
		case view_as<int>(TFTeam_Red):
		{
			beam_colors[0] = 200;
			beam_colors[1] = 255;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
		default:
		{
			beam_colors[0] = 0;
			beam_colors[1] = 255;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
	}
	
	flAng[0] = 0.0;
	
	TeleportEntity(Mortis_Hammer[clientIdx], highpos, flAng, NULL_VECTOR);
	
	if(!IsModelPrecached(SPRITE_BEAM) || !IsModelPrecached(SPRITE_HALO))
	{
		LogError("Sprite Models are not precached!");
		return;
	}
	else
	{
		TE_SetupBeamRingPoint(flPos, Mortis_Range[clientIdx] - 1.0, Mortis_Range[clientIdx], CAL_BeamSprite, CAL_HaloSprite, 0, 30, 0.1, 36.0, 0.0, beam_colors, 30, 0);
		TE_SendToAll();
	}
}

public void OnPlayerRunCmdPost(int clientIdx, int buttons)
{
	BossData boss = FF2R_GetBossData(clientIdx);
	if(!boss)
		return;
	
	AbilityData mortis = boss.GetAbility("rage_mortis");
	if(mortis.IsMyPlugin())
	{
		if(!Mortis_Enabled[clientIdx])
			return;
			
		if(!Mortis_InUse[clientIdx] && buttons & IN_ATTACK)
		{
			Mortis_InUse[clientIdx] = true;
			if(!Mortis_Init[clientIdx])
				Call_Hammer(clientIdx);
				
		}
		else if(Mortis_InUse[clientIdx] && !(buttons & IN_ATTACK))
		{
			Mortis_InUse[clientIdx] = false;		
		}
	}
}

public void Call_Hammer(int clientIdx)
{	
	Mortis_Init[clientIdx] = true;
	
	EmitSoundToAll("misc/halloween/strongman_fast_swing_01.wav", _, _, _, _, 1.0, _, _, Mortis_Position[clientIdx]);
	
	SetVariantString("OnUser2 !self:SetAnimation:smash:0:1");
	AcceptEntityInput(Mortis_Hammer[clientIdx], "AddOutput");
	AcceptEntityInput(Mortis_Hammer[clientIdx], "FireUser2");
	
	int beam_colors[4];
	switch(GetClientTeam(clientIdx))
	{
		case view_as<int>(TFTeam_Blue):
		{
			beam_colors[0] = 0;
			beam_colors[1] = 255;
			beam_colors[2] = 200;
			beam_colors[3] = 255;
		}
		case view_as<int>(TFTeam_Red):
		{
			beam_colors[0] = 200;
			beam_colors[1] = 255;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
		default:
		{
			beam_colors[0] = 0;
			beam_colors[1] = 255;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
	}
	
	if(!IsModelPrecached(SPRITE_BEAM) || !IsModelPrecached(SPRITE_HALO))
	{
		LogError("Sprite Models are not precached!");
		return;
	}
	else
	{
		TE_SetupBeamRingPoint(Mortis_Position[clientIdx], Mortis_Range[clientIdx] - 1.0, Mortis_Range[clientIdx], CAL_BeamSprite, CAL_HaloSprite, 0, 30, 1.6, 36.0, 0.0, beam_colors, 30, 0);
		TE_SendToAll();
	}
	
	CreateTimer(1.6, Timer_Smash, clientIdx, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Smash(Handle timer, int clientIdx)
{
	if(!Mortis_Enabled[clientIdx])
		return Plugin_Stop;
		
	int shaker = CreateEntityByName("env_shake");
	if(IsValidEntity(shaker))
	{
		DispatchKeyValue(shaker, "amplitude", "10");
		DispatchKeyValue(shaker, "radius", "1500");
		DispatchKeyValue(shaker, "duration", "1");
		DispatchKeyValue(shaker, "frequency", "2.5");
		DispatchKeyValue(shaker, "spawnflags", "4");
		DispatchKeyValueVector(shaker, "origin", Mortis_Position[clientIdx]);

		DispatchSpawn(shaker);
		AcceptEntityInput(shaker, "StartShake");

		CreateTimer(1.0, Timer_RemoveEntity, EntIndexToEntRef(shaker), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	EmitSoundToAll("ambient/explosions/explode_1.wav", _, _, _, _, 1.0, _, _, Mortis_Position[clientIdx]);
	EmitSoundToAll("misc/halloween/strongman_fast_impact_01.wav", _, _, _, _, 1.0, _, _, Mortis_Position[clientIdx]);
	
	int Particle01 = CreateParticle("hammer_bones_kickup", Mortis_Position[clientIdx]);
	
	//Player Damage
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsValidClient(iClient))
		{
			if(IsPlayerAlive(iClient) && GetClientTeam(iClient) != GetClientTeam(clientIdx))
			{
				static float ClientPos[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", ClientPos);
				float flDist = GetVectorDistance(ClientPos, Mortis_Position[clientIdx]);
				
				if(flDist <= Mortis_Range[clientIdx])
				{
					// Player Damage
					float damage = Mortis_Damage[clientIdx] - (Mortis_Damage[clientIdx] * flDist / Mortis_Range[clientIdx]);
					if(damage > 0.0)
						SDKHooks_TakeDamage(iClient, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}	
			}
		}
	}
	
	
	CreateTimer(1.0, Timer_RemoveEntity, EntIndexToEntRef(Particle01), TIMER_FLAG_NO_MAPCHANGE);
	Mortis_Init[clientIdx] = false;
	return Plugin_Continue;
}

public Action Timer_RemoveCalcium(Handle timer, int userid)
{
	int clientIdx = GetClientOfUserId(userid);
	if(!clientIdx)
		return Plugin_Handled;
		
	if(FF2R_GetBossData(clientIdx) == null)
		return Plugin_Handled;
	
	if(Calcium_CanHit[clientIdx])
		Calcium_CanHit[clientIdx] = false;
	
	return Plugin_Continue;
}


public Action Calcium_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
	{
		if(Calcium_CanHit[attacker])
		{
			Calcium_CanHit[attacker] = false;
			float victim_pos[3];
			
			int beam_colors[4];
			switch(GetClientTeam(attacker))
			{
				case view_as<int>(TFTeam_Blue):
				{
					beam_colors[0] = 0;
					beam_colors[1] = 255;
					beam_colors[2] = 200;
					beam_colors[3] = 255;
				}
				case view_as<int>(TFTeam_Red):
				{
					beam_colors[0] = 200;
					beam_colors[1] = 255;
					beam_colors[2] = 0;
					beam_colors[3] = 255;
				}
				default:
				{
					beam_colors[0] = 0;
					beam_colors[1] = 255;
					beam_colors[2] = 0;
					beam_colors[3] = 255;
				}
			}
			
			GetClientAbsOrigin(victim, victim_pos);
			//GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victim_pos);
			
			damage = 0.0;
			TF2_StunPlayer(victim, Calcium_EffectDuration[attacker], 1.0, TF_STUNFLAG_SLOWDOWN | TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_BONKSTUCK, attacker);
			SetEntityMoveType(victim, MOVETYPE_NONE);
			
			if(!IsModelPrecached(SPRITE_BEAM) || !IsModelPrecached(SPRITE_HALO))
			{
				LogError("Sprite Models are not precached!");
				return Plugin_Continue;
			}
			else
			{
				TE_SetupBeamRingPoint(victim_pos, Calcium_EffectRange[attacker], Calcium_EffectRange[attacker] + 1.0, 
				CAL_BeamSprite, CAL_HaloSprite, 0, 30, Calcium_EffectDuration[attacker], 36.0, 0.0, beam_colors, 30, 0);
				TE_SendToAll();
			}
			
			DataPack pack;
			CalciumTimer[attacker] = CreateDataTimer(Calcium_EffectDuration[attacker], Timer_BigBoom, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(GetClientUserId(attacker));
			pack.WriteCell(GetClientUserId(victim));
			pack.WriteFloat(victim_pos[0]);
			pack.WriteFloat(victim_pos[1]);
			pack.WriteFloat(victim_pos[2]);
			
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action Timer_BigBoom(Handle timer, DataPack pack)
{
	float victim_pos[3];
	
	pack.Reset();
	int clientIdx = GetClientOfUserId(pack.ReadCell());
	int victim = GetClientOfUserId(pack.ReadCell());
	victim_pos[0] = pack.ReadFloat();
	victim_pos[1] = pack.ReadFloat();
	victim_pos[2] = pack.ReadFloat();
	
	if(!clientIdx || !victim)
		return Plugin_Handled;
		
	SetEntityMoveType(victim, MOVETYPE_WALK);
	float pos2[3];
	
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target) != GetClientTeam(clientIdx))
		{
			GetClientAbsOrigin(target, pos2);
			float distance = GetVectorDistance(victim_pos, pos2);
			if(distance <= Calcium_EffectRange[clientIdx])
			{
				if(Calcium_EffectDamage[clientIdx] < 0.0)
				{
					SDKHooks_TakeDamage(target, clientIdx, clientIdx, 990000.0, DMG_CRUSH | DMG_PREVENT_PHYSICS_FORCE | DMG_ALWAYSGIB);
					if(Calcium_SpawnSkeleton[clientIdx])
						SpawnTheBones(clientIdx, pos2);
				}
				else
				{
					SDKHooks_TakeDamage(target, clientIdx, clientIdx, Calcium_EffectDamage[clientIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE | DMG_ALWAYSGIB);
					if(Calcium_SpawnSkeleton[clientIdx])
						SpawnTheBones(clientIdx, pos2);
				}
			}
		}
	}
	
	int Calcium_Particle_01 = CreateParticle("hammer_bones_kickup", victim_pos);
	int Calcium_Particle_02 = CreateParticle("hammer_bell_ring_shockwave", victim_pos);
	
	if(IsValidEntity(Calcium_Particle_01))
		CreateTimer(10.0, Timer_RemoveEntity, EntIndexToEntRef(Calcium_Particle_01), TIMER_FLAG_NO_MAPCHANGE);
		
	if(IsValidEntity(Calcium_Particle_02))
		CreateTimer(10.0, Timer_RemoveEntity, EntIndexToEntRef(Calcium_Particle_02), TIMER_FLAG_NO_MAPCHANGE);
		
	return Plugin_Continue;
}

public void Rage_Bone_Tornado(int clientIdx, const char[] ability_name, AbilityData ability)
{
	Tornado_Duration[clientIdx] = ability.GetFloat("duration", 1.0) + GetGameTime();
	Tornado_DamagePerTick[clientIdx] = ability.GetFloat("damage per tick", 0.2);
	Tornado_Range[clientIdx] = ability.GetFloat("range", 128.0);
	Tornado_IgnoreInvuln[clientIdx] = ability.GetBool("ignore invuln", false);
	
	SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 2);
	IsTornadoActive[clientIdx] = true;
	SDKHook(clientIdx, SDKHook_PreThink, Tornado_PreThink);
}

public void Tornado_PreThink(int clientIdx)
{
	if(!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
		FF2R_OnBossRemoved(clientIdx);
	
	if(GetGameTime() >= Tornado_Duration[clientIdx])
	{
		SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 5);
		IsTornadoActive[clientIdx] = false;
		SDKUnhook(clientIdx, SDKHook_PreThink, Tornado_PreThink);
	}
		
	if(!FF2R_GetBossData(clientIdx))
	{
		IsTornadoActive[clientIdx] = false;
		SDKUnhook(clientIdx, SDKHook_PreThink, Tornado_PreThink);
	}
	
	float pos1[3], pos2[3];
	GetClientEyePosition(clientIdx, pos1);
	
	int beam_colors[4];
	switch(GetClientTeam(clientIdx))
	{
		case view_as<int>(TFTeam_Blue):
		{
			beam_colors[0] = 0;
			beam_colors[1] = 40;
			beam_colors[2] = 200;
			beam_colors[3] = 255;
		}
		case view_as<int>(TFTeam_Red):
		{
			beam_colors[0] = 200;
			beam_colors[1] = 40;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
		default:
		{
			beam_colors[0] = 0;
			beam_colors[1] = 40;
			beam_colors[2] = 0;
			beam_colors[3] = 255;
		}
	}
		
	
	for(int victim = 1; victim <= MaxClients; victim++)
	{
		if(IsValidClient(victim) && IsPlayerAlive(victim) && victim != clientIdx)
		{
			if(GetClientTeam(victim) != GetClientTeam(clientIdx))
			{	
				GetClientEyePosition(victim, pos2);
				if(GetVectorDistance(pos1, pos2) <= Tornado_Range[clientIdx])
				{
					if(!IsModelPrecached(SPRITE_BEAM) || !IsModelPrecached(SPRITE_HALO))
					{
						LogError("Sprite Models are not precached!");
						return;
					}
					else
					{
						TE_SetupBeamPoints(pos1, pos2, CAL_BeamSprite, CAL_HaloSprite, 0, 25, 0.1, 4.0, 4.5, 0, 2.0, beam_colors, 30);
						TE_SendToAll();
					}
					
					SDKHooks_TakeDamage(victim, clientIdx, clientIdx, Tornado_DamagePerTick[clientIdx], DMG_CRUSH | DMG_PREVENT_PHYSICS_FORCE | DMG_ALWAYSGIB);					
				}
			}
		}
	}
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

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
	if(clientIdx <= 0 || clientIdx > MaxClients)
		return false;

	if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
		return false;

	if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(clientIdx) ||IsClientReplay(clientIdx)))
		return false;

	return true;
}

stock int CreateParticle(const char[] particle_name, const float pos[3])
{
	int iEnt = CreateEntityByName("info_particle_system");
	
	if(IsValidEdict(iEnt))
	{
		TeleportEntity(iEnt, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iEnt, "effect_name", particle_name);
		SetVariantString("!activator");
		DispatchKeyValue(iEnt, "targetname", "present");
		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);
		AcceptEntityInput(iEnt, "Start");
		
		return iEnt;
	}
	
	return -1;
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

stock int SpawnTheBones(int clientIdx, const float pos[3])
{	
	int iTeam = GetClientTeam(clientIdx);
	int iSpell = CreateEntityByName("tf_projectile_spellspawnzombie");
	if(IsValidEdict(iSpell))
	{
		SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", clientIdx);
		SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
		SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));
		
		TeleportEntity(iSpell, pos, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantInt(iTeam);
		AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
		SetVariantInt(iTeam);
		AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0); 
		
		DispatchSpawn(iSpell);
		return iSpell;
	}
	return -1;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) //Borrowed from Apocalips
{
    return entity > MaxClients;
}