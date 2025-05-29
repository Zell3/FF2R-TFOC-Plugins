/*
	"customized_weighdown"	
	{
		"slot"		"0"			// Ability slot
		"gravity"	"6.0"		// Gravity force
		"downward"	"-5000"		// Velocity force applied to player
		"angle"		"60.0"		// Required angle limit to activate weighdown
		"plugin_name"		"ff2r_special_mobility"	// This subplugin name
	}
	
	"special_bhop"		
	{
		"slot"			"0"			// Ability slot
		"boost"			"25.0"		// Velocity boost per frame
		"plugin_name"	"ff2r_special_mobility"	// This subplugin name
	}
	
	"special_directional_dash"	
	{
		"slot"		"0"			// Ability slot
		"revert"	"0.1"		// Revert velocity after this duration (-1: doesn't revert)
		"forward"	"1500.0"	// Velocity force applied to player
		"upward"	"350.0"		// Velocity boost applied to player
		
		"plugin_name"		"ff2r_special_mobility"	// This subplugin name
	}
	
	"special_dash"
	{
		"slot"		"0"			// Ability slot
		"revert"	"-1"		// Revert velocity after this duration (-1: doesn't revert)
		"forward"	"1500.0"	// Velocity force applied to player
		
		"plugin_name"		"ff2r_special_mobility"	// This subplugin name
	}
	
	"special_point_teleport"
	{
		"slot"			"12"		// Ability slot
		"maxdist"		"9999.0"	// Maximum distance
		"preverse"		"false"		// Preserve momentum
		"buttonmode"	"11"		// Buttonmode
		"cooldown"		"6.0"		// Cooldown/Recharge duration in seconds
		"initial"		"8.0"		// Initial Cooldown
		"charges"		"1"			// INTERNAL: Determine amount of charge player have
		"stack"			"3"			// Maximum amount of point teleports can be stacked
		"clone"			"0.0"		// Leave a clone that decays after this duration, lower than 0.0 disables this option
		"cost"			"20"		// Rage Cost for teleportation
		
		"hud_x"			"-1.0"		// X Position in the hud
		"hud_y"			"0.75"		// Y Position in the hud
		"strings"		"Point Teleports: [%s][%d/%d]"	// Hud Text
		
		// Misc
		"do slot before low"	""		// Do an ability before teleportating, low slot
		"do slot before high"	""		// Do an ability before teleportating, high slot
		
		"do slot after low"		""		// Do an ability when teleportation succesfull, low slot
		"do slot after high"	""		// Do an ability when teleportation succesfull, high slot
		
		
		
		"plugin_name"	"ff2r_special_mobility"	// This subplugin name
	}
	
	"special_jetpack"
	{
		"slot"			"0"			// Ability slot
		"buttonmode"	"11"		// buttonmode type (11=M2, 13=Reload, 25=M3)
		"maxcharge"		"1000.0"	// Maximum charge amount
		"force"			"15.0"		// Velocity force per tick
		"cooldown"		"5.0"		// Cooldown before recharging up after last use
		"discharge"		"5.0"		// Discharge per frame
		"recharge"		"12.0"		// Recharge per frame
		"charge"		"300.0"		// Charge
		
		"hud_x"			"-1.0"		// X Position in the hud
		"hud_y"			"0.88"		// Y Position in the hud
		"strings"		"Jetpack Charge: [%s/%s]"	// Hud text
		
		"plugin_name"	"ff2r_special_mobility"	// This subplugin name
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Special Mobility"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_OWNER	""
#define PLUGIN_DESC 	"Dash, Directional Dash, Point Teleport & More"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "3"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL 		""

#define MAXTF2PLAYERS	36
#define NOPE_AVI 		"vo/engineer_no01.mp3"
#define AB_DENYUSE		"common/wpn_denyselect.wav"

float vel_base[MAXTF2PLAYERS][3];

/*
*	Bunny Hop Variables
*/
bool BH_Enabled[MAXTF2PLAYERS];

