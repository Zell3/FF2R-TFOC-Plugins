/*
	"dot_weapon_swap"
	{
		"newclassname"      ""              // new weapon: name
		"newattributes"     ""              // new weapon: attributes
		"newindex"          ""             // new weapon: index
		"newlevel"          ""              // new weapon: level
		"newquality"        ""              // new weapon: quality
		"newrank"           ""              // new weapon: rank
		"newshow"           ""              // visibility for new weapon
				
		"oldclassname"      ""              // old weapon: name
		"oldattributes"     ""              // old weapon: attributes
		"oldindex"          ""           // old weapon: index
		"oldlevel"          ""              // old weapon: level
		"oldquality"        ""              // old weapon: quality
		"oldrank"           ""              // old weapon: rank
		"oldshow"           ""              // visibility for old weapon

		"plugin_name"       "ff2r_public_dots"
	}

	"dot_model_swap"
	{
		"ragemodel"							"models\freak_fortress_2\testboss\test_ragemodel.mdl"	// Rage model path
		"use class anims on ragemodel"		"1"													// Should we use class animations on ragemodel? 0 disable 1 enable
		"defaultmodel"						"models\freak_fortress_2\testboss\test_model_02.mdl"	// Default model path									(Uses default boss model if Left Blank)
		"use class anims on defaultmodel"	"1"													// 0 = disable 1 = enable
		"plugin_name"	"ff2r_public_dots"
	}

	"dot_looping_sound"
	{
		"sound"	"buttons/blip1.wav" // sound to play
		"interval"	"1.0" // interval in seconds between plays (automatically converted to ticks)
		"plugin_name"	"ff2r_public_dots"
	}

	"dot_sentry_knockback_immunity"
	{
		"plugin_name"	"ff2r_public_dots"
	}

	"dot_teleport"
	{
		"distance"	"30000.0" // max distance for teleport
		"failsound"	"vo/engineer_no01.wav" // failure sound
		"particle1"	"ghost_smoke"   // particle old points
		"particle2"	"ghost_smoke"   // particle new points
		"sound"	"buttons/blip1.wav" // sound when teleport
		"plugin_name"	"public_dots"
	}
*/

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <cfgmap>
#include <ff2r>
#include <tf2attributes>
#include <ff2r_drain_over_time>
#include <ff2r_drain_over_time_subplugin>

/**
 * Some default drain over time rages. It's a good example if you want to make your own.
 * Requires the drain over time platform:
 * - ff2r_drain_over_time.sp
 * - ff2r_drain_over_time.inc
 * - ff2r_drain_over_time_subplugin.inc
 *
 * Known Issues:
 * WEAPON SWAP
 * - Uses different code for swapping weapons. This fixes the problem with melee swing sometimes not appearing, but causes some weapons which should be
 *   hidden to not be. If you have this problem with a hidden weapon, just use something else.
 * - Has a problem with old models like Vagineer where a weapon appears in the model's center. But this isn't an issue with pony models or stock class models.
 *
 * MODEL SWAP
 * - Could cause problems if your models' skeletons don't line up. Will be a train wreck if your models are rigged to different classes.
 *
 * TELEPORT
 * - It's just a straight port of the otokiru/War3 version, which means all the exploits and stuck bugs will still exist.
 *   I only ported it for demonstration purposes, since conceptually a point teleport makes an excellent one-use reload ability.
 * 
 * Credits:
 * - Most of the work: sarysa
 * - Special thanks to Skeith and Kralthe for testing the manic mode (weapon switch) stuff.
 */
 
#pragma newdecls required

#define MAXTF2PLAYERS	MAXPLAYERS+1

// change this to minimize console output
bool PRINT_DEBUG_INFO = true;

// for getting things off the map that have an undesirable destruction delay (i.e. certain particle effects)
float OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

// this is very generous as really only VSH servers with the RTD mod would have this many
// (RTD allows temporary sentries and permanent dispensers to be spawned by non-engineers)
#define MAX_BUILDINGS 32

// text string limits. I've set these as low as reasonably possible.
// Enumerated strings are VERY wasteful. every character is 4 bytes!
// but the only way to get something resembling a struct is using the enumeration trick below.
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_SWAP_LENGTH 80
#define MAX_WEAPON_NAME_LENGTH 40
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_COLOR_ID_LENGTH 7

bool RoundInProgress = false;

