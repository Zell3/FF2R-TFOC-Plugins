/*
	"dot_base"
	{
		"ragemin"					"15"			// minimum rage to activate
		"ragedrain"					"0.0"			// rage % drain per 100ms
		"startragepenalty"			"15.0"			// rage penalty for entry
		"endragepenalty"			"0.0"			// rage penalty for ending it manually
		"startsound"				""				// "vs_ponyville\cheese\cs_mm_enter.mp3" // sound to play when entering rage
		"endsound"					""				// "vs_ponyville\cheese\cs_mm_exit.mp3" // sound to play when exiting rage
		"startparticlename"			"bday_confetti" // particle effect to apply to user when entering rage
		"startparticleduration"		"0.0"			// duration of above particle effect (not necessarily applicable)
		"endparticlename"			"ghost_smoke"	// particle effect to apply to user when exiting rage
		"endparticleduration"		"0.0"			// duration of above particle effect (not necessarily applicable)
		"condition"					""				// conditions to add during DOT, format like weapon attributes. i.e. 3 ; 23 ; 47 [strict space-semicolon-space between each condition, max 10]
		"nooverlay"					"0"				// if this is 1, it won't show the helpful reload overlay message. probably should only use this if your boss needs overlays elsewhere.
		"cooldown"					"2.0"			// cooldown duration in seconds
		"buttonmode"				"1"				// 0 = RELOAD, 1 = MOUSE3, 2 = MOUSE2  
		"allowstun"					"1"				// 0 = not allow to use dot while stun , 1 = allow

		"plugin_name"	"ff2r_drain_over_time"
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

/**
 * A platform for drain over time rages. Combines all the common aspects of such rages to
 * simplify other drain over time rages' code and configuration.
 *
 * KNOWN ISSUES:
 *	- Turning all three Vaccinator conditions on at the same time is definitely unsafe, a certain key combo from the player
 *		(reload, attack, movement dirs) can crash the server, usually when spamming R.
 *		As for individual Vaccinator conditions, your guess is as good as mine.
 *
 * Revamped on 2015-03-21
 */

// change this to minimize console output
int PRINT_DEBUG_INFO = true;

#pragma semicolon 1
#pragma newdecls required

#define MAXTF2PLAYERS	MAXPLAYERS+1

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_WEAPON_NAME_LENGTH 40
#define MAX_EFFECT_NAME_LENGTH 48

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)


// handle needed for the method shared by sub-plugins
Handle Handle_OnDOTAbilityActivated;
Handle Handle_OnDOTAbilityDeactivated;
Handle Handle_OnDOTUserDeath; // in case cleanup is necessary
Handle Handle_OnDOTAbilityTick;
Handle Handle_DOTPostRoundStartInit;

// shared variables
bool RoundInProgress = false;