/*
*	Point Teleport Variables
*/
Handle HudTeleport;
float TP_Cooldown[MAXTF2PLAYERS];
bool TP_InUse[MAXTF2PLAYERS];
bool TP_Enabled[MAXTF2PLAYERS];
bool ResizeTraceFailed;

/*
*	Jetpack Variables
*/
Handle HudJetpack;
bool JP_Enabled[MAXTF2PLAYERS];
float JP_Cooldown[MAXTF2PLAYERS];

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
	HudTeleport = CreateHudSynchronizer();
	HudJetpack = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
	for(int clientIdx = 0; clientIdx <= MaxClients; clientIdx++)
	{
		FF2R_OnBossRemoved(clientIdx);	
	}
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	if(BH_Enabled[clientIdx])
		BH_Enabled[clientIdx] = false;
		
	TP_Cooldown[clientIdx] = GetGameTime();
	if(TP_Enabled[clientIdx])
		TP_Enabled[clientIdx] = false;
		
	if(JP_Enabled[clientIdx])
		JP_Enabled[clientIdx] = false;
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	if(!setup || FF2R_GetGamemodeType() != 2)
	{
		if(cfg.GetAbility("special_point_teleport").IsMyPlugin())
		{
			TP_Enabled[clientIdx] = true;
			TP_Cooldown[clientIdx] = GetGameTime() + cfg.GetAbility("special_point_teleport").GetFloat("initial", 8.0);
		}
		
		if(cfg.GetAbility("special_jetpack").IsMyPlugin())
		{
			JP_Enabled[clientIdx] = true;
			JP_Cooldown[clientIdx] = GetGameTime() + 3.0;
		}
		
		if(cfg.GetAbility("special_bhop").IsMyPlugin())
		{
			BH_Enabled[clientIdx] = true;
		}
	}	
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names with different plugins in boss config
		return;
		
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "customized_weighdown", false))	
	{
		WeighDown(clientIdx, cfg);	// gosh default weighdowns are so bad
	}
	if(!StrContains(ability, "special_directional_dash", false))	
	{
		Escape_Dash(clientIdx, cfg);
	}
	if(!StrContains(ability, "special_dash", false))	
	{
		Special_Dash(clientIdx, cfg);
	}
}

public void WeighDown(int clientIdx, AbilityData ability)
{
	float grv_force = ability.GetFloat("gravity", 6.0);
	float vel_force = ability.GetFloat("downward", -5000.0);
	float ang_limit = ability.GetFloat("angle", 60.0);
	if(vel_force > 0.0)
		vel_force * -1.0;
	
	float old_grv;
	if(GetEntityGravity(clientIdx) != grv_force)
	{
		old_grv = GetEntityGravity(clientIdx);
	}
	if(GetClientButtons(clientIdx) & IN_DUCK)
	{
		if(!(GetEntityFlags(clientIdx) & FL_ONGROUND))
		{
			float ang[3];
			GetClientEyeAngles(clientIdx, ang);
			if(ang[0] > ang_limit)
			{
				float vel[3];
				GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vel);
				vel[2] = vel_force;
				TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel);
				SetEntityGravity(clientIdx, grv_force);
			}
		}
		SetEntityGravity(clientIdx, old_grv);
	}
}

