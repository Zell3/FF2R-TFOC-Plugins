/*
	"rage_spell"		// Ability name can use prefix or suffixes
	{
		// Spell index
		// -1 = Random, 0 = Fireball, 1 = Bat Swarm, 2 = Healing Aura, 3 = Pumpkin Bombs, 4 = Blast Jump, 5 = Invisibility,
		// 6 = Teleport, 7 = Lightning, 8 = Minify, 9 = Meteor Shower, 10 = Monoculus, 11 = Skeleton (most of vsh map doesn't have nav mesh)

		"slot"			"0"							// Ability Slot
		"index"			"1"							// Spell Index
		"count"			"3"							// Spell Count?
		"forceuse"		"true"						// Force Use?	false=no, true=yes
		"plugin_name"	"ff2r_spellbook"	// Plugin Name
	}

	"spellbook_hud"
	{
		"text"			""							// HUD text
		"position"		"-1.0 ; 0.77"				// X ; Y
		"color"			"255 ; 255 ; 255 ; 255"		// Red ; Green ; Blue ; Alpha
		"plugin_name"	"ff2r_spellbook"			// Plugin Name		
	}

	"spell_chaos"	// Ability name can use prefix or suffixes
	{
		"amount"		""							// Spell Count
		"interval"		""							// Cooldown Between Two Spell
		"plugin_name"	"ff2r_spellbook"			// Plugin Name		
	}

*/

#pragma semicolon 1

#include <tf2_stocks>
#include <tf2items>
#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

bool isActivated;
int Spellcount[MAXPLAYERS + 1];
Handle SpellHud;
char HudStrings[MAXPLAYERS + 1][768];
int HudColor[MAXPLAYERS + 1][4];
float HudCordinate[MAXPLAYERS + 1][2];

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Spellbook",
	author = "J0BL3SS, Zell",
	description = "Spooky Spells",
	version = "2.0.0",
	url = "www.skyregiontr.com"
};