// Weapon Swap
#define WS_STRING "dot_weapon_swap"
#define WS_CW_INTERVAL 0.5 // time between hack-fix for civilian hale
bool WS_ActiveThisRound = false; // internal
float WS_CivilianWorkaroundAt;
bool WS_CanUse[MAXTF2PLAYERS];
bool WS_IsUsing[MAXTF2PLAYERS];
char WS_NewWeaponName[MAXTF2PLAYERS][MAX_WEAPON_NAME_LENGTH];
char WS_NewWeaponArgs[MAXTF2PLAYERS][MAX_WEAPON_ARG_LENGTH];
int WS_NewWeaponIdx[MAXTF2PLAYERS];
int WS_NewWeaponLevel[MAXTF2PLAYERS];
int WS_NewWeaponQuality[MAXTF2PLAYERS];
int WS_NewWeaponRank[MAXTF2PLAYERS];
int WS_NewWeaponVisibility[MAXTF2PLAYERS];
char WS_OldWeaponName[MAXTF2PLAYERS][MAX_WEAPON_NAME_LENGTH];
char WS_OldWeaponArgs[MAXTF2PLAYERS][MAX_WEAPON_ARG_LENGTH];
int WS_OldWeaponIdx[MAXTF2PLAYERS];
int WS_OldWeaponLevel[MAXTF2PLAYERS];
int WS_OldWeaponQuality[MAXTF2PLAYERS];
int WS_OldWeaponRank[MAXTF2PLAYERS];
int WS_OldWeaponVisibility[MAXTF2PLAYERS];

// Model Swap
#define MS_STRING "dot_model_swap"
bool MS_CanUse[MAXTF2PLAYERS];
char MS_OldModelSwap[MAXTF2PLAYERS][MAX_MODEL_SWAP_LENGTH];
int MS_OldAnim[MAXTF2PLAYERS];
char MS_NewModelSwap[MAXTF2PLAYERS][MAX_MODEL_SWAP_LENGTH];
int MS_NewAnim[MAXTF2PLAYERS];

// Sentry Knockback Immunity
#define SKI_STRING "dot_sentry_knockback_immunity"
bool SKI_CanUse[MAXTF2PLAYERS];			// internal
bool SKI_SentryKnockbackImmune[MAXTF2PLAYERS];	// internal

// Looping Sound
#define LS_STRING "dot_looping_sound"
bool LS_CanUse[MAXTF2PLAYERS];				// internal
char LS_Sound[MAXTF2PLAYERS][MAX_SOUND_FILE_LENGTH];	// arg1
int LS_TicksBetweenUses[MAXTF2PLAYERS];			// arg2

// war3 teleport ported as a DOT rage
#define DT_STRING "dot_teleport"
bool DT_CanUse[MAXTF2PLAYERS]; // internal
float DT_MaxDistance[MAXTF2PLAYERS]; // arg1
char DT_FailSound[MAXTF2PLAYERS][MAX_SOUND_FILE_LENGTH]; // arg2
char DT_OldLocationParticleEffect[MAXTF2PLAYERS][MAX_EFFECT_NAME_LENGTH]; // arg3
char DT_NewLocationParticleEffect[MAXTF2PLAYERS][MAX_EFFECT_NAME_LENGTH]; // arg4
char DT_UseSound[MAXTF2PLAYERS][MAX_SOUND_FILE_LENGTH]; // arg5

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Default DOTs",
	author = "sarysa , Zell",
	version = "1.1.0",
}

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

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		if (PRINT_DEBUG_INFO)
			PrintToServer("[public_dots] Default DOTs: Event_RoundStart()");
			
		// NOTE: For DOTs, only basic inits go here. The real init happens on a time delay shortly after.
		// It is recommended you don't load anything related to DOTs until then.
		RoundInProgress = true;
		WS_ActiveThisRound = false;
		WS_CivilianWorkaroundAt = GetEngineTime() + WS_CW_INTERVAL;

		if (PRINT_DEBUG_INFO)
			PrintToServer("[public_dots] Event_RoundStart");
			
		// initialize each DOT's array
		for (int i = 0; i < MaxClients; i++)
		{
			// Weapon Swap
			WS_CanUse[i] = false;
			WS_IsUsing[i] = false;
			
			// Model Swap
			MS_CanUse[i] = false;
			
			// Sentry Knockback Immunity
			SKI_CanUse[i] = false;
			SKI_SentryKnockbackImmune[i] = false;
			
			// Looping Sound
			LS_CanUse[i] = false;
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	if (PRINT_DEBUG_INFO)
		PrintToServer("[public_dots] Event_RoundEnd()");

	// round has ended, this'll kill the looping timer
	RoundInProgress = false;
	WS_ActiveThisRound = false;
		
	// clean up stuff
	for (int clientIdx = 1; clientIdx < MaxClients; clientIdx++)
	{
		if (SKI_CanUse[clientIdx])
		{
			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, SKIOnTakeDamage);
			SKI_CanUse[clientIdx] = false;
		}
	}
}

/**
 * METHODS REQUIRED BY dot subplugin
 */
public void DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToServer("[public_dots] DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	if (PRINT_DEBUG_INFO)
		PrintToServer("[public_dots] DOTPostRoundStartInit() called");
		
	for (int bossClientIdx = 1; bossClientIdx < MaxClients; bossClientIdx++)
	{
		BossData boss = FF2R_GetBossData(bossClientIdx);
		if (!boss)
			continue; // this may seem weird, but rages often break on duo bosses if the leader suicides. these DOTs can be an exception. :D

		// Weapon Swap
		AbilityData weaponswap = boss.GetAbility("dot_weapon_swap")
		WS_CanUse[bossClientIdx] = weaponswap.IsMyPlugin();
		if (WS_CanUse[bossClientIdx])
		{
			WS_ActiveThisRound = true;
			//new weapon
			weaponswap.GetString("newclassname", WS_NewWeaponName[bossClientIdx], MAX_WEAPON_NAME_LENGTH)
			weaponswap.GetString("newattributes", WS_NewWeaponArgs[bossClientIdx], MAX_WEAPON_ARG_LENGTH)
			WS_NewWeaponIdx[bossClientIdx] = weaponswap.GetInt("newindex");
			WS_NewWeaponLevel[bossClientIdx] = weaponswap.GetInt("newlevel");
			WS_NewWeaponQuality[bossClientIdx] = weaponswap.GetInt("newquality");
			WS_NewWeaponRank[bossClientIdx] = weaponswap.GetInt("newrank");
			WS_NewWeaponVisibility[bossClientIdx] = weaponswap.GetInt("newshow");
			//old weapon
			weaponswap.GetString("oldclassname", WS_OldWeaponName[bossClientIdx], MAX_WEAPON_NAME_LENGTH)
			weaponswap.GetString("oldattributes", WS_OldWeaponArgs[bossClientIdx], MAX_WEAPON_ARG_LENGTH)
			WS_OldWeaponIdx[bossClientIdx] = weaponswap.GetInt("oldindex");
			WS_OldWeaponLevel[bossClientIdx] = weaponswap.GetInt("oldlevel");
			WS_OldWeaponQuality[bossClientIdx] = weaponswap.GetInt("oldquality");
			WS_OldWeaponRank[bossClientIdx] = weaponswap.GetInt("oldrank");
			WS_OldWeaponVisibility[bossClientIdx] = weaponswap.GetInt("oldshow");
			
			// switch out the user's primary weapon now, to avoid bugs like EVERY BONK BOY DERIVATIVE EVER MADE :P
			SwitchWeapon(bossClientIdx, WS_OldWeaponName[bossClientIdx], WS_OldWeaponArgs[bossClientIdx], WS_OldWeaponIdx[bossClientIdx], WS_OldWeaponLevel[bossClientIdx], WS_OldWeaponQuality[bossClientIdx], WS_OldWeaponRank[bossClientIdx], WS_OldWeaponVisibility[bossClientIdx]);
			
			if (PRINT_DEBUG_INFO)
				PrintToServer("[public_dots] Boss client %d will use Weapon Swap DOT this round.", bossClientIdx);
		}
		
		// Model Swap
		AbilityData modelswap = boss.GetAbility("dot_model_swap")
		MS_CanUse[bossClientIdx] = modelswap.IsMyPlugin();
		if (MS_CanUse[bossClientIdx])
		{

			modelswap.GetString("ragemodel", MS_NewModelSwap[bossClientIdx], MAX_MODEL_SWAP_LENGTH)
			MS_NewAnim[bossClientIdx] = modelswap.GetInt("use class anims on ragemodel");
			// precache the swap model now, if applicable
			if (strlen(MS_NewModelSwap[bossClientIdx]) > 3)
				PrecacheModel(MS_NewModelSwap[bossClientIdx]);

			modelswap.GetString("defaultmodel", MS_OldModelSwap[bossClientIdx], MAX_MODEL_SWAP_LENGTH)
			MS_OldAnim[bossClientIdx] = modelswap.GetInt("use class anims on defaultmodel")

			if (PRINT_DEBUG_INFO)
				PrintToServer("[public_dots] Boss client %d will use Model Swap DOT this round.", bossClientIdx);
		}
		
		// Sentry Knockback Immunity
		AbilityData sentryimmune = boss.GetAbility("dot_sentry_knockback_immunity")
		SKI_CanUse[bossClientIdx] = sentryimmune.IsMyPlugin();
		if (SKI_CanUse[bossClientIdx]) // create hook for sentry knockback immunity
		{
			SDKHook(bossClientIdx, SDKHook_OnTakeDamage, SKIOnTakeDamage);
			
			if (PRINT_DEBUG_INFO)
				PrintToServer("[public_dots] Boss client %d will use Sentry Knockback Immunity DOT this round.", bossClientIdx);
		}
		
		// Looping Sound
		AbilityData soundloop = boss.GetAbility("dot_looping_sound")
		LS_CanUse[bossClientIdx] = soundloop.IsMyPlugin();
		if (LS_CanUse[bossClientIdx])
		{
			soundloop.GetString("sound", LS_Sound[bossClientIdx], MAX_SOUND_FILE_LENGTH);
			LS_TicksBetweenUses[bossClientIdx] = RoundFloat(soundloop.GetFloat("interval") * 10.0);
			if (LS_TicksBetweenUses[bossClientIdx] <= 0) // don't allow div 0
				LS_TicksBetweenUses[bossClientIdx] = 1;
		}
		
		// teleport
		AbilityData teleport = boss.GetAbility("dot_teleport")
		DT_CanUse[bossClientIdx] = teleport.IsMyPlugin();
		if (DT_CanUse[bossClientIdx])
		{
			DT_MaxDistance[bossClientIdx] = teleport.GetFloat("distance");
			teleport.GetString("failsound", DT_FailSound[bossClientIdx], MAX_SOUND_FILE_LENGTH);

			if (strlen(DT_FailSound[bossClientIdx]) > 3)
				PrecacheSound(DT_FailSound[bossClientIdx]);

			teleport.GetString("startparticle",DT_OldLocationParticleEffect[bossClientIdx],MAX_EFFECT_NAME_LENGTH);
			teleport.GetString("endparticle",DT_NewLocationParticleEffect[bossClientIdx],MAX_EFFECT_NAME_LENGTH);
			teleport.GetString("sound", DT_UseSound[bossClientIdx], MAX_SOUND_FILE_LENGTH);

			if (strlen(DT_UseSound[bossClientIdx]) > 3)
				PrecacheSound(DT_UseSound[bossClientIdx]);
		}
	}
}