public void Escape_Dash(int clientIdx, AbilityData ability)
{
	float vel_revert = ability.GetFloat("revert", 0.10);
	float vel_force = ability.GetFloat("forward", 3250.0);
	float vel_boost = ability.GetFloat("upward", 275.0);
	
	float vel_temp[3] = { 0.0, 0.0, 0.0 };
	
	GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vel_base[clientIdx]);
	
	float ang[3];
	GetClientAbsAngles(clientIdx, ang);
	
	bool LeftAndRight = false;
	if(GetClientButtons(clientIdx) & IN_MOVELEFT)		
	{
		if(GetClientButtons(clientIdx) & IN_FORWARD)
			ang[1] += 45.0;
		else if (GetClientButtons(clientIdx) & IN_BACK)
			ang[1] += 135.0;
		else
			ang[1] += 90.0;
			
		LeftAndRight = true;
	}
		
	if(GetClientButtons(clientIdx) & IN_MOVERIGHT)		
	{
		if(GetClientButtons(clientIdx) & IN_FORWARD)
			ang[1] -= 45.0;
		else if (GetClientButtons(clientIdx) & IN_BACK)
			ang[1] -= 135.0;
		else
			ang[1] -= 90.0;
		
		if(!LeftAndRight)
			LeftAndRight = true;
		else
			LeftAndRight = false;
	}
		
	if(GetClientButtons(clientIdx) & IN_BACK && !LeftAndRight)		
	{
		ang[1] -= 180.0;
	}
	
	fixAngles(ang);
	
	GetAngleVectors(ang, vel_temp, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vel_temp, vel_force);
	
	vel_temp[2] += vel_boost;
	TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel_temp);
	
	if(vel_revert > 0.0)
		CreateTimer(vel_revert, Timer_ResetVel, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
}

public void Special_Dash(int clientIdx, AbilityData ability)
{
	float ang[3], forwardVector[3];
	float vel_force = ability.GetFloat("forward", 750.0);
	float vel_revert = ability.GetFloat("revert", -1.0);
	
	GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vel_base[clientIdx]);
	
	GetClientEyeAngles(clientIdx, ang);
	GetAngleVectors(ang, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, vel_force);
	
	TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, forwardVector);
	
	if(vel_revert > 0.0)
		CreateTimer(vel_revert, Timer_ResetVel, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ResetVel(Handle timer, int userid)
{
	int clientIdx = GetClientOfUserId(userid);
	if(!clientIdx || !IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx) || !FF2R_GetBossData(clientIdx))
		return Plugin_Handled;

	TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel_base[clientIdx]);
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int clientIdx, int buttons/*, int impulse, const float velocity[3], const float angles[3]*/)
{
	if(IsPlayerAlive(clientIdx) && FF2R_GetBossData(clientIdx))
	{	
		if(BH_Enabled[clientIdx])
		{	
			Tick_BHOP(clientIdx, buttons);
		}
		
		if(TP_Enabled[clientIdx])
		{
			Tick_PointTeleport(clientIdx, buttons);
		}
		
		if(JP_Enabled[clientIdx]) 
		{	
			Tick_Jetpack(clientIdx, buttons);
		}
	}
}

/*
*	Bunny Hop
*/
public Action Tick_BHOP(int clientIdx, int &buttons)
{
	if(!FF2R_GetBossData(clientIdx).GetAbility("special_bhop").GetBool("enabled", true))
		return Plugin_Continue;
	
	if(buttons & IN_JUMP && GetEntityFlags(clientIdx) & FL_ONGROUND)
	{
		float vel[3];
		GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vel);
				
		vel[2] = 267.0;
				
		float boost = FF2R_GetBossData(clientIdx).GetAbility("special_bhop").GetFloat("boost", 1.0);
				
		if(vel[1] < 0.0)
		{
			vel[1] -= buttons & IN_DUCK ? boost * 1.0 : boost;
		}
		else
		{
			vel[1] += buttons & IN_DUCK ? boost * 1.0 : boost;
		}
				
		PrintHintText(clientIdx, "Velocity: %f", vel[1]);
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel);
	}
	return Plugin_Continue;
}

