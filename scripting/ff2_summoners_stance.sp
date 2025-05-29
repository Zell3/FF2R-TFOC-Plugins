#pragma semicolon 1

#include <tf2_stocks>
#include <tf2items>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2: My Stock Subplugin"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"It's a template ff2 subplugin"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL "www.skyregiontr.com"

#define MAXPLAYERARRAY MAXPLAYERS+1

/*
 *	Defines "test_ability"
 */
#define STANCE "ability_stance"
int STANCE_ButtonMode[MAXPLAYERARRAY];
int STANCE_RagePerInvoke[MAXPLAYERARRAY];
float STANCE_DurationBetweenInvokes[MAXPLAYERARRAY];

float STANCE_DamageMultipler[MAXPLAYERARRAY];
float STANCE_KnockbackMultipler[MAXPLAYERARRAY];
char STANCE_Particle[MAXPLAYERARRAY][1024];

char STANCE_Intro[MAXPLAYERARRAY][1024];
char STANCE_Idle[MAXPLAYERARRAY][1024];
char STANCE_End[MAXPLAYERARRAY][1024];

float STANCE_StunDuration[MAXPLAYERARRAY];

char STANCE_DoAbility_AbilityName[MAXPLAYERARRAY][1024];
char STANCE_DoAbility_PluginName[MAXPLAYERARRAY][1024];
int STANCE_DoAbility_AbilitySlot[MAXPLAYERARRAY];


//internal
bool STANCE_IsActive[MAXPLAYERARRAY];

#define PLAYERANIMEVENT_CUSTOM_GESTURE 20
#define PLAYERANIMEVENT_CUSTOM_SEQUENCE 21
#define PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE 22



enum Operators
{
	Operator_None = 0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps
	
	HookEvent("arena_win_panel", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ClearEverything();
	
	MainBoss_PrepareAbilities();
	CreateTimer(1.0, TimerHookSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerHookSpawn(Handle timer)
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int UserIdx = GetEventInt(event, "userid");
	
	if(IsValidClient(GetClientOfUserId(UserIdx)))
	{
		CreateTimer(0.3, SummonedBoss_PrepareAbilities, UserIdx, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		FF2_LogError("ERROR: Invalid client index. %s:Event_PlayerSpawn()", this_plugin_name);
	}
}

public Action SummonedBoss_PrepareAbilities(Handle timer, int UserIdx)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
		return;

	int bossClientIdx = GetClientOfUserId(UserIdx);
	if(IsValidClient(bossClientIdx))
	{
		int bossIdx = FF2_GetBossIndex(bossClientIdx);
		if(bossIdx >= 0)
		{
			HookAbilities(bossIdx, bossClientIdx);
		}
	}
	else
	{
		FF2_LogError("ERROR: Unable to find respawned player. %s:SummonedBoss_PrepareAbilities()", this_plugin_name);
	}
}

public void MainBoss_PrepareAbilities()
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
	{
		FF2_LogError("ERROR: Abilitypack called when round is over or when gamemode is not FF2. %s:MainBoss_PrepareAbilities()", this_plugin_name);
		return;
	}
	for(int bossClientIdx = 1; bossClientIdx <= MaxClients; bossClientIdx++)
	{
		int bossIdx = FF2_GetBossIndex(bossClientIdx);
		if(bossIdx >= 0)
		{
			HookAbilities(bossIdx, bossClientIdx);
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearEverything();
}

public void ClearEverything()
{	
	for(int i =1; i<= MaxClients; i++)
	{
		STANCE_IsActive[i] = false;
	}
}

public void HookAbilities(int bossIdx, int bossClientIdx)
{
	if(bossIdx >= 0)
	{
		if(FF2_HasAbility(bossIdx, this_plugin_name, STANCE))
		{
			STANCE_RagePerInvoke[bossClientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, STANCE, 2, 0);
			STANCE_DurationBetweenInvokes[bossClientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, STANCE, 3, 5.0);

			STANCE_DamageMultipler[bossClientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, STANCE, 4, 1.0);
			STANCE_KnockbackMultipler[bossClientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, STANCE, 5, 1.0);

			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 6, STANCE_Particle[bossClientIdx], 1024);
			
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 7, STANCE_Intro[bossClientIdx], 1024);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 8, STANCE_Idle[bossClientIdx], 1024);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 9, STANCE_End[bossClientIdx], 1024);

			STANCE_StunDuration[bossClientIdx]= FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, STANCE, 10, 1.0);

			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 10, STANCE_DoAbility_AbilityName[bossClientIdx], 1024);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, STANCE, 11, STANCE_DoAbility_PluginName[bossClientIdx], 1024);
			STANCE_DoAbility_AbilitySlot[bossClientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, STANCE, 12, 0);

			PrintToServer("Found ability \"%s\" on player %N. Hooking the ability. %s:HookAbilities()", STANCE, bossClientIdx, this_plugin_name);
		}
	}
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int bossClientIdx, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
	if(IsValidClient(bossClientIdx))
	{
		int bossIdx = FF2_GetBossIndex(bossClientIdx);
		if(bossIdx >= 0)
		{
			if(FF2_HasAbility(bossIdx, this_plugin_name, STANCE))
			{
				STANCE_ButtonMode[bossClientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, STANCE, 1, 3);
				switch(STANCE_ButtonMode[bossClientIdx])
				{
					case 1: STANCE_ButtonMode[bossClientIdx] = IN_ATTACK;	// attack
					case 2: STANCE_ButtonMode[bossClientIdx] = IN_ATTACK2; // alt-fire
					case 3: STANCE_ButtonMode[bossClientIdx] = IN_ATTACK3; // special
					case 4: STANCE_ButtonMode[bossClientIdx] = IN_RELOAD;  // reload
					case 5: // use (requires server to have "tf_allow_player_use" set to 1)
					{
						STANCE_ButtonMode[bossClientIdx] = IN_USE;
						if(!GetConVarBool(FindConVar("tf_allow_player_use")))
						{
							LogMessage("[%s] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!", this_plugin_name);
							STANCE_ButtonMode[bossClientIdx] = IN_RELOAD;
						}
					}
					default: STANCE_ButtonMode[bossClientIdx] = IN_RELOAD; // primary fire
				}
	
				if(GetClientButtons(bossClientIdx) & STANCE_ButtonMode[bossClientIdx])
				{
					SetClientTauntSequence(bossClientIdx, STANCE_Intro[bossClientIdx]);
				}
			}
		}
	}
}

