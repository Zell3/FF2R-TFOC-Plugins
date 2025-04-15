/*
	"humansentrybuster"	// Ability name can use suffixes
	{
		"delay"		""		// (float)	delay (default = 2.1)
		"range"     ""      // (float)	Range
		"damage"    ""      // (int)	Damage

		"stun"    ""	// (bool)	true = boss stay stun, false = no stun
		"move"		""		// (bool)	true = boss move freely , false = cannot
		"plugin_name"	"ff2r_shadow93_humansentrybuster"
	}
*/

#include <tf2>
#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

float bRange , bDelay;
int bDmg;

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Sentry Buster Ability",
	author = "Koishi (SHADoW NiNE TR3S) fix by zell",
	description = "Only fixed human sentry blaster",
	version = "1.0.1",
	url = ""
};

public void OnPluginStart() {
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
		}
	}
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("humansentrybuster");
		if (ability.IsMyPlugin())
			PrecacheSound("mvm/sentrybuster/mvm_sentrybuster_explode.wav", true);
	}
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "humansentrybuster", false) && cfg.IsMyPlugin()) {
		bDelay = cfg.GetFloat("delay", 2.1);	// delay
		bRange = cfg.GetFloat("range", 500.0);	// range
		bDmg = cfg.GetInt("damage", 500); 	// damage

		if (!cfg.GetBool("move", false))
			CreateTimer(0.1, SentryBustPrepare, client);
			
		CreateTimer(bDelay, SentryBusting, client);
	}
}

public Action SentryBustPrepare(Handle timer, int client) {
	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		FakeClientCommand(client, "taunt");
	SetEntityMoveType(client, MOVETYPE_NONE);
	
	return Plugin_Continue;
}

public Action SentryBusting(Handle timer, int client)
{
	int explosion = CreateEntityByName("env_explosion");
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (explosion) {
		DispatchSpawn(explosion);
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		RemoveEdict(explosion);
	}
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || !IsPlayerAlive(i)) 
			continue;
		float zPos[3];
		GetClientAbsOrigin(i, zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist < bRange)
			DoDamage(client, i, bDmg);
	}

	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		char cls[20];
		GetEntityClassname(i, cls, sizeof(cls));
		if (!StrEqual(cls, "obj_sentrygun", false) &&
		!StrEqual(cls, "obj_dispenser", false) &&
		!StrEqual(cls, "obj_teleporter", false)) continue;
		float zPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist < bRange)
		{
			SetVariantInt(bDmg);
			AcceptEntityInput(i, "RemoveHealth");
		}
	}

	EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	AttachParticle(client, "fluidSmokeExpl_ring_mvm");

	if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
		TF2_RemoveCondition(client,TFCond_Taunting);
	SetEntityMoveType(client, MOVETYPE_WALK);

	return Plugin_Continue;
}

stock void DoDamage(int client, int target, int amount) // from Goomba Stomp.
{
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamageTarget", "explodeme");
		char dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEdict(pointHurt);
	}
}

// from L4D Achievement Trophy
stock bool AttachParticle(int Ent, char[] particleType, bool cache=false) {
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle)) return false;
	char tName[128];
	float f_pos[3];
	if (cache)
		f_pos[2] -= 3000;
	else {
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);
		f_pos[2] += 60;
	}
	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", Ent);
	DispatchKeyValue(Ent, "targetname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(10.0, DeleteParticle, particle);
	return true;
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true) {
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

public Action DeleteParticle(Handle timer, int Ent) {
	if (!IsValidEntity(Ent)) return Plugin_Continue;
	char cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return Plugin_Continue;
}