public void OnDOTAbilityActivated(int clientIdx)
{
	// Weapon Swap
	if (WS_CanUse[clientIdx])
	{
		WS_IsUsing[clientIdx] = true;
		SwitchWeapon(clientIdx, WS_NewWeaponName[clientIdx], WS_NewWeaponArgs[clientIdx], WS_NewWeaponIdx[clientIdx], WS_NewWeaponLevel[clientIdx], WS_NewWeaponQuality[clientIdx], WS_NewWeaponRank[clientIdx], WS_NewWeaponVisibility[clientIdx]);
	}
	
	// Model Swap
	if (MS_CanUse[clientIdx])
	{
		if (strlen(MS_NewModelSwap[clientIdx]) > 3)
			SwapModel(clientIdx, MS_NewModelSwap[clientIdx], MS_NewAnim[clientIdx]);
	}
	
	// Sentry Knockback Immunity
	if (SKI_CanUse[clientIdx])
	{
		SKI_SentryKnockbackImmune[clientIdx] = true;
	}
	
	// Teleport
	if (DT_CanUse[clientIdx])
	{
		if (!DOTTeleport(clientIdx))
		{
			if (strlen(DT_FailSound[clientIdx]) > 3)
				EmitSoundToClient(clientIdx, DT_FailSound[clientIdx]);
			CancelDOTAbilityActivation(clientIdx);
			return;
		}
	}
}