// according to the good folks at AlliedModders, this is as close as I'll get to a struct or a class
// but this mod needs to handle multiple bosses.
#define DOT_INTERVAL 0.1
#define MAX_CONDITIONS 10
#define CONDITION_DELIM " ; " // I'm going with this because people are already using this format for weapon attributes
#define CONDITION_DELIM_SHORT ";" // one year later, I realize how stupid my logic was with the above.
#define CONDITION_STRING_LENGTH (MAX_CONDITIONS * 3 + ((MAX_CONDITIONS - 1) * 3) + 1) // ### ; ### ; ### ; ###... (3-digit conditions will exist pretty soon, I'd think)
bool DOT_ActiveThisRound = false;
float DOT_NextTick;
bool DOT_CanUse[MAXTF2PLAYERS];
float DOT_TimeOfLastSound[MAXTF2PLAYERS];
bool DOT_ReloadDown[MAXTF2PLAYERS];
bool DOT_RageActive[MAXTF2PLAYERS];
int DOT_ActiveTickCount[MAXTF2PLAYERS];
bool DOT_OverlayVisible[MAXTF2PLAYERS];
bool DOT_ActivationCancel[MAXTF2PLAYERS];
bool DOT_ForceDeactivation[MAXTF2PLAYERS];
bool DOT_Usable[MAXTF2PLAYERS];
bool DOT_IsOnCooldown[MAXTF2PLAYERS];
int DOT_CooldownTicksRemaining[MAXTF2PLAYERS];
bool DOT_ReloadPressPending[MAXTF2PLAYERS];
float DOT_MinRage[MAXTF2PLAYERS]; // arg1
float DOT_RageDrain[MAXTF2PLAYERS]; // arg2
float DOT_EnterPenalty[MAXTF2PLAYERS]; // arg3
float DOT_ExitPenalty[MAXTF2PLAYERS]; // arg4
char DOT_EntrySound[MAXTF2PLAYERS][MAX_SOUND_FILE_LENGTH]; // arg5
char DOT_ExitSound[MAXTF2PLAYERS][MAX_SOUND_FILE_LENGTH]; // arg6
char DOT_EntryEffect[MAXTF2PLAYERS][MAX_EFFECT_NAME_LENGTH]; // arg7
float DOT_EntryEffectDuration[MAXTF2PLAYERS]; // arg8
char DOT_ExitEffect[MAXTF2PLAYERS][MAX_EFFECT_NAME_LENGTH]; // arg9: Rage exit particle effect
float DOT_ExitEffectDuration[MAXTF2PLAYERS]; // arg10: Duration of said particle effect
int DOT_ConditionChanges[MAXTF2PLAYERS][MAX_CONDITIONS]; // arg11: Conditions to add (and then subsequently remove) during the reload-activated rage.
bool DOT_NoOverlay[MAXTF2PLAYERS]; // arg12: Don't use overlay
int DOT_CooldownDurationTicks[MAXTF2PLAYERS]; // arg13: Tick count for cooldown
int DOT_ActivationKey[MAXTF2PLAYERS]; // arg14: Activation key (IN_RELOAD or IN_ATTACK3)
bool DOT_AllowWhileStunned[MAXTF2PLAYERS]; // arg15

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Drain Over Time Platform",
	author = "sarysa fix by zell",
	version = "1.1.0",
};

public void OnDOTAbilityActivated(int clientIdx)
{
	Action act = Plugin_Continue;	
	Call_StartForward(Handle_OnDOTAbilityActivated);
	Call_PushCell(clientIdx);
	Call_Finish(act);
}

public void OnDOTAbilityDeactivated(int clientIdx)
{
	Action act = Plugin_Continue;	
	Call_StartForward(Handle_OnDOTAbilityDeactivated);
	Call_PushCell(clientIdx);
	Call_Finish(act);
}

public void OnDOTAbilityTick(int clientIdx, int tickCount)
{
	Action act = Plugin_Continue;	
	Call_StartForward(Handle_OnDOTAbilityTick);
	Call_PushCell(clientIdx);
	Call_PushCell(tickCount);
	Call_Finish(act);
}

public void OnDOTUserDeath(int clientIdx, int isInGame)
{
	if (isInGame)
		RemoveDOTOverlay(clientIdx);

	Action act = Plugin_Continue;	
	Call_StartForward(Handle_OnDOTUserDeath);
	Call_PushCell(clientIdx);
	Call_PushCell(isInGame);
	Call_Finish(act);
}

public void DOTPostRoundStartInit()
{
	Action act = Plugin_Continue;
	Call_StartForward(Handle_DOTPostRoundStartInit);
	Call_Finish(act);
}

public void OnMapStart()
{
	// // Make the clients download the overlays, since pretty much everyone forgot to put those in the boss' config
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay1.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay1.vtf");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay2.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay2.vtf");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay1.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay1.vtf");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay2.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay2.vtf");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay1.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay1.vtf");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay2.vmt");
	// AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay2.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay1.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay1.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay2.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/alt_fire_overlay2.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay1.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay1.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay2.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/attack3_overlay2.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay1.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay1.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay2.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/dots/reload_overlay2.vtf");
}