public void OnPluginStart2() {
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
		AbilityData hud = cfg.GetAbility("spellbook_hud");
		if (hud.IsMyPlugin()) {
			isActivated = true;
			SpellHud = CreateHudSynchronizer();

			hud.GetString("text", HudStrings[client], 768);

			char Pos[32][2];
			char RGBA[32][4];
			char Position[1024];
			char Color[1024];

			hud.GetString("position", Position, 1024, "-1.0 ; 0.77");
			hud.GetString("color", Color, 1024, "255 ; 255 ; 255 ; 255");

			ExplodeString(Position, " ; ", Pos, 32, 2);
			ExplodeString(Color, " ; ", RGBA, 32, 4);

			HudCordinate[client][0] = StringToFloat(Pos[0]);
			HudCordinate[client][1] = StringToFloat(Pos[1]);
			
			HudColor[client][0] = StringToInt(RGBA[0]);
			HudColor[client][1] = StringToInt(RGBA[1]);
			HudColor[client][2] = StringToInt(RGBA[2]);
			HudColor[client][3] = StringToInt(RGBA[3]);
			
			CreateTimer(0.3, ShowSpellStatus, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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

public void FF2R_OnBossRemoved(int client){
	Spellcount[client] = 0;
	isActivated = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return;
	if (!StrContains(ability, "rage_spell", false) && cfg.IsMyPlugin()) {
		isActivated = true;
		int Spellbook = FindSpellBook(client);
		if(Spellbook == -1)
			SpawnWeapon(client, "tf_weapon_spellbook", 1069, 0, 0, "138 ; 0.33 ; 15 ; 0",0);

		int SPL_SpellIndex = cfg.GetInt("index", -1);
		int SPL_SpellCount = cfg.GetInt("count", 3);
		bool SPL_ForceUse = cfg.GetBool("forceuse", false);
	
		if(SPL_SpellIndex == -1)
			SPL_SpellIndex = GetRandomInt(0, 11);

		if(GetEntProp(Spellbook, Prop_Send, "m_iSelectedSpellIndex") == SPL_SpellIndex)
		{
			int SpellCount = GetEntProp(Spellbook, Prop_Send, "m_iSpellCharges");		//Spell Count
			SetEntProp(Spellbook, Prop_Send, "m_iSpellCharges", SPL_SpellCount + SpellCount);
		}
		else
		{
			SetEntProp(Spellbook, Prop_Send, "m_iSelectedSpellIndex", SPL_SpellIndex);	//Spell Index
			SetEntProp(Spellbook, Prop_Send, "m_iSpellCharges", SPL_SpellCount);		//Spell Count
		}
		
		if(SPL_ForceUse) {
			FakeClientCommand(client, "use tf_weapon_spellbook");
			CreateTimer(0.5, UseSpell, client, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
	}

	if (!StrContains(ability, "spell_chaos", false) && cfg.IsMyPlugin()) {
		isActivated = true;
		float CAOS_Cooldown = cfg.GetFloat("interval", 1.0);
		if(CAOS_Cooldown < 0.7)
			CAOS_Cooldown = 0.7;
		SpawnWeapon(client, "tf_weapon_spellbook", 1069, 0, 0, "138 ; 0.33 ; 15 ; 0 ; 178 ; 0.00005", 0);

		DataPack pack;
		CreateDataTimer(CAOS_Cooldown, SpellChaos, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		pack.WriteCell(client);
		pack.WriteString(ability);
	}
}

public Action ShowSpellStatus(Handle timer, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !isActivated)
		return Plugin_Stop;
	
	int Spellbook = FindSpellBook(client);
	if(Spellbook != -1)
	{	
		char HUDStatus[256];
		SetHudTextParams(HudCordinate[client][0], HudCordinate[client][1], 0.4,
		HudColor[client][0], 
		HudColor[client][1], 
		HudColor[client][2], 
		HudColor[client][3]);
		int SpellCount = GetEntProp(Spellbook, Prop_Send, "m_iSpellCharges");		//Spell Count
		if(SpellCount > 0)
		{
			int SpellIndex = GetEntProp(Spellbook, Prop_Send, "m_iSelectedSpellIndex");	//Spell Index
			char SpellName[96];
			switch(SpellIndex)
			{
				case 0:		SpellName = "Fireball";
				case 1:		SpellName = "Bat Swarm";
				case 2:		SpellName = "Healing Aura";
				case 3:		SpellName = "Pumpkin Bombs";
				case 4:		SpellName = "Blast Jump";
				case 5:		SpellName = "Invisibility";
				case 6:		SpellName = "Teleport";
				case 7: 	SpellName = "Lightning";
				case 8: 	SpellName = "Minify";
				case 9: 	SpellName = "Meteor Shower";
				case 10:	SpellName = "Monoculus";
				case 11:	SpellName = "Skeleton";
			}
			Format(HUDStatus, sizeof(HUDStatus), HudStrings[client], SpellCount, SpellName);
			ShowSyncHudText(client, SpellHud, HUDStatus);
			CloseHandle(SpellHud);
		}
	}
	return Plugin_Continue;
}

public Action UseSpell(Handle timer, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || 	!isActivated)
		return Plugin_Stop;

	int Spellbook = FindSpellBook(client);
	if(GetEntProp(Spellbook, Prop_Send, "m_iSpellCharges") <= 0)
	{
		TF2_RemoveWearable(client, FindSpellBook(client));
		return Plugin_Stop;
	}
	FakeClientCommand(client, "use tf_weapon_spellbook");	//Force Spell Usage
	return Plugin_Continue;
}

public Action SpellChaos(Handle timer, DataPack pack)
{
	char ability[256];
	pack.Reset();
	int client = pack.ReadCell();
	pack.ReadString(ability, sizeof(ability));
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !isActivated)
		return Plugin_Stop;
	BossData boss = FF2R_GetBossData(client);
	if(!boss)
		return Plugin_Stop;
	AbilityData cfg = boss.GetAbility(ability);
	if(!cfg.IsMyPlugin())
		return Plugin_Stop;

	if(Spellcount[client] < cfg.GetInt("amount", 30)) {
		int Spellbook = FindSpellBook(client);
		if(Spellbook != -1)
		{
			int SpellIndex;
			switch(GetRandomInt(0,20/*25*/))
			{
				case 0, 1, 2, 3, 4:			SpellIndex = 0; //"Fireball"
				case 5, 6, 7, 8, 9:			SpellIndex = 1; //"Bat Swarm"
				case 10, 11, 12, 13, 14:	SpellIndex = 7; //"Lightning"
				case 15, 16, 17:			SpellIndex = 3; //"Pumpkin Bombs"
				case 18, 19:				SpellIndex = 9;	//"Meteor Shower"
				case 20:					SpellIndex = 10; //"Monoculus"
				//case 21,22,23,24,25: 		SpellIndex = 11; //"Skeleton" //More than half of servers don't have nav meshs				
			}
			SetEntProp(Spellbook, Prop_Send, "m_iSelectedSpellIndex", SpellIndex);	//Spell Index
			SetEntProp(Spellbook, Prop_Send, "m_iSpellCharges", 1);		//Spell Count
			FakeClientCommand(client, "use tf_weapon_spellbook");	//Force Spell Usage
			Spellcount[client]++;
			return Plugin_Continue;
		}
	} else {
		TF2_RemoveWearable(client, FindSpellBook(client));
		Spellcount[client] = 0;
	}
	return Plugin_Stop;
}

stock bool IsValidClient(int client)
{
	if(client <= 0 || client > MaxClients) return false;
	if(!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;		
}

stock int FindSpellBook(int client)
{
	int Spellbook = -1;
	while((Spellbook = FindEntityByClassname(Spellbook, "tf_weapon_spellbook")) != -1)
	{
		if(IsValidEntity(Spellbook) && GetEntPropEnt(Spellbook, Prop_Send, "m_hOwnerEntity") == client)
			if(!GetEntProp(Spellbook, Prop_Send, "m_bDisguiseWeapon"))
				return Spellbook;
	}
	return -1;
}

#if !defined _FF2_Extras_included
stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1, bool preserve = false)
{
	if(StrEqual(name,"saxxy", false)) // if "saxxy" is specified as the name, replace with appropiate name
	{ 
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: ReplaceString(name, 64, "saxxy", "tf_weapon_bat", false);
			case TFClass_Soldier: ReplaceString(name, 64, "saxxy", "tf_weapon_shovel", false);
			case TFClass_Pyro: ReplaceString(name, 64, "saxxy", "tf_weapon_fireaxe", false);
			case TFClass_DemoMan: ReplaceString(name, 64, "saxxy", "tf_weapon_bottle", false);
			case TFClass_Heavy: ReplaceString(name, 64, "saxxy", "tf_weapon_fists", false);
			case TFClass_Engineer: ReplaceString(name, 64, "saxxy", "tf_weapon_wrench", false);
			case TFClass_Medic: ReplaceString(name, 64, "saxxy", "tf_weapon_bonesaw", false);
			case TFClass_Sniper: ReplaceString(name, 64, "saxxy", "tf_weapon_club", false);
			case TFClass_Spy: ReplaceString(name, 64, "saxxy", "tf_weapon_knife", false);
		}
	}
	
	if(StrEqual(name, "tf_weapon_shotgun", false)) // If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_soldier", false);
			case TFClass_Pyro:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_pyro", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_hwg", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_primary", false);
		}
	}

	Handle weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
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
		int i2 = 0;
		for(int i = 0; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
			if (attrib == 0)
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

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[SpawnWeapon] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	
	if(!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	if (StrContains(name, "tf_wearable")==-1)
	{
		EquipPlayerWeapon(client, entity);
	}
	else
	{
		Wearable_EquipWearable(client, entity);
	}
	
	return entity;
}

Handle S93SF_equipWearable = INVALID_HANDLE;
stock void Wearable_EquipWearable(int client, int wearable)
{
	if(S93SF_equipWearable==INVALID_HANDLE)
	{
		Handle config=LoadGameConfigFile("equipwearable");
		if(config==INVALID_HANDLE)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		CloseHandle(config);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==INVALID_HANDLE)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif