#include <tf2_stocks>
#include <tf2items>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

float Aleph[MAXPLAYERS+1];
float Bet[MAXPLAYERS+1];
float Gimmel[MAXPLAYERS+1];
int Dalet[MAXPLAYERS+1];
bool Hei[MAXPLAYERS+1];
char Vav[MAXPLAYERS+1][768];
bool Zayin[MAXPLAYERS+1];
float Het;
bool Tet[MAXPLAYERS+1];
float Yud[MAXPLAYERS+1];
float YudAleph[MAXPLAYERS+1];
bool YudBet[MAXPLAYERS+1];

float basuvelocite[5256][3];
float basuangelu[5256][3];
float basuoriginu[5256][3];
MoveType basuspeedwagon[5256];
float basudamagi[MAXPLAYERS+1];

bool Zafkiel = false;

public Plugin myinfo = 
{
	name = "Corrupt By Bernkastel : Zafukieru - Time Emperor",
	author = "Saiaku no Seirei (J0BLESS) Rewrite by Zell",
	description = "Erohimu - Spirit Dress of God's Authority, Number 3",
	version = "0.0.0",
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
			FF2R_OnBossRemoved(client);
		}
	}
}
public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!(!setup || FF2R_GetGamemodeType() != 2))
		for(int i = 1; i <= MaxClients; i++)
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void FF2R_OnBossRemoved(int clientIdx) {
	for(int i = 1; i <= MaxClients; i++)
	{
		SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "Zafkiel", false) && cfg.IsMyPlugin()) {
		Aleph[client]				= cfg.GetFloat("Aleph", 0.0);
		Bet[client]			= cfg.GetFloat("Bet", 13.0);
		Gimmel[client]			= cfg.GetFloat("Gimmel", 9990.0);
		Dalet[client]			= cfg.GetInt("Dalet", 4);
		Hei[client]		= cfg.GetBool("Hei", true);
		cfg.GetString("Vav", Vav[client], 768, "119");
		Zayin[client]			= cfg.GetBool("Zayin", true);
		Het					= cfg.GetFloat("Het", 0.0);
		Tet[client]		= cfg.GetBool("Tet", false);
		YudAleph[client]	= cfg.GetFloat("Yud", 0.0);
		Yud[client]	= cfg.GetFloat("Yud Aleph", 40.0);
		YudBet[client]		= cfg.GetBool("Yud Bet", false);

		CreateTimer(Aleph[client], Zafukieru, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Zafukieru(Handle timer, int bossClientIdx)
{
	float ClientPos[3], BossPos[3];
	GetEntPropVector(bossClientIdx, Prop_Send, "m_vecOrigin", BossPos);
	
	if(Dalet[bossClientIdx] == 1 || Dalet[bossClientIdx] == 3 || Dalet[bossClientIdx] == 4)
	{
		for(int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if(IsValidClient(iClient))
			{
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", ClientPos);
				if(GetVectorDistance(BossPos, ClientPos) <= Gimmel[bossClientIdx])
				{
					if(Vav[bossClientIdx][0]!='\0')
					{
						if(!IsPlayerInSpecificConditions(iClient, Vav[bossClientIdx]))
						{
							if(Hei[bossClientIdx])
							{
								if(bossClientIdx != iClient)
									Zafukieru_caliento(iClient, bossClientIdx);
							}
							else
							{
								if(GetClientTeam(iClient) != GetClientTeam(bossClientIdx) && bossClientIdx != iClient)
									Zafukieru_caliento(iClient, bossClientIdx);
							}	
						}
						else
						{
							PrintToServer("[Zafkiel] ERROR: My name is Tokisaki Kurumi. ...I am a Spirit.");
						}
					}
					else
					{
						if(Hei[bossClientIdx])
						{
							if(bossClientIdx != iClient)
								Zafukieru_caliento(iClient, bossClientIdx);
						}
						else
						{
							if(GetClientTeam(iClient) != GetClientTeam(bossClientIdx) && bossClientIdx != iClient)
								Zafukieru_caliento(iClient, bossClientIdx);
						}
					}
				}
			}
		}
	}
	if(Dalet[bossClientIdx] == 2 || Dalet[bossClientIdx] == 3 || Dalet[bossClientIdx] == 4)
	{
		int iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, "tf_projectile_*")) != -1)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", basuoriginu[iEnt]);
			if(GetVectorDistance(BossPos, basuoriginu[iEnt]) <= Gimmel[bossClientIdx])
			{
				if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
					Zafukieru_projectilu(iEnt, bossClientIdx);
			}
		}
	}
	if(Dalet[bossClientIdx] == 1 || Dalet[bossClientIdx] == 4)
	{
		int iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, "obj_*")) != -1)
		{
			static float BuildingPos[3];
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", BuildingPos);
			if(GetVectorDistance(BossPos, BuildingPos) <= Gimmel[bossClientIdx])
			{
				if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
					Zafukieru_Buledingo(iEnt, bossClientIdx);
			}
		}
	}
	return Plugin_Continue;
}

public void Zafukieru_projectilu(int iEnt, int bossClientIdx)
{
	if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", basuvelocite[iEnt]);
		GetEntPropVector(iEnt, Prop_Data, "m_angRotation", basuangelu[iEnt]);
		basuspeedwagon[iEnt] = GetEntityMoveType(iEnt);
		
		SetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", NULL_VECTOR);
		SetEntityMoveType(iEnt, MOVETYPE_NONE);
		
		DataPack prj;
		CreateDataTimer(Bet[bossClientIdx], IeZafukieru_projectilu, prj);
		prj.WriteCell(iEnt);
		prj.WriteCell(bossClientIdx);
	}
}