bool SetClientTauntSequence(int client, const char[] name)
{
	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting) && GetEntityFlags(client) & FL_ONGROUND)
	{
		STANCE_IsActive[client] = true;
		int model = CreateAnimationDummy(client, name);
		
		// get sequence from prop
		int nSequence = GetEntProp(model, Prop_Send, "m_nSequence");
		
		if (!nSequence) {
			return false;
		}
		
		SetEntProp(client, Prop_Send, "m_nForceTauntCam", 1);
		SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
		
		// you can use CTFPlayer::PlaySpecificSequence here too
		TE_SetupPlayerAnimEvent(client, PLAYERANIMEVENT_CUSTOM_SEQUENCE, nSequence);
		TE_SendToAll();
		
		// client-side is fugged
		SetClientPrediction(client, false);
		
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
		TF2_AddCondition(client, TFCond_Taunting);
		
		// taunt yaw
		float vecEyeAngles[3];
		GetClientEyeAngles(client, vecEyeAngles);
		SetEntPropFloat(client, Prop_Send, "m_flTauntYaw", vecEyeAngles[1]);
		
		return true;
	}
	return false;
}

/**
 * Create a dummy prop performing the specified animation.
 * We use it only to determine when the animation is done.
 */
int CreateAnimationDummy(int client, const char[] anim, float flAnimMaxTime = 10.0)
{
	int model = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(model))
	{
		char clientModel[PLATFORM_MAX_PATH];
		
		GetClientModel(client, clientModel, sizeof(clientModel));
		
		DispatchKeyValue(model, "model", clientModel);
		DispatchKeyValue(model, "DefaultAnim", anim);
		
		DispatchSpawn(model);
		
		SetEntPropEnt(model, Prop_Data, "m_hParent", client);
		
		SetVariantString(anim);
		AcceptEntityInput(model, "SetAnimation");
		
		
		// don't use the Break input, that leaves gibs lol
		char selfRemove[128];
		Format(selfRemove, sizeof(selfRemove), "OnUser1 !self:AddHealth:1:%.f:1",
				flAnimMaxTime); 
		SetVariantString(selfRemove);
		AcceptEntityInput(model, "AddOutput");
		
		SetVariantString("");
		AcceptEntityInput(model, "FireUser1");
		
		AcceptEntityInput(model, "DisableShadow");
		
		HookSingleEntityOutput(model, "OnAnimationDone", OnTauntAnimationDone, true);
		HookSingleEntityOutput(model, "OnHealthChanged", OnTauntAnimationDone, true);
		
		SetEntityRenderMode(model, RENDER_NONE);
	}
	return model;
}

public void OnTauntAnimationDone(const char[] output, int caller, int activbator, float delay)
{
	int client = GetEntPropEnt(caller, Prop_Data, "m_hParent");
	
	if (IsValidEntity(client)) {
		SetEntProp(client, Prop_Send, "m_nForceTauntCam", 0);
		
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
		TF2_RemoveCondition(client, TFCond_Taunting);
		TF2_RemoveCondition(client, TFCond_Slowed);
		
		AcceptEntityInput(caller, "KillHierarchy");
		
		SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
		SetClientPrediction(client, true);
		
		STANCE_IsActive[client] = false;
		
	}
}

stock void TE_SetupPlayerAnimEvent(int client, int iEvent, int nData, float flDelay = 0.0)
{
	TE_Start("PlayerAnimEvent");
	TE_WriteNum("m_iPlayerIndex", client);
	TE_WriteNum("m_iEvent", iEvent);
	TE_WriteNum("m_nData", nData);
}