/*
*	Point Teleport
*/
public Action Tick_PointTeleport(int clientIdx, int &buttons)
{
	AbilityData teleport = FF2R_GetBossData(clientIdx).GetAbility("special_point_teleport");
	
	bool hud;
	if(teleport.GetBool("enabled", true))
	{
		hud = true;
	}
	else
	{
		return Plugin_Continue;
	}
	
	float gameTime = GetGameTime();
	int charges = teleport.GetInt("charges");
	int maxcharges = teleport.GetInt("stack", 2);
	float cost = teleport.GetFloat("cost");
	
	if(!(buttons & IN_SCORE) && (hud || teleport.GetFloat("hudin") < gameTime))
	{
		teleport.SetFloat("hudin", gameTime + 0.09);
		float hud_x = teleport.GetFloat("hud_x", -1.0);
		float hud_y = teleport.GetFloat("hud_y", 0.75);
		
		char strings[256];
		teleport.GetString("strings", strings, sizeof(strings), "Point Teleports: [%s][%d/%d][Cost: %.0f Rage]");
	
		char duration[128];
		if(charges >= maxcharges)
		{
			SetHudTextParams(hud_x, hud_y, 0.1, 255, 255, 255, 255);
			Format(duration, sizeof(duration), "MAX");
			ShowSyncHudText(clientIdx, HudTeleport, strings, duration, charges, maxcharges, cost);
		}
		else
		{
			if(charges <= 0)
			{
				SetHudTextParams(hud_x, hud_y, 0.1, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
			}
			else
			{
				SetHudTextParams(hud_x, hud_y, 0.1, 255, 255, 255, 255);
			}
			Format(duration, sizeof(duration), "%.1f",  TP_Cooldown[clientIdx] - GetGameTime());
			ShowSyncHudText(clientIdx, HudTeleport, strings, duration, charges, maxcharges, cost);
		}
	}
	
	if(TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
		return Plugin_Continue;
	
	if(charges < maxcharges)
	{
		if(TP_Cooldown[clientIdx] <= GetGameTime())
		{
			teleport.SetInt("charges", (teleport.GetInt("charges") + 1));
			if(charges < maxcharges)
			{
				float cooldown = teleport.GetFloat("cooldown", 6.0);
				TP_Cooldown[clientIdx] = GetGameTime() + cooldown;
			}
		}
	}
	
	int buttonmode = teleport.GetInt("buttonmode", 13);
	if(!TP_InUse[clientIdx] && buttons & ReturnButtonMode(buttonmode))
	{	
		float rage = GetBossCharge(FF2R_GetBossData(clientIdx), "0") + FF2R_GetBossData(clientIdx).GetFloat("ragemin");
		if(!(rage >= cost))
		{
			ClientCommand(clientIdx, "playgamesound " ... AB_DENYUSE);
			return Plugin_Continue;
		}

		
		if(charges > 0)
		{
			TP_InUse[clientIdx] = true;
			float pos[3];
			
			float max_dist = teleport.GetFloat("maxdist", 9999.0);
			if(GetSafeAimLocation(clientIdx, max_dist, pos))
			{
				SetBossCharge(FF2R_GetBossData(clientIdx), "0", rage - cost);
				
				TP_Cooldown[clientIdx] = GetGameTime() + teleport.GetFloat("cooldown", 6.0);
				teleport.SetInt("charges", (teleport.GetInt("charges") - 1));
				
				char sound[128];
				if(teleport.GetString("slot", sound, sizeof(sound)))
					FF2R_EmitBossSoundToAll("sound_ability", clientIdx, sound, clientIdx, _, SNDLEVEL_TRAFFIC);
					
				int slot1 = teleport.GetInt("do slot before high", teleport.GetInt("do slot before low"));
				FF2R_DoBossSlot(clientIdx, teleport.GetInt("do slot before low", slot1), slot1);
				
				bool preverse = teleport.GetBool("preverse", false);
				if(preverse)
					TeleportEntity(clientIdx, pos, NULL_VECTOR, NULL_VECTOR);
				else
					TeleportEntity(clientIdx, pos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
				
				int slot2 = teleport.GetInt("do slot after high", teleport.GetInt("do slot after low"));
				FF2R_DoBossSlot(clientIdx, teleport.GetInt("do slot after low", slot2), slot2);
				
			}

		}	
	}
	else if(TP_InUse[clientIdx] && !(buttons & ReturnButtonMode(buttonmode)))
	{
		TP_InUse[clientIdx] = false;		
	}
	return Plugin_Continue;
}

stock bool GetSafeAimLocation(int clientIdx, float maxDistance = 9999.0, float result[3])
{
	float sizeMultiplier = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
	
	float startPos[3], endPos[3], testPos[3], eyeAng[3];
	
	GetClientEyePosition(clientIdx, startPos);
	GetClientEyeAngles(clientIdx, eyeAng);
	
	TR_TraceRayFilter(startPos, eyeAng, MASK_PLAYERSOLID, RayType_Infinite, TracePlayersAndBuildings, clientIdx);
	TR_GetEndPosition(endPos);
	
	// don't even try if the distance is less than 82
	float distance = GetVectorDistance(startPos, endPos);
	if (distance < 82.0)
	{
		EmitSoundToClient(clientIdx, NOPE_AVI);
		return false;
	}
		
	if (distance > maxDistance)
		constrainDistance(startPos, endPos, distance, maxDistance);
	else // shave just a tiny bit off the end position so our point isn't directly on top of a wall
		constrainDistance(startPos, endPos, distance, distance - 1.0);
	
	// now for the tests. I go 1 extra on the standard mins/maxs on purpose.
	bool found = false;
	for (int x = 0; x < 3; x++)
	{
		if (found)
			break;
	
		float xOffset;
		if (x == 0)
			xOffset = 0.0;
		else if (x == 1)
			xOffset = 12.5 * sizeMultiplier;
		else
			xOffset = 25.0 * sizeMultiplier;
		
		if (endPos[0] < startPos[0])
			testPos[0] = endPos[0] + xOffset;
		else if (endPos[0] > startPos[0])
			testPos[0] = endPos[0] - xOffset;
		else if (xOffset != 0.0)
			break; // super rare but not impossible, no sense wasting on unnecessary tests
	
		for (int y = 0; y < 3; y++)
		{
			if (found)
				break;

			float yOffset;
			if (y == 0)
				yOffset = 0.0;
			else if (y == 1)
				yOffset = 12.5 * sizeMultiplier;
			else
				yOffset = 25.0 * sizeMultiplier;

			if (endPos[1] < startPos[1])
				testPos[1] = endPos[1] + yOffset;
			else if (endPos[1] > startPos[1])
				testPos[1] = endPos[1] - yOffset;
			else if (yOffset != 0.0)
				break; // super rare but not impossible, no sense wasting on unnecessary tests
		
			for (int z = 0; z < 3; z++)
			{
				if (found)
					break;

				float zOffset;
				if (z == 0)
					zOffset = 0.0;
				else if (z == 1)
					zOffset = 41.5 * sizeMultiplier;
				else
					zOffset = 83.0 * sizeMultiplier;

				if (endPos[2] < startPos[2])
					testPos[2] = endPos[2] + zOffset;
				else if (endPos[2] > startPos[2])
					testPos[2] = endPos[2] - zOffset;
				else if (zOffset != 0.0)
					break; // super rare but not impossible, no sense wasting on unnecessary tests

				// before we test this position, ensure it has line of sight from the point our player looked from
				// this ensures the player can't teleport through walls
				static float tmpPos[3];
				TR_TraceRayFilter(endPos, testPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceWallsOnly, clientIdx);
				TR_GetEndPosition(tmpPos);
				if(testPos[0] != tmpPos[0] || testPos[1] != tmpPos[1] || testPos[2] != tmpPos[2])
					continue;
				
				// now we do our very expensive test. thankfully there's only 27 of these calls, worst case scenario.
				found = IsSpotSafe(clientIdx, testPos, sizeMultiplier);
			}
		}
	}
	
	if(!found)
	{
		EmitSoundToClient(clientIdx, NOPE_AVI);
		return false;
	}
	
	result[0] = testPos[0];
	result[1] = testPos[1];
	result[2] = testPos[2];
	return true;
}

/*
*	Jepack
*/
public Action Tick_Jetpack(int clientIdx, int &buttons)
{
	AbilityData jetpack = FF2R_GetBossData(clientIdx).GetAbility("special_jetpack");
			
	bool hud;
	if(jetpack.GetBool("enabled", true))
	{
		hud = true;
	}
	else
	{
		return Plugin_Continue;
	}
	
	float gameTime = GetGameTime();
	float maxcharge = jetpack.GetFloat("maxcharge", 1000.0);
	float charge = jetpack.GetFloat("charge", maxcharge > 0.0 ? maxcharge / 3.3 : 1000.0);
	float cooldown = jetpack.GetFloat("cooldown", 5.0);
	float recharge = jetpack.GetFloat("recharge", 10.0);
	
	float vel[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vel);
	
	if(!(buttons & IN_SCORE) && (hud || jetpack.GetFloat("hudin") < gameTime))
	{
		jetpack.SetFloat("hudin", gameTime + 0.09);

		float hud_x = jetpack.GetFloat("hud_x", -1.0);
		float hud_y = jetpack.GetFloat("hud_y", 0.75);
		
		char bf_charge[64], bf_maxcharge[64];
		
		Format(bf_charge, sizeof(bf_charge), "%.1f", charge);
		Format(bf_maxcharge, sizeof(bf_maxcharge), "%.1f", maxcharge);
		
		char strings[256];
		jetpack.GetString("strings", strings, sizeof(strings), "Jetpack Charge: [%s/%s]");
	
		//HUD
		if(maxcharge <= 0.0 || (charge / maxcharge) >= 0.6) {
			SetHudTextParams(hud_x, hud_y, 0.1, 255, 255, 255, 255);
		}
		else if((charge / maxcharge) >= 0.25) {
			SetHudTextParams(hud_x, hud_y, 0.1, 255, 255, 64, 255);
		}
		else {
			SetHudTextParams(hud_x, hud_y, 0.1, 255, 64, 64, 255);
		}
		
		if(maxcharge > 0.0)	{
			ShowSyncHudText(clientIdx, HudJetpack, strings, bf_charge, bf_maxcharge);
		}
		else {
			ShowSyncHudText(clientIdx, HudJetpack, strings, "∞", "∞");
		}
	}
	
	
	if(JP_Cooldown[clientIdx] <= GetGameTime())
	{
		if(charge < maxcharge)
		{
			if(charge + recharge <= maxcharge)
			{
				jetpack.SetFloat("charge", charge + recharge);
			}
			else
			{
				jetpack.SetFloat("charge", maxcharge);
			}
		}
	}
	
	if(TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
		return Plugin_Continue;
	
	int buttonmode = jetpack.GetInt("buttonmode", 13);
	if(buttons & ReturnButtonMode(buttonmode))
	{
		float discharge = jetpack.GetFloat("discharge", 5.0);
		if(discharge <= charge || maxcharge < 0.0)
		{
			if(maxcharge > 0.0)
				jetpack.SetFloat("charge", charge - discharge);
			
			if(vel[2] < 110.0)
			{
				vel[2] = 273.0;
			}
			else
			{
				float force = jetpack.GetFloat("force", 15.0);
				vel[2] = vel[2] + force;
			}
			
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel);
			JP_Cooldown[clientIdx] = GetGameTime() + cooldown;
		}
	}
	
	return Plugin_Continue;
}

/*
*	STOCKS
*/
stock float fixAngle(float angle)
{
	int sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

void fixAngles(float angles[3])
{
	for (int i = 0; i < 3; i++)
		angles[i] = fixAngle(angles[i]);
}

stock void constrainDistance(const float startPoint[3], float endPoint[3], float distance, float maxDistance)
{
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

public bool IsSpotSafe(int clientIdx, float playerPos[3], float sizeMultiplier)
{
	ResizeTraceFailed = false;
	static float mins[3];
	static float maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 82.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2], clientIdx)) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2], clientIdx)) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2], clientIdx)) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2], clientIdx)) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2], clientIdx)) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2], clientIdx)) return false;
	
	return true;
}