public void OnDOTAbilityDeactivated(int clientIdx)
{
	// Weapon Swap
	if (WS_CanUse[clientIdx])
	{
		WS_IsUsing[clientIdx] = false;
		SwitchWeapon(clientIdx, WS_OldWeaponName[clientIdx], WS_OldWeaponArgs[clientIdx], WS_OldWeaponIdx[clientIdx], WS_OldWeaponLevel[clientIdx], WS_OldWeaponQuality[clientIdx], WS_OldWeaponRank[clientIdx], WS_OldWeaponVisibility[clientIdx]);
	}
	
	// Model Swap
	if (MS_CanUse[clientIdx])
	{
		if (strlen(MS_NewModelSwap[clientIdx]) > 3) // if the manic mode model swap is invalid, then the switch will never have been made
			SwapModel(clientIdx, MS_OldModelSwap[clientIdx], MS_OldAnim[clientIdx]);
	}
	
	// Sentry Knockback Immunity
	if (SKI_CanUse[clientIdx])
	{
		SKI_SentryKnockbackImmune[clientIdx] = false;
	}
}

public void OnDOTUserDeath(int clientIdx,int isInGame)
{
	// not used by any of these dots
	// there has to be a better way to suppress the warnings :P
	if (clientIdx || isInGame) { }
}

public void OnDOTAbilityTick(int clientIdx, int tickCount)
{
	// Looping Sound
	if (LS_CanUse[clientIdx] && tickCount % LS_TicksBetweenUses[clientIdx] == 0)
	{
		if (strlen(LS_Sound[clientIdx]) > 3)
			EmitSoundToAll(LS_Sound[clientIdx]);
	}
	
	// Teleport
	if (DT_CanUse[clientIdx])
	{
		// since DOT teleport is just a one-time action, deactivate it.
		ForceDOTAbilityDeactivation(clientIdx);
	}
}

/**
 * Ability Specific Methods
 */
// in manic mode, don't take knockback from sentries!
// note, sentry weapon entity is always -1 (recent edit, that "weapon" below is actually an entity index, bah)
char weaponBuffer[64]; // since this'd often get allocated like 500 times per hale match otherwise
public Action SKIOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	BossData boss = FF2R_GetBossData(victim);
	if(!boss)
		return Plugin_Continue;

	if (victim > 0 && victim < MaxClients)
	{
		//PrintToServer("[public_dots] boss attacked for %f damage by weapon %i, a/i=%d,%d...", damage, weapon, attacker, inflictor);
		
		// for reference, tweaking the damageForce/damagePosition did nothing
		if (SKI_SentryKnockbackImmune[victim])
		{
			// validity check, in case player suicides for example
			if (attacker <= MaxClients && attacker > 0)
			{
				// make sure it's an engineer as well
				if (TF2_GetPlayerClass(attacker) == TFClass_Engineer)
				{
					// one last check, check the object entity name
					if (IsValidEntity(inflictor))
					{
						GetEntityClassname(inflictor, weaponBuffer, 64);
						int weaponIdx = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
						if ((!strcmp("obj_sentrygun", weaponBuffer) || !strcmp("tf_projectile_sentryrocket", weaponBuffer)) || weaponIdx == 140) // included wrangler just in case
						{
							damagetype |= DMG_PREVENT_PHYSICS_FORCE;
							return Plugin_Changed;
						}
					}
				}
			}
		}
	}
	else
	{
		if (PRINT_DEBUG_INFO) // never seen this happen but it could be spam-tastic
			PrintToServer("[public_dots] someone we don't care about got attacked for %f damage?!", damage);
	}
	
	return Plugin_Continue;
}

public void SwitchWeapon(int bossClient, char[] weaponName, char[] weaponAttributes, int weaponIdx, int weaponLevel, int weaponQuality, int weaponRank, int visible)
{
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Melee);
	int weapon;
	weapon = SpawnWeapon(bossClient, weaponName, weaponAttributes, weaponIdx, weaponLevel, weaponQuality, weaponRank, visible);
	SetEntPropEnt(bossClient, Prop_Data, "m_hActiveWeapon", weapon);
}

public void SwapModel(int bossClient, const char[] model, int useClassAnims)
{
	SetVariantString(model);
	AcceptEntityInput(bossClient, "SetCustomModel");
	
	if(useClassAnims)
		SetEntProp(bossClient, Prop_Send, "m_bUseClassAnimations", 1);
}

/**
 * DOT_TELEPORT rages, ported from otokiru/War3Source
 */