/**
 * Sets client-side prediction on a client.
 */
void SetClientPrediction(int client, bool bPrediction)
{
	// https://github.com/Pelipoika/TF2_Idlebot/blob/master/idlebot.sp
	FindConVar("sv_client_predict").ReplicateToClient(client, bPrediction ? "-1" : "0");
	SetEntProp(client, Prop_Data, "m_bLagCompensation", bPrediction);
	SetEntProp(client, Prop_Data, "m_bPredictWeapons", bPrediction);
}

stock bool IsInvuln(int client)
{
	//Borrowed from Batfoxkid
	if(!IsValidClient(client))	
		return true;
	
	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	//Borrowed from Batfoxkid
	
	if(client <= 0 || client > MaxClients)
		return false;

	if(!IsClientInGame(client) || !IsClientConnected(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

public void FF2_EmitRandomSound(int bossClientIdx, const char[] keyvalue)
{
	int bossIdx = FF2_GetBossIndex(bossClientIdx);
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound(keyvalue, sound, sizeof(sound), bossIdx))
	{
		EmitSoundToAll(sound);
		EmitSoundToAll(sound);
	}
}

public int ParseFormula(int boss, const char[] key, int defaultValue, int playing)
{
	//Borrowed from Batfoxkid
	char formula[1024], bossName[64];
	FF2_GetBossName(boss, bossName, sizeof(bossName), 0, 0);
	
	strcopy(formula, sizeof(formula), key);
	int size = 1;
	int matchingBrackets;
	for(int i; i <= strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i]=='(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i]==')')
		{
			matchingBrackets++;
		}
	}

	ArrayList sumArray=CreateArray(_, size), _operator=CreateArray(_, size);
	int bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	sumArray.Set(0, 0.0);
	_operator.Set(bracket, Operator_None);

	char character[2], value[16];
	for(int i; i <= strlen(formula); i++)
	{
		character[0]=formula[i];  //Find out what the next char in the formula is
		switch(character[0])
		{
			case ' ', '\t': continue; //Ignore whitespace
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				sumArray.Set(bracket, 0.0);
				_operator.Set(bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(_operator.Get(bracket) != Operator_None)
				{
					LogError("[%s] %s's %s formula has an invalid operator at character %i", this_plugin_name, bossName, key, i+1);
					delete sumArray; delete _operator; return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[%s] %s's %s formula has an unbalanced parentheses at character %i", this_plugin_name, bossName, key, i+1);
					delete sumArray; delete _operator; return defaultValue;
				}

				Operate(sumArray, bracket, sumArray.Get(bracket+1), _operator);
			}
			case '\0': OperateString(sumArray, bracket, value, sizeof(value), _operator); //End of formula
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);  //Constant?  Just add it to the current value
			}
			case 'n', 'x': Operate(sumArray, bracket, float(playing), _operator); //n and x denote player variables
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':_operator.Set(bracket, Operator_Add);
					case '-':_operator.Set(bracket, Operator_Subtract);
					case '*':_operator.Set(bracket, Operator_Multiply);
					case '/':_operator.Set(bracket, Operator_Divide);
					case '^':_operator.Set(bracket, Operator_Exponent);	
				}
			}
		}
	}

	float result = sumArray.Get(0);
	delete sumArray;
	delete _operator;
	if(result <= 0)
	{
		LogError("[%s] %s has an invalid %s formula, using default health!", this_plugin_name, bossName, key);
		return defaultValue;
	}
	return RoundFloat(result);
}

stock void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

stock void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
{
	//Borrowed from Batfoxkid
	float sum = sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:sumArray.Set(bracket, sum + value);
		case Operator_Subtract:sumArray.Set(bracket, sum - value);
		case Operator_Multiply:sumArray.Set(bracket, sum * value);
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[%s] Detected a divide by 0!", this_plugin_name);
				bracket = 0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent: sumArray.Set(bracket, Pow(sum, value));
		default: sumArray.Set(bracket, value);  //This means we're dealing with a constant
	}
	_operator.Set(bracket, Operator_None);
}

stock int GetTotalPlayerCount()
{
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			total++;
		}
	}
	return total;
}

stock int GetDeadPlayerCount()
{
	int dead = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(!IsPlayerAlive(i))
			{
				dead++;
			}
		}
	}
	return dead;
}

stock int GetAlivePlayerCount()
{
	int alive = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(IsPlayerAlive(i))
			{
				alive++;
			}
		}
	}
	return alive;
}

stock int GetTeamPlayerCount(int team)
{
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(GetClientTeam(i) == team)
			{
				total++;	
			}
		}
	}
	return total;
}

public int GetRandomDeadPlayer()
{
	int[] iClients = new int[MaxClients + 1]; int iCount;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsPlayerAlive(i) && FF2_GetBossIndex(i) == -1 && (GetClientTeam(i) > 1))
		{
			iClients[iCount++] = i;
		}
	}
	return (iCount == 0) ? -1 : iClients[GetRandomInt(0, iCount - 1)];
}