public void OnPluginStart() {
	// handles for global forwards
	Handle_OnDOTAbilityActivated = CreateGlobalForward("OnDOTAbilityActivatedInternal", ET_Hook, Param_Cell);
	Handle_OnDOTAbilityDeactivated = CreateGlobalForward("OnDOTAbilityDeactivatedInternal", ET_Hook, Param_Cell);
	Handle_OnDOTAbilityTick = CreateGlobalForward("OnDOTAbilityTickInternal", ET_Hook, Param_Cell, Param_Cell);
	Handle_DOTPostRoundStartInit = CreateGlobalForward("DOTPostRoundStartInitInternal", ET_Hook);
	Handle_OnDOTUserDeath = CreateGlobalForward("OnDOTUserDeathInternal", ET_Hook, Param_Cell, Param_Cell);

	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}

	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		// set all clients to inactive
		for (int clientIdx = 0; clientIdx < MaxClients; clientIdx++)
		{
			DOT_CanUse[clientIdx] = false;
			DOT_ReloadDown[clientIdx] = false;
			DOT_RageActive[clientIdx] = false;
			DOT_OverlayVisible[clientIdx] = false;
			DOT_ActivationCancel[clientIdx] = false;
			DOT_Usable[clientIdx] = true;
			DOT_NoOverlay[clientIdx] = false;
			DOT_IsOnCooldown[clientIdx] = false;
			DOT_ReloadPressPending[clientIdx] = false;
			for (int i = 0; i < MAX_CONDITIONS; i++)
				DOT_ConditionChanges[clientIdx][i] = -1;
		}
		
		// initialize these
		DOT_ActiveThisRound = false;
		DOT_NextTick = FAR_FUTURE;
	
		// round is now in progress
		RoundInProgress = true;
	
		// post-round start inits
		CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
			
	}
}

public void OnPluginEnd() {
  UnhookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}