public bool TracePlayersAndBuildings(int entity, int contentsMask)
{
	if (!IsValidEntity(entity))
		return false;

	// check for mercs
	if (entity > 0 && entity < MaxClients)
	{
		if (IsPlayerAlive(entity) && !TF2_IsPlayerInCondition(entity, TFCond_Cloaked)) {
			BossData boss = FF2R_GetBossData(entity);
			if(!boss)
			return true;
		}
	}
	else
	{
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		if (!strcmp("obj_sentrygun", classname) || !strcmp("obj_dispenser", classname) || !strcmp("obj_teleporter", classname))
			return true;
	}
	
	return false;
}

int absincarray[] = {0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller

public bool CanHitThis(int entityhit, int mask, int data)
{
	if(entityhit == data )
	{// Check if the TraceRay hit the itself.
		return false; // Don't allow self to be hit, skip this result
	}
	if (IsValidBoss(entityhit)){
		return false; //skip result, prend this space is not taken cuz they on same team
	}
	return true; // It didn't hit itself
}

public void GetEmptyLocationHull(int client, float originalpos[3], float emptypos[3])
{
	float mins[3];
	float maxs[3];
	GetClientMins(client,mins);
	GetClientMaxs(client,maxs);
	int absincarraysize=sizeof(absincarray);
	int limit=5000;
	for(int x=0;x<absincarraysize;x++){
		if(limit>0){
			for(int y=0;y<=x;y++){
				if(limit>0){
					for(int z=0;z<=y;z++){
						float pos[3]={0.0,0.0,0.0};
						AddVectors(pos,originalpos,pos);
						pos[0]+=float(absincarray[x]);
						pos[1]+=float(absincarray[y]);
						pos[2]+=float(absincarray[z]);
						TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,CanHitThis,client);
						//new ent;
						if(!TR_DidHit(_))
						{
							AddVectors(emptypos,pos,emptypos); ///set this gloval variable
							limit=-1;
							break;
						}
						if(limit--<0){
							break;
						}
					}
					if(limit--<0){
						break;
					}
				}
			}
			if(limit--<0){
				break;
			}
		}
	}
} 

public bool DOTTeleport(int bossClientIdx)
{
	// taken directly from War3 otokiru with some tweaks
	float eyeAngles[3];
	float bossOrigin[3];
	GetClientEyeAngles(bossClientIdx, eyeAngles);
	float endPos[3];
	float startPos[3];
	GetClientEyePosition(bossClientIdx, startPos);
	float dir[3];
	GetAngleVectors(eyeAngles, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, DT_MaxDistance[bossClientIdx]);
	AddVectors(startPos, dir, endPos);
	GetClientAbsOrigin(bossClientIdx, bossOrigin);
	TR_TraceRayFilter(startPos, endPos, MASK_ALL, RayType_EndPoint, TracePlayersAndBuildings);
	TR_GetEndPosition(endPos);
	float distanceteleport = GetVectorDistance(startPos, endPos);
	GetAngleVectors(eyeAngles, dir, NULL_VECTOR, NULL_VECTOR);///get dir again
	ScaleVector(dir, distanceteleport - 33.0);

	AddVectors(startPos, dir, endPos);
	float emptyPos[3];
	emptyPos[0] = 0.0;
	emptyPos[1] = 0.0;
	emptyPos[2] = 0.0;

	endPos[2] -= 30.0;
	GetEmptyLocationHull(bossClientIdx, endPos, emptyPos);

	if (GetVectorLength(emptyPos) < 1.0)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[public_dots] Teleport failure case: Bad location");
		PrintCenterText(bossClientIdx, "Cannot teleport there!");
		return false;
	}

	TeleportEntity(bossClientIdx, emptyPos, NULL_VECTOR, NULL_VECTOR);
	if (strlen(DT_UseSound[bossClientIdx]) > 3)
	{
		EmitSoundToAll(DT_UseSound[bossClientIdx]);
		EmitSoundToAll(DT_UseSound[bossClientIdx]);
	}
	
	ParticleEffectAt(startPos, DT_OldLocationParticleEffect[bossClientIdx]);
	ParticleEffectAt(emptyPos, DT_NewLocationParticleEffect[bossClientIdx]);
	
	return true;
}

/**
 * Workaround for weapon swap and FF2 1.10.0, some change made causing civilian.
 */