stock bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset, int clientIdx)
{
	static float pointA[3];
	static float pointB[3];
	for(int phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (int shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if(!Resize_OneTrace(pointA, pointB, clientIdx))
				return false;
		}
	}
		
	return true;
}

// the purpose of this method is to first trace outward, upward, and then back in.
stock bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset, int clientIdx)
{
	static float tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static float targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];
	
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin, clientIdx))
			return false;
		
	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin, clientIdx))
		return false;
		
	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;
		
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin, clientIdx))
			return false;
		
	return true;
}

stock bool Resize_OneTrace(const float startPos[3], const float endPos[3], int clientIdx)
{
	static float result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, Resize_TracePlayersAndBuildings, clientIdx);
	if(ResizeTraceFailed)
	{
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		return false;
	}
	
	return true;
}

public bool Resize_TracePlayersAndBuildings(int entity, int contentsMask, any clientIdx)
{
	if(IsValidClient(entity) && IsPlayerAlive(entity) && GetClientTeam(entity) != GetClientTeam(clientIdx))
	{
		ResizeTraceFailed = true;
	}
	else if(IsValidEntity(entity))
	{
		static char classname[48];
		GetEntityClassname(entity, classname, sizeof(classname));
		if ((strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0) 
		|| (strcmp(classname, "prop_dynamic") == 0) || (strcmp(classname, "func_physbox") == 0) || (strcmp(classname, "func_breakable") == 0) || 
		(strcmp(classname, "func_respawnroomvisualizer") == 0 && GetEntProp(entity, Prop_Send, "m_iTeamNum") != GetEntProp(clientIdx, Prop_Send, "m_iTeamNum")))
		{
			ResizeTraceFailed = true;
		}
	}
	
	return false;
}