public Action Timer_PostRoundStartInits(Handle timer)
{
	// edge case: user suicided
	if (!RoundInProgress)
	{
		PrintToServer("[drain_over_time] Timer_PostRoundStartInits() in ff2r_drain_over_time called after round ended. User probably suicided.");
		return Plugin_Stop;
	}

	int dotUserCount = 0;

	for (int clientIdx = 1; clientIdx < MaxClients; clientIdx++) // make no boss count assumptions, though anything above 3 is very weird
	{		
		if (!IsLivingPlayer(clientIdx))
			continue;
		
		
		BossData boss = FF2R_GetBossData(clientIdx);
		
		if (!boss)
			continue;

		AbilityData ability = boss.GetAbility("dot_base");
		if (!ability.IsMyPlugin())
			continue;		
		
		DOT_ActiveThisRound = true; // looks like we'll start the looping timer.
		// now lets set this user's parameters!
		DOT_CanUse[clientIdx] = true;
		DOT_MinRage[clientIdx] = ability.GetFloat("ragemin");
		DOT_RageDrain[clientIdx] = ability.GetFloat("ragedrain");
		DOT_EnterPenalty[clientIdx] = ability.GetFloat("startragepenalty");
		DOT_ExitPenalty[clientIdx] = ability.GetFloat("endragepenalty");

		ability.GetString("startsound",DOT_EntrySound[clientIdx],MAX_SOUND_FILE_LENGTH);
		ability.GetString("endsound",DOT_ExitSound[clientIdx],MAX_SOUND_FILE_LENGTH);
		if (strlen(DOT_EntrySound[clientIdx]) > 3)
			PrecacheSound(DOT_EntrySound[clientIdx], true);
		if (strlen(DOT_ExitSound[clientIdx]) > 3)	
			PrecacheSound(DOT_ExitSound[clientIdx], true);
					
		ability.GetString("startparticlename",DOT_EntryEffect[clientIdx],MAX_EFFECT_NAME_LENGTH);
		DOT_EntryEffectDuration[clientIdx] = ability.GetFloat("startparticleduration");
		ability.GetString("startparticlename",DOT_ExitEffect[clientIdx],MAX_EFFECT_NAME_LENGTH);
		DOT_ExitEffectDuration[clientIdx] = ability.GetFloat("endparticleduration");
					
		static char conditionStr[CONDITION_STRING_LENGTH];
		static char conditions[MAX_CONDITIONS][4];

		ability.GetString("condition",conditionStr,sizeof(conditionStr));

		if (!IsEmptyString(conditionStr))
		{
			int conditionCount = 0;
			if (StrContains(conditionStr, CONDITION_DELIM) < 0)
				conditionCount = ExplodeString(conditionStr, CONDITION_DELIM_SHORT, conditions, MAX_CONDITIONS, 4);
			else
				conditionCount = ExplodeString(conditionStr, CONDITION_DELIM, conditions, MAX_CONDITIONS, 4);
			for (int condIdx = 0; condIdx < conditionCount; condIdx++)
			{
				DOT_ConditionChanges[clientIdx][condIdx] = StringToInt(conditions[condIdx]);
				//PrintToServer("[drain_over_time] Condition: %d", DOT_ConditionChanges[clientIdx][condIdx]);
			}
		}

		DOT_NoOverlay[clientIdx] = ability.GetInt("nooverlay") == 1;
		DOT_CooldownDurationTicks[clientIdx] = RoundFloat(ability.GetFloat("cooldown") * 10.0);
		DOT_ActivationKey[clientIdx] = ability.GetInt("buttonmode");
		DOT_AllowWhileStunned[clientIdx] = ability.GetInt("allowstun") == 1;
					
		// fix activation key
		switch(DOT_ActivationKey[clientIdx])
		{
			case 0: DOT_ActivationKey[clientIdx] = IN_RELOAD;
			case 1: DOT_ActivationKey[clientIdx] = IN_ATTACK3;
			case 2: DOT_ActivationKey[clientIdx] = IN_ATTACK2;
		}

		// warn user of mistake
		if (DOT_MinRage[clientIdx] < DOT_EnterPenalty[clientIdx])
			PrintToServer("[drain_over_time] For %d, minimum rage (%f) < rage entry cost (%f), should set minimum higher!", clientIdx, DOT_MinRage, DOT_EnterPenalty);

		// init this just in case
		DOT_TimeOfLastSound[clientIdx] = GetEngineTime();

		// debug only
		dotUserCount++;

	}

	if (DOT_ActiveThisRound)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[drain_over_time] DOT rage on %d boss(es) this round.", dotUserCount);
		DOTPostRoundStartInit();
		DOT_NextTick = GetEngineTime() + DOT_INTERVAL;
	}
	else
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[drain_over_time] No DOT rage users this round.");
	}
	
	return Plugin_Stop;
}

