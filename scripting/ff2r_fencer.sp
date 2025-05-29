/*
	"special_smoke"
	{
		"slot"			"0"
		"setup"			"true"	// works only on setup
		"delay"			"0.5"
		"thickness"		"60"
		"color"			"10 10 10"
		"spread"		"100"
		"spread speed"	"140"
		"start size"	"200"
		"end size"		"2"	
		"alpha"			"255"
		"duration"		"1.0"
		"plugin_name"	"ff2r_fencer"	// This subplugin name
	}
	
	"rage_smoke"
	{
		"slot"			"0"
		"delay"			"0.0"
		"thickness"		"60"
		"color"			"10 10 10"
		"spread"		"100"
		"spread speed"	"140"
		"start size"	"200"
		"end size"		"2"	
		"alpha"			"255"
		"duration"		"0.5"
		"plugin_name"	"ff2r_fencer"	// This subplugin name
	}
	
	"rage_next_hit"
	{
		"slot"			"0"
		"stun"			""				// Stun duration
		"flags"			""				// Stun flags
		"slowdown"		""				// Stun slowdown ratio
		"particle"		""				// Stun particle
		"duration"		"10.0"			// Duration in seconds before effect decays
		"plugin_name"	"ff2r_fencer"	// This subplugin name
	}
	
	
	
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf_ontakedamage>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Fencer"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Fencer's Unique Abilities"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXTF2PLAYERS	36

#define SPRITE "materials/sprites/dot.vmt"

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};

/*
Handle MenuTimer[MAXTF2PLAYERS];
bool ViewingMenu[MAXTF2PLAYERS];
bool SetupMode[MAXTF2PLAYERS];
*/

public void OnPluginStart()
{
	LoadTranslations("ff2_rewrite.phrases");
	LoadTranslations("core.phrases");
	if(!TranslationPhraseExists("Ability Delay"))
		SetFailState("Translation file \"ff2_rewrite.phrases\" is outdated");
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	//HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	//HookEvent("object_deflected", OnObjectDeflected, EventHookMode_Post);
	
	// Lateload Support
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if(IsClientInGame(clientIdx))
		{
			BossData cfg = FF2R_GetBossData(clientIdx);			
			if(cfg)
				FF2R_OnBossCreated(clientIdx, cfg, false);
		}
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(victim)
	{
		//FF2R_OnBossRemoved(victim);
	}
}

/*
public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom, CritType &critType)
{
	if(!IsValidClient(victim))
		return Plugin_Continue;
		
	if(MG_Enabled[victim])			// For Market Gardens
	{
		if(!IsValidClient(attacker) || !RocketJumping[attacker] || !IsValidEntity(weapon) || GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != 416)
			return Plugin_Continue;
			
		damage = damage * MG_Scale[victim];
		
		if(MG_Bleed[victim] > 0.0)
		{
			TF2_MakeBleed(attacker, victim, MG_Bleed[victim]);
		}
		
		return Plugin_Continue;
	}
	
	if(BS_Enabled[victim] && damagecustom == TF_CUSTOM_BACKSTAB)	// For Backstabs
	{
		damage = damage * BS_Scale[victim];
		
		if(BS_Bleed[victim] > 0.0)
		{
			TF2_MakeBleed(attacker, victim, BS_Bleed[victim]);
		}
		
		return Plugin_Changed;
	}
	
	if(DS_Mark[victim])
	{
		damage = damage * DS_DamageRatio[victim];
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
*/