public bool TraceWallsOnly(int entity, int contentsMask, any clientIdx)
{
	return false;
}

public bool TracePlayersAndBuildings(int entity, int contentsMask, any clientIdx)
{
	if(IsValidClient(entity) && IsPlayerAlive(entity) && GetClientTeam(entity) != GetClientTeam(clientIdx))
	{
		return true;
	}
	else if(IsValidClient(entity) && IsPlayerAlive(entity))
	{
		return false;
	}
	
	return IsValidEntity(entity);
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

float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0)
{
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	return cfg.GetFloat(buffer, defaul);
}

void SetBossCharge(ConfigData cfg, const char[] slot, float amount)
{
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	cfg.SetFloat(buffer, amount);
}

stock int ReturnButtonMode(int mode = 13)
{
	switch(mode)
	{
		case 0:return IN_ATTACK;
		case 1:return IN_JUMP;
		case 2:return IN_DUCK;
		case 3:return IN_FORWARD;
		case 4:return IN_BACK;
		case 5:return IN_USE;
		case 6:return IN_CANCEL;
		case 7:return IN_LEFT;
		case 8:return IN_RIGHT;
		case 9:return IN_MOVELEFT;
		case 10:return IN_MOVERIGHT;
		case 11:return IN_ATTACK2;
		case 12:return IN_RUN;
		case 13:return IN_RELOAD;
		case 14:return IN_ALT1;
		case 15:return IN_ALT2;
		case 16:return IN_SCORE;
		case 17:return IN_SPEED;
		case 18:return IN_WALK;
		case 19:return IN_ZOOM;
		case 20:return IN_WEAPON1;
		case 21:return IN_WEAPON2;
		case 22:return IN_BULLRUSH;
		case 23:return IN_GRENADE1;
		case 24:return IN_GRENADE2;
		case 25:return IN_ATTACK3;
		default:return IN_RELOAD;
	}
}