public void FF2R_OnBossRemoved(int client) {
	// round has ended, this'll kill the looping timer
	RoundInProgress = false;
	// remove overlays for all bosses
	for (int clientIdx = 0; clientIdx < MaxClients; clientIdx++)
	{
		if (DOT_CanUse[clientIdx])
			RemoveDOTOverlay(clientIdx);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}


public void CancelDOTAbilityActivation(int clientIdx)
{
	//new clientIdx = GetNativeCell(1);
	DOT_ActivationCancel[clientIdx] = true;
}

public void ForceDOTAbilityDeactivation(int clientIdx)
{
	//new clientIdx = GetNativeCell(1);
	if (DOT_RageActive[clientIdx])
		DOT_ForceDeactivation[clientIdx] = true;
}

public void SetDOTUsability(int clientIdx, int usability)
{
	//new clientIdx = GetNativeCell(1);
	//new bool:usability = GetNativeCell(2) == 1;
	DOT_Usable[clientIdx] = usability == 1;
}


// ensure that sounds are not spammed by user spamming R. two seconds between sounds played
public void PlaySoundLocal(int clientIdx, const char[] soundPath)
{
	if (DOT_TimeOfLastSound[clientIdx] + 2.0 > GetEngineTime()) // two second interval check
		return; // prevent spam
	else if (strlen(soundPath) < 3)
		return; // nothing to play
		
	// play a speech sound that travels normally, local from the player.
	// I can swear that sounds are louder from eye position than origin...
	float playerPos[3];
	//GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", playerPos);
	GetClientEyePosition(clientIdx, playerPos);
	EmitAmbientSound(soundPath, playerPos, clientIdx);
	DOT_TimeOfLastSound[clientIdx] = GetEngineTime();
}

// also need to ensure this one isn't spammed
public void TransitionEffect(int clientIdx, char[] effectName, float duration)
{
	if (IsEmptyString(effectName))
		return; // nothing to play
	if (duration == 0.0)
		duration = 0.1; // probably doesn't matter for this effect, I just don't feel comfortable passing 0 to a timer
		
	float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	int particle = AttachParticle(clientIdx, effectName, 75.0, true);
	if (IsValidEntity(particle))
		CreateTimer(duration, RemoveEntityDA, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
}

// repeating timers documented here: https://wiki.alliedmods.net/Timers_%28SourceMod_Scripting%29
int overlayTickCount = 0;
public Action TickDOTs(float curTime)
{
	if (curTime >= DOT_NextTick)
		overlayTickCount++;
		
	for (int clientIdx = 1; clientIdx < MaxClients; clientIdx++)
	{
		// only bother if client is using the plugin
		if (!DOT_CanUse[clientIdx])
			continue;
		else if (!IsLivingPlayer)
		{
			OnDOTUserDeath(clientIdx, IsClientInGame(clientIdx) ? 1 : 0);
			DOT_CanUse[clientIdx] = false;
			continue;
		}
		else if (curTime < DOT_NextTick)
			continue;
		
		if (DOT_IsOnCooldown[clientIdx])
		{
			DOT_CooldownTicksRemaining[clientIdx]--;
			if (DOT_CooldownTicksRemaining[clientIdx] <= 0)
				DOT_IsOnCooldown[clientIdx] = false;
		}
			
		bool dotRageStart = false;
		bool dotRageStop = false;
		float ragePenalty = 0.0;
		BossData boss = FF2R_GetBossData(clientIdx);
		float rage = GetBossCharge(boss, "0");
		if (DOT_ReloadPressPending[clientIdx])
		{
			if (DOT_RageActive[clientIdx]) // player manually stops the DOT
			{
				ragePenalty = DOT_ExitPenalty[clientIdx];
				dotRageStop = true;
			}
			else if (rage >= DOT_MinRage[clientIdx]) // player enters DOT
				dotRageStart = true;
				
			DOT_ReloadPressPending[clientIdx] = false;
		}
		
		// drain rage if DOT is active
		if (DOT_RageActive[clientIdx])
		{
			rage -= DOT_RageDrain[clientIdx];
			if (rage < 0.0)
			{
				dotRageStop = true; // force player out of manic mode
				rage = 0.0;
			}
			SetBossCharge(boss, "0", rage);
		}
		
		// don't start rage if on cooldown
		if (DOT_IsOnCooldown[clientIdx])
			dotRageStart = false;

		// leaks shouldn't ever happen here, but it's better for most plugins to get the exit after the enter
		if (dotRageStart && DOT_Usable[clientIdx] && !DOT_ForceDeactivation[clientIdx])
		{
			OnDOTAbilityActivated(clientIdx);
			if (!DOT_ActivationCancel[clientIdx])
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[drain_over_time] %d entered DOT rage. (cooldown=%d ticks)", clientIdx, DOT_CooldownDurationTicks[clientIdx]);
				PlaySoundLocal(clientIdx, DOT_EntrySound[clientIdx]);
				TransitionEffect(clientIdx, DOT_EntryEffect[clientIdx], 1.5);
				DOT_RageActive[clientIdx] = true;
				DOT_ActiveTickCount[clientIdx] = 0;
				ragePenalty = DOT_EnterPenalty[clientIdx];
				RemoveDOTOverlay(clientIdx);

				// add conditions
				for (int condIdx = 0; condIdx < MAX_CONDITIONS; condIdx++)
				{
					if (DOT_ConditionChanges[clientIdx][condIdx] == -1)
						break;

					TF2_AddCondition(clientIdx, view_as<TFCond>(DOT_ConditionChanges[clientIdx][condIdx]), -1.0);
				}
				
				// cooldown
				if (DOT_CooldownDurationTicks[clientIdx] > 0)
				{
					DOT_IsOnCooldown[clientIdx] = true;
					DOT_CooldownTicksRemaining[clientIdx] = DOT_CooldownDurationTicks[clientIdx];
				}
			}
		}
		if (DOT_RageActive[clientIdx] && !DOT_ActivationCancel[clientIdx] && !DOT_ForceDeactivation[clientIdx])
		{
			OnDOTAbilityTick(clientIdx, DOT_ActiveTickCount[clientIdx]);
			DOT_ActiveTickCount[clientIdx]++;
		}
		if (dotRageStop || DOT_ActivationCancel[clientIdx] || (DOT_RageActive[clientIdx] && DOT_ForceDeactivation[clientIdx]))
		{
			OnDOTAbilityDeactivated(clientIdx);
			if (!DOT_ActivationCancel[clientIdx])
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[drain_over_time] %d exited DOT rage.", clientIdx);
				PlaySoundLocal(clientIdx, DOT_ExitSound[clientIdx]);
				TransitionEffect(clientIdx, DOT_ExitEffect[clientIdx], 1.5);
				DOT_RageActive[clientIdx] = false;

				// remove conditions
				for (int condIdx = 0; condIdx < MAX_CONDITIONS; condIdx++)
				{
					if (DOT_ConditionChanges[clientIdx][condIdx] == -1)
						break;
					
					if (TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(DOT_ConditionChanges[clientIdx][condIdx])))
						TF2_RemoveCondition(clientIdx, view_as<TFCond>(DOT_ConditionChanges[clientIdx][condIdx]));
				}
			}
			DOT_ActivationCancel[clientIdx] = false;
			DOT_ForceDeactivation[clientIdx] = false;
		}
		
		// in some cases, standard rages may force the deactivation of a DOT, but it has no way of knowing if it's
		// really active. just silently set this to false in such a case.
		if (!DOT_RageActive[clientIdx] && DOT_ForceDeactivation[clientIdx])
			DOT_ForceDeactivation[clientIdx] = false;
		
		// handle any rage penalties, entry or exit
		if (ragePenalty > 0)
		{
			rage -= ragePenalty;
			if (rage < 0.0)
				rage = 0.0;
			SetBossCharge(boss, "0", rage);
		}
		
		// DOT overlay, some conditions for its appearance and removal
		if (DOT_RageActive[clientIdx] || (rage >= DOT_MinRage[clientIdx] && !DOT_IsOnCooldown[clientIdx]))
			DisplayDOTOverlay(clientIdx);
		else if ((rage < DOT_MinRage[clientIdx] || DOT_IsOnCooldown[clientIdx]) && DOT_OverlayVisible[clientIdx])
			RemoveDOTOverlay(clientIdx); // this only happens if standard 100% rage is used
	}
	
	if (curTime >= DOT_NextTick)
		DOT_NextTick += DOT_INTERVAL; // get more accuracy with these ticks
		
	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (DOT_ActiveThisRound && RoundInProgress)
		TickDOTs(GetEngineTime());
}