public void OnMapStart()
{
	PrecacheGeneric(SPRITE, true);
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{	
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
		
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "rage_smoke", false))
	{
		float delay = cfg.GetFloat("delay", 1.0);
		CreateTimer(delay, Timer_Rage_Smoke, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void FF2R_OnBossCreated(int clientIdx, BossData boss, bool setup)
{
	AbilityData ability;
	
	ability = boss.GetAbility("special_smoke");
	if(ability.IsMyPlugin())
	{
		if(!ability.GetBool("enabled", true))
			return;
			
		if(ability.GetBool("setup", true) && !setup)
			return;
	
		float delay = ability.GetFloat("delay", 1.0);
		CreateTimer(delay, Timer_Special_Smoke, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	ability = boss.GetAbility("special_player_color");
	if(ability.IsMyPlugin())
	{
		if(!ability.GetBool("enabled", true))
			return;
	
		int r = ability.GetInt("red", 255);
		int g = ability.GetInt("green", 255);
		int b = ability.GetInt("blue", 255);
		int a = ability.GetInt("alpha", 255);
		
		SetEntityRenderMode(clientIdx, RENDER_TRANSCOLOR);
		SetEntityRenderColor(clientIdx, r, g, b, a);
	}
	
	if(!setup || FF2R_GetGamemodeType() != 2)
	{
		/*
		ability = boss.GetAbility("special_menu");
		if(ability.IsMyPlugin())
		{
			
		}
		*/
	}
}



stock int CreateViewEntity(int clientIdx, float pos[3])
{
	int entity = CreateEntityByName("env_sprite");
	if(entity)
	{
		DispatchKeyValue(entity, "model", SPRITE);
		DispatchKeyValue(entity, "renderamt", "0");
		DispatchKeyValue(entity, "rendercolor", "0 0 0");
		DispatchSpawn(entity);
		
		float angle[3];
		GetClientEyeAngles(clientIdx, angle);
		
		TeleportEntity(entity, pos, angle, NULL_VECTOR);
		TeleportEntity(clientIdx, NULL_VECTOR, angle, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", clientIdx, entity, 0);
		SetClientViewEntity(clientIdx, entity);
		return entity;
	}
	return -1;
}

public Action Timer_Rage_Smoke(Handle timer, int userid)
{
	int clientIdx = GetClientOfUserId(userid);
	if(!clientIdx)
		return Plugin_Continue;
		
	CreateSmoke(clientIdx, FF2R_GetBossData(clientIdx).GetAbility("rage_smoke"));
	return Plugin_Continue;
}

public Action Timer_Special_Smoke(Handle timer, int userid)
{
	int clientIdx = GetClientOfUserId(userid);
	if(!clientIdx)
		return Plugin_Continue;
		
	CreateSmoke(clientIdx, FF2R_GetBossData(clientIdx).GetAbility("special_smoke"));
	return Plugin_Continue;
}

public void CreateSmoke(int clientIdx, AbilityData ability)
{
	if(!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx) || !FF2R_GetBossData(clientIdx))
		return;
	
	int iEnt = CreateEntityByName("env_smokestack");
	if(iEnt)
	{
		char buffer[128];
		
		float pos1[3];
		GetClientAbsOrigin(clientIdx, pos1);
		
		Format(buffer, sizeof(buffer), "Smoke%i", clientIdx);
		DispatchKeyValue(iEnt, "targetname", buffer);
		
		Format(buffer, sizeof(buffer), "%f %f %f", pos1[0], pos1[1], pos1[2]);
		DispatchKeyValue(iEnt, "Origin", buffer);
		
		ability.GetString("spread", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "BaseSpread", buffer);
		
		ability.GetString("spread speed", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "SpreadSpeed", buffer);
		
		ability.GetString("speed", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "Speed", buffer);
		
		ability.GetString("start size", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "StartSize", buffer);
		
		ability.GetString("end size", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "EndSize", buffer);
		
		ability.GetString("thickness", buffer, sizeof(buffer));	//100
		DispatchKeyValue(iEnt, "Rate", buffer);
		
		DispatchKeyValue(iEnt, "JetLength", "400");
		DispatchKeyValue(iEnt, "Twist", "20"); 
		
		ability.GetString("color", buffer, sizeof(buffer));	//30 30 30
		DispatchKeyValue(iEnt, "RenderColor", buffer);
		
		ability.GetString("alpha", buffer, sizeof(buffer));	//200
		DispatchKeyValue(iEnt, "RenderAmt", buffer);
		
		DispatchKeyValue(iEnt, "SmokeMaterial", "particle/particle_smokegrenade1.vmt");
		
		DispatchSpawn(iEnt);
		AcceptEntityInput(iEnt, "TurnOn");
		
		float duration = ability.GetFloat("duration", 4.0);
		
		CreateTimer(duration, Timer_StopSmoke, EntIndexToEntRef(iEnt), TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(duration + 5.0, Timer_RemoveEntity, EntIndexToEntRef(iEnt), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_StopSmoke(Handle timer, int entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity > MaxClients)
	{
		AcceptEntityInput(entity, "TurnOff");
	}
	return Plugin_Continue;
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity > MaxClients)
	{
		TeleportEntity(entity, view_as<float>( { 16383.0, 16383.0, -16383.0 } ), NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
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