public void OnGameFrame()
{
	if (WS_ActiveThisRound && RoundInProgress)
	{
		if (WS_CivilianWorkaroundAt >= GetEngineTime())
		{
			for (int clientIdx = 1; clientIdx < MaxClients; clientIdx++)
			{
				if (WS_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
				{
					int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
					if (!IsValidEntity(weapon))
					{
						if (PRINT_DEBUG_INFO)
							PrintToServer("[public_dots] Boss %d is civilian. Restoring their weapon.", clientIdx);
						
						TF2_RemoveAllWeapons(clientIdx);
						if (WS_IsUsing[clientIdx])
							SwitchWeapon(clientIdx, WS_NewWeaponName[clientIdx], WS_NewWeaponArgs[clientIdx], WS_NewWeaponIdx[clientIdx], WS_NewWeaponLevel[clientIdx], WS_NewWeaponQuality[clientIdx], WS_NewWeaponRank[clientIdx], WS_NewWeaponVisibility[clientIdx]);
  						else
							SwitchWeapon(clientIdx, WS_OldWeaponName[clientIdx], WS_OldWeaponArgs[clientIdx], WS_OldWeaponIdx[clientIdx], WS_OldWeaponLevel[clientIdx], WS_OldWeaponQuality[clientIdx], WS_OldWeaponRank[clientIdx], WS_OldWeaponVisibility[clientIdx]);
					}
				}
			}
			
			WS_CivilianWorkaroundAt = GetEngineTime() + WS_CW_INTERVAL;
		}
	}
}

/**
 * Support Methods
 */
stock void ParticleEffect(int clientIdx, char[] effectName, float duration)
{
	if (strlen(effectName) < 3)
		return; // nothing to display
	if (duration == 0.0)
		duration = 0.1; // probably doesn't matter for this effect, I just don't feel comfortable passing 0 to a timer
		
	int particle = AttachParticle(clientIdx, effectName, 75.0, true);
	if (IsValidEntity(particle))
		CreateTimer(duration, RemoveEntityDA, EntIndexToEntRef(particle));
}

// a duration of 0.0 below means that it won't be removed by a timer
// and instead must be managed by the programmer
stock int ParticleEffectAt(float position[3], char[] effectName, float duration = 0.0)
{
	if (strlen(effectName) < 3)
		return -1; // nothing to display
		
	int particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if (duration > 0.0)
			CreateTimer(duration, RemoveEntityDA, EntIndexToEntRef(particle));
	}
	return particle;
}

/**
 * CODE BELOW WAS TAKEN FROM ff2_1st_set_abilities, I TAKE NO CREDIT FOR IT
 */
public int SpawnWeapon(int client, char[] name, char[] attribute, int index, int level, int quality, int kills, int visible)
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2=0;
		for(int i=0; i<count; i+=2)
		{
			int attrib=StringToInt(attributes[i]);
			if(attrib==0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}
	if(weapon==INVALID_HANDLE)
	{
		return -1;
	}
	int entity=TF2Items_GiveNamedItem(client, weapon);

	if(kills >= 0)
	TF2Attrib_SetByDefIndex(entity, 214, view_as<float>(kills));

	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);

	// sarysa addition, since cheese's weapons are currently invisible
	if (!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", -1, _, 0);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);

		// SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
    // SetEntityRenderColor(entity, 0, 0, 0, 0);
	}
	
	return entity;
}

stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MaxClients)
		return false;
		
	return IsValidClient(clientIdx) && IsPlayerAlive(clientIdx);
}

stock bool IsValidBoss(int clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return false;
	
	BossData boss = FF2R_GetBossData(clientIdx);
	if(!boss)
		return false;

	return true;
}

/**
 * CODE BELOW TAKEN FROM default_abilities, I CLAIM NO CREDIT
 */
public Action DestroyEntity(Handle timer, int entid) // well, this one's mine. ;P need to make slow kill entities disappear while they die.
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
	{
		// may not be the best way to handle this, but I can't find documentation re: toggling visibility. bah.
		// and the few lists of entity props I could find don't include it, so...
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
		RemoveEntityDA(timer, entid);
	}
	return Plugin_Continue;
}

public Action RemoveEntityDA(Handle timer, int entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		AcceptEntityInput(entity, "Kill");
	}
		
	return Plugin_Continue;
}

public int AttachParticle(int entity, char[] particleType, float offset, bool attach)
{
	int particle = CreateEntityByName("info_particle_system");

	if (!IsValidEntity(particle))
		return -1;
	char targetName[128];
	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
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