public void Zafukieru_caliento(int iClient, int bossClientIdx)
{
	if(IsValidClient(iClient))
	{
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", basuvelocite[iClient]);
		GetEntPropVector(iClient, Prop_Data, "m_angRotation", basuangelu[iClient]);
		basuspeedwagon[iClient] = GetEntityMoveType(iClient);
			
		SetEntProp(iClient, Prop_Send, "m_bIsPlayerSimulated", 0);
		SetEntProp(iClient, Prop_Send, "m_bSimulatedEveryTick", 0);
		SetEntProp(iClient, Prop_Send, "m_bAnimatedEveryTick", 0);
		SetEntProp(iClient, Prop_Send, "m_bClientSideAnimation", 0);
		SetEntProp(iClient, Prop_Send, "m_bClientSideFrameReset", 1);
			
		TF2_AddCondition(iClient, TFCond_FreezeInput, -1.0);
		SetEntityMoveType(iClient, MOVETYPE_NONE);
		SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
		Zafkiel = true;
			
		DataPack client;
		CreateDataTimer(Bet[bossClientIdx], IeZafukieru_caliento, client);
		client.WriteCell(iClient);
		client.WriteCell(bossClientIdx);
	}
}

public void Zafukieru_Buledingo(int iEnt, int bossClientIdx)
{
	if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
	{
		SetEntProp(iEnt, Prop_Send, "m_bDisabled", 1);
		
		DataPack build;
		CreateDataTimer(Bet[bossClientIdx], IeZafukieru_Buledingo, build);
		build.WriteCell(iEnt);
	}
}

public Action IeZafukieru_projectilu(Handle timer, DataPack prj)
{
	int iEnt, bossClientIdx;
	prj.Reset();
	iEnt = prj.ReadCell();
	bossClientIdx = prj.ReadCell();
	
	if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
	{
		SetEntPropVector(iEnt, Prop_Data, "m_angRotation", basuangelu[iEnt]);
		SetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", basuvelocite[iEnt]);
		SetEntityMoveType(iEnt, basuspeedwagon[iEnt]);
		
		if(Tet[bossClientIdx])
		{
			for(int i = 0; i<3 ;i++)
			{
				basuvelocite[iEnt][i] *= -1.0;
				basuangelu[iEnt][i] *= -1.0;
			}
			SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", bossClientIdx);
			if(YudBet[bossClientIdx])
			{
				SetEntProp(iEnt, Prop_Send, "m_bCritical", 1, 1); //uuhh.. ok
			}
			if(Yud[bossClientIdx] > 0.0)
			{
				SetEntDataFloat(iEnt, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, GetRandomFloat(Yud[bossClientIdx], YudAleph[bossClientIdx]), true);
			}
			SetEntProp(iEnt, Prop_Send, "m_iTeamNum", GetClientTeam(bossClientIdx), 1);
			SetEntProp(iEnt, Prop_Send, "m_nSkin", (GetClientTeam(bossClientIdx)-2));
			TeleportEntity(iEnt, NULL_VECTOR, basuangelu[iEnt], basuvelocite[iEnt]);
		}
	}
	return Plugin_Continue;
}

public Action IeZafukieru_caliento(Handle timer, DataPack client)
{
	int iClient, bossClientIdx;
	client.Reset();
	iClient = client.ReadCell();
	bossClientIdx = client.ReadCell();
	if(IsValidClient(iClient))
	{
		SetEntPropVector(iClient, Prop_Data, "m_angRotation", basuangelu[iClient]);
		SetEntPropVector(iClient, Prop_Data, "m_vecVelocity", basuvelocite[iClient]);
		SetEntProp(iClient, Prop_Send, "m_bIsPlayerSimulated", 1);
		SetEntProp(iClient, Prop_Send, "m_bSimulatedEveryTick", 1);
		SetEntProp(iClient, Prop_Send, "m_bAnimatedEveryTick", 1);
		SetEntProp(iClient, Prop_Send, "m_bClientSideAnimation", 1);
		SetEntProp(iClient, Prop_Send, "m_bClientSideFrameReset", 0);
		TF2_RemoveCondition(iClient, TFCond_FreezeInput);
		SetEntityMoveType(iClient, basuspeedwagon[iClient]);
		
		Zafkiel = false;
		SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
		if(basudamagi[iClient] > 0)
		{
			SDKHooks_TakeDamage(iClient, bossClientIdx, bossClientIdx, basudamagi[iClient]);
			basudamagi[iClient] = 0.0;
		}
	}
	return Plugin_Continue;
}

public Action IeZafukieru_Buledingo(Handle timer, DataPack build)
{
	int iEnt;
	build.Reset();
	iEnt = build.ReadCell();
	
	if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
	{
		SetEntProp(iEnt, Prop_Send, "m_bDisabled", 0);
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (FF2R_GetBossData(attacker)) {
		if(victim != attacker && IsValidClient(attacker)) {
			if(Zafkiel && Zayin[attacker])
			{
				basudamagi[victim] += damage;
				if(Het <= basudamagi[victim] && Het > 0)
				{
					basudamagi[victim] = Het;
				}
				damage = 0.0;
				return Plugin_Changed;		
			}
		}
	}
	return Plugin_Continue;		
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
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

stock bool IsPlayerInSpecificConditions(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i++)
		{
			return TF2_IsPlayerInCondition(client, view_as<TFCond>(StringToInt(conds[i])));
		}
	}
	return false;
}