public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!DOT_ActiveThisRound || !RoundInProgress || !IsValidClient(clientIdx) && IsPlayerAlive(clientIdx) || !DOT_CanUse[clientIdx])
		return Plugin_Continue;

	// check key state, all we can get is the held state so use that to determine press/release
	if (buttons & DOT_ActivationKey[clientIdx]) // reload pressed!
	{
		// key pressed?
		if (!DOT_ReloadDown[clientIdx])
		{
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || DOT_AllowWhileStunned[clientIdx])
				DOT_ReloadPressPending[clientIdx] = true;
			DOT_ReloadDown[clientIdx] = true;
		}
	}
	else
	{
		// key released?
		if (DOT_ReloadDown[clientIdx])
			DOT_ReloadDown[clientIdx] = false;
	}
		
	return Plugin_Continue;
}


public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
}

float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	return cfg.GetFloat(buffer, defaul);
}

void SetBossCharge(ConfigData cfg, const char[] slot, float amount) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	cfg.SetFloat(buffer, amount);
}

/**
 * READ THE LONG-WINDED COMMENTS BEFORE COPYING WHAT I DID.
 */
public void DisplayDOTOverlay(int clientIdx)
{
	// ohai
	// So you may be wondering how I got this overlay to show up, when you don't even need to be a coder
	// to realize how screwed up the HUD overlays are.
	// Simple answer: I cheated.
	// I created a client command overlay similar to what Demopan uses, but I gave it to the hale.
	// This is after careful consideration of a couple things:
	// - Hales don't get overlays, except in rare cases for cosmetic reasons. (i.e. Doomguy)
	// - I'd have to modify the FF2 source to tack on my message to an existing overlay. That's a no-no.
	// - There's a limited number of overlays available...probably six. Adding my own overlay would destroy another, or just not appear.
	// So with that in mind I'm doing it this way. Keep this in mind if you copy this code. If you use this in your DOT...
	// well...don't.
	// The problem is you can only have one of these, period.
	// So if you use this code, remember that any existing overlay that client uses will vanish when you add yours.
	// And vice versa.
	// Server operators (who code) have it easy. :P Getting to pick and choose what HUDs are worth it and fixing the overuse in the FF2 code...
	// oh yeah, this isn't localized. Sorry about that.
	bool shouldExecute = (overlayTickCount % 5 == 0) || !DOT_OverlayVisible[clientIdx];
	shouldExecute = shouldExecute && !DOT_NoOverlay[clientIdx];
	if (!shouldExecute)
		return;
	
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	if ((overlayTickCount / 5) % 2 == 0)
	{
		if(DOT_ActivationKey[clientIdx] == IN_RELOAD)
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/reload_overlay1");
		else if (DOT_ActivationKey[clientIdx] == IN_ATTACK3)
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/attack3_overlay1");
		else
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/alt_fire_overlay1");
	}
	else
	{
		if(DOT_ActivationKey[clientIdx] == IN_RELOAD)
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/reload_overlay2");
		else if (DOT_ActivationKey[clientIdx] == IN_ATTACK3)
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/attack3_overlay2");
		else
			ClientCommand(clientIdx, "r_screenoverlay freak_fortress_2/dots/alt_fire_overlay2");	
	}
	SetCommandFlags("r_screenoverlay", flags);
	
	DOT_OverlayVisible[clientIdx] = true;
}

public void RemoveDOTOverlay(int clientIdx)
{
	if (!IsClientInGame(clientIdx) || DOT_NoOverlay[clientIdx])
		return;
	
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "r_screenoverlay \"\"");
	SetCommandFlags("r_screenoverlay", flags);
	
	DOT_OverlayVisible[clientIdx] = false;
}

/**
 * Stocks
 */
stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MaxClients)
		return false;
		
	return IsValidClient(clientIdx) && IsPlayerAlive(clientIdx);
}

/**
 * CODE BELOW TAKEN FROM default_abilities, I CLAIM NO CREDIT
 */
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