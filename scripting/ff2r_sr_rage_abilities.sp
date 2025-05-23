/*
 * Some Code Spinnets from:
 * "Freak Fortress 2: Fire Boss Pack" 			Version "1.0" by "Friagram" 	~ for Noclip Acceleration and Noclip Speed
 * "Freak Fortress 2: Blightcaler's Subplugin" 	Version "1.0" by "LeAlex" 		~ for DOT Phasewalk.
 * Thanks to: JuegosPablo for helping me about dot_noclip. LeAlex14 for dot_phasewalk's code, mainly created for DoctorKrazy's boss Hoovydundy

 * Note from Zell: This is a Rage Version of the original FF2 SR DOT Abilities, but with some changes.
 * Don't have noclip and speed because you can use that ability from other plugins (rage_movespeed and hunter).


  "rage_regen"
  {
    "duration"			"10"			// Duration of Regen
    "tickrate"			"5"				// Tickrate
    "bossrate"			"0.0003" 	// Health gain per tick. For self heal. (Value between 1.0 and 0.0)
    "teamrate"			"0.0002"	// Health gain per tick. For companions. (Value between 1.0 and 0.0)
    "range"					"1024.0"	// Companion Range to Heal
    "plugin_name"	"ff2r_sr_rage_abilities"
  }

  "rage_phasewalk"
  {
    "duration"			"10"			// Duration of Phasewalk
    "tickrate"			"5"				// Image Creation Tickrate
    "lifetime"			"48"			// Image Duration Tickrate
    "particle"			"utaunt_bubbles_glow_green_parent"	//Effect Particle Name

    "plugin_name"		"ff2r_sr_rage_abilities"
  }

  "rage_render"
  {
    "duration"			"10"			// Duration of Render
    "red"						"255"			// Red
    "green"					"255"			// Green
    "blue"					"255"			// Blue
    "alpha"					"125"			// Alpha

    "plugin_name"		"ff2r_sr_rage_abilities"
  }

  "rage_damage"
  {
    "duration"			"10"			// Duration of Damage Multiplier
    "damage"				"0.1"			// Damage Multiplier
    "knockback"			"0.1"			// Knockback Multiplier

    "plugin_name"		"ff2r_sr_rage_abilities"
  }

  "rage_no_collisions"
  {
    "duration"			"10"			// Duration of No Collisions
    "range"					"50"			// Collision range
    "damage"				"9999"		// Damage to Player when dot disabled
    "plugin_name"		"ff2r_sr_rage_abilities"
  }

  "rage_block_attack"
  {
    "duration"			"10"			// Duration of Block Attack
    "plugin_name"		"ff2r_sr_rage_abilities"
  }
*/

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>
#include <sdkhooks>
#include <sdktools_functions>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: SR Rage Abilitypack",
  author      = "J0BL3SS, Zell",
  description = "FF2R Subplugin: SR DOT Abilities but rage version",
  version     = "1.0.0"
};

/*
 * Shared Variables
 */
Handle SDKGetMaxHealth;
float  OFF_THE_MAP[3] = { 1182792704.0, 1182792704.0, -964690944.0 };

/*
 * Global Variables "rage_regen"
 */
float  flRegenDuration[MAXPLAYERS + 1];
int    iRegenTickcount[MAXPLAYERS + 1];
int    iRegenTickrate[MAXPLAYERS + 1];
float  flRegenBossRate[MAXPLAYERS + 1];
float  flRegenTeamRate[MAXPLAYERS + 1];
float  flRegenRange[MAXPLAYERS + 1];

/*
 * Global Variables "rage_phasewalk"
 */
float  flPhaseWalkDuration[MAXPLAYERS + 1];
int    iPhaseWalkTickcount[MAXPLAYERS + 1];
int    iCreateTickrate[MAXPLAYERS + 1];
int    iRemoveTickrate[MAXPLAYERS + 1];
char   sEffectName[MAXPLAYERS + 1][768];
/*
 * Global Variables "rage_render"
 */
float  flRenderDuration[MAXPLAYERS + 1];
int    iColors[MAXPLAYERS + 1][4];

/*
 * Global Variables "rage_damage"
 */
float  flDamageDuration[MAXPLAYERS + 1];
float  flDamageMultp[MAXPLAYERS + 1];
float  flDamageKnockbackMultp[MAXPLAYERS + 1];

/*
 * Global Variables "rage_no_collisions"
 */
float  flNoCollisionsDuration[MAXPLAYERS + 1];
float  flTelefragRange[MAXPLAYERS + 1];
float  flTelefragDamage[MAXPLAYERS + 1];

/*
 * Global Variables "rage_block_attack"
 */
float  flBlockAttackDuration[MAXPLAYERS + 1];

public void OnPluginStart()
{
  HookEvent("arena_win_panel", Event_RoundEnd);
  HookEvent("teamplay_round_win", Event_RoundEnd);  // for non-arena maps

  GameData gamedata = new GameData("sdkhooks.games");
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "GetMaxHealth");
  PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
  SDKGetMaxHealth = EndPrepSDKCall();
  if (!SDKGetMaxHealth)
    LogError("[Gamedata] Could not find GetMaxHealth");
  delete gamedata;
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    ResetEverything();
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  ResetEverything();
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_regen", false))
  {
    flRegenDuration[clientIdx] = cfg.GetFloat("duration", 10.0) + GetGameTime();
    iRegenTickcount[clientIdx] = 0;
    iRegenTickrate[clientIdx]  = cfg.GetInt("tickrate", 5);
    flRegenBossRate[clientIdx] = cfg.GetFloat("bossrate", 0.0003);
    flRegenTeamRate[clientIdx] = cfg.GetFloat("teamrate", 0.0002);
    flRegenRange[clientIdx]    = cfg.GetFloat("range", 1024.0);

    SDKHook(clientIdx, SDKHook_PreThink, Regen);
  }
  else if (!StrContains(ability, "rage_phasewalk", false))
  {
    flPhaseWalkDuration[clientIdx] = cfg.GetFloat("duration", 10.0) + GetGameTime();
    iCreateTickrate[clientIdx]     = cfg.GetInt("tickrate", 5);
    iRemoveTickrate[clientIdx]     = cfg.GetInt("lifetime", 48);
    cfg.GetString("particle", sEffectName[clientIdx], sizeof(sEffectName));

    SDKHook(clientIdx, SDKHook_PreThink, PhaseWalk);
  }
  else if (!StrContains(ability, "rage_render", false))
  {
    flRenderDuration[clientIdx] = cfg.GetFloat("duration", 10.0) + GetGameTime();
    iColors[clientIdx][0]       = cfg.GetInt("red", 255);
    iColors[clientIdx][1]       = cfg.GetInt("green", 255);
    iColors[clientIdx][2]       = cfg.GetInt("blue", 255);
    iColors[clientIdx][3]       = cfg.GetInt("alpha", 125);

    SetEntityRenderMode(clientIdx, view_as<RenderMode>(2));
    SetEntityRenderColor(clientIdx, iColors[clientIdx][0], iColors[clientIdx][1], iColors[clientIdx][2], iColors[clientIdx][3]);

    SDKHook(clientIdx, SDKHook_PreThink, Render);
  }
  else if (!StrContains(ability, "rage_damage", false))
  {
    flDamageDuration[clientIdx]       = cfg.GetFloat("duration", 10.0) + GetGameTime();
    flDamageMultp[clientIdx]          = cfg.GetFloat("damage", 1.0);
    flDamageKnockbackMultp[clientIdx] = cfg.GetFloat("knockback", 1.0);

    SDKHook(clientIdx, SDKHook_OnTakeDamage, NoDamage);
    SDKHook(clientIdx, SDKHook_PreThink, Damage);
  }
  else if (!StrContains(ability, "rage_no_collisions", false))
  {
    flNoCollisionsDuration[clientIdx] = cfg.GetFloat("duration", 10.0) + GetGameTime();
    flTelefragRange[clientIdx]        = cfg.GetFloat("range", 50.0);
    flTelefragDamage[clientIdx]       = cfg.GetFloat("damage", 9999.0);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsPlayerAlive(i))
      {
        SetEntProp(i, Prop_Data, "m_CollisionGroup", 2);
      }
    }

    int iBuilding = -1;
    while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
    {
      static char strClassname[15];
      GetEntityClassname(iBuilding, strClassname, sizeof(strClassname));
      if (StrEqual(strClassname, "obj_dispenser") || StrEqual(strClassname, "obj_teleporter") || StrEqual(strClassname, "obj_sentrygun"))
      {
        SetEntProp(iBuilding, Prop_Data, "m_CollisionGroup", 2);
      }
    }

    SDKHook(clientIdx, SDKHook_PreThink, NoCollisions);
  }
  else if (!StrContains(ability, "rage_block_attack", false))
  {
    flBlockAttackDuration[clientIdx] = cfg.GetFloat("duration", 10.0) + GetGameTime();
    SDKHook(clientIdx, SDKHook_PreThink, BlockAttack);
  }
}

/*
 * Rage Regen
 */
public void Regen(int clientIdx)
{
  if (flRegenDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, Regen);
    iRegenTickcount[clientIdx] = 0;
    return;
  }

  iRegenTickcount[clientIdx]++;
  if (iRegenTickcount[clientIdx] % iRegenTickrate[clientIdx] == 0)
  {
    int bossMaxHealth = SDKCall_GetMaxHealth(clientIdx);
    int bossHealth    = GetClientHealth(clientIdx);
    int bossNewHealth = bossHealth + RoundToZero(flRegenBossRate[clientIdx] * bossMaxHealth);
    if (bossNewHealth > bossMaxHealth)
      bossNewHealth = bossMaxHealth;
    SetEntityHealth(clientIdx, bossNewHealth);

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == GetClientTeam(clientIdx) && i != clientIdx)
      {
        float clientPos[3];
        GetClientAbsOrigin(i, clientPos);
        if (GetVectorDistance(bossPos, clientPos) <= flRegenRange[clientIdx])
        {
          int clientMaxHealth = SDKCall_GetMaxHealth(i);
          int clientHealth    = GetClientHealth(i);
          int clientNewHealth = clientHealth + RoundToZero(flRegenTeamRate[clientIdx] * clientMaxHealth);
          if (clientNewHealth > clientMaxHealth)
            clientNewHealth = clientMaxHealth;
          SetEntityHealth(i, clientNewHealth);
        }
      }
    }
  }
}

/*
 * Rage Phasewalk
 */
public void PhaseWalk(int clientIdx)
{
  if (flPhaseWalkDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, PhaseWalk);
    iPhaseWalkTickcount[clientIdx] = 0;
    DispatchKeyValue(clientIdx, "disableshadows", "0");
    return;
  }

  iPhaseWalkTickcount[clientIdx]++;
  if (iPhaseWalkTickcount[clientIdx] % iCreateTickrate[clientIdx] == 0)
    MakeAnImage(clientIdx);
}

/*
 * Rage Render
 */
public void Render(int clientIdx)
{
  if (flRenderDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, Render);
    SetEntityRenderColor(clientIdx, 255, 255, 255, 255);
    SetEntityRenderMode(clientIdx, view_as<RenderMode>(1));
  }
}

/*
 * Rage Damage
 */
public void Damage(int clientIdx)
{
  if (flDamageDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, Damage);
    SDKUnhook(clientIdx, SDKHook_OnTakeDamage, NoDamage);
  }
}

public Action NoDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  damageForce[0] = damageForce[0] * flDamageKnockbackMultp[victim];
  damageForce[1] = damageForce[1] * flDamageKnockbackMultp[victim];
  damageForce[2] = damageForce[2] * flDamageKnockbackMultp[victim];

  damage         = damage * flDamageMultp[victim];
  return Plugin_Changed;
}

/*
 * Rage No Collisions
 */
public void NoCollisions(int clientIdx)
{
  if (flNoCollisionsDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, NoCollisions);

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i) && IsPlayerAlive(i))
      {
        SetEntProp(i, Prop_Data, "m_CollisionGroup", 5);

        if (i != clientIdx)
        {
          float clientPos[3];
          GetClientAbsOrigin(i, clientPos);
          if (GetVectorDistance(bossPos, clientPos) <= flTelefragRange[clientIdx])
            SDKHooks_TakeDamage(i, clientIdx, clientIdx, flTelefragDamage[clientIdx], DMG_VEHICLE);
        }
      }
    }

    int iBuilding = -1;
    while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
    {
      char strClassname[15];
      GetEntityClassname(iBuilding, strClassname, sizeof(strClassname));
      if (StrEqual(strClassname, "obj_dispenser") || StrEqual(strClassname, "obj_teleporter") || StrEqual(strClassname, "obj_sentrygun"))
      {
        float buildingPos[3];
        GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", buildingPos);

        SetEntProp(iBuilding, Prop_Data, "m_CollisionGroup", 5);
        if (GetVectorDistance(bossPos, buildingPos) <= flTelefragRange[clientIdx])
          SDKHooks_TakeDamage(iBuilding, clientIdx, clientIdx, flTelefragDamage[clientIdx], DMG_VEHICLE);
      }
    }
  }
}

/*
 * Rage Block Attack
 */
public void BlockAttack(int clientIdx)
{
  if (flBlockAttackDuration[clientIdx] < GetGameTime())
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, BlockAttack);
    return;
  }

  SetEntPropFloat(clientIdx, Prop_Send, "m_flNextAttack", GetGameTime() + 1.0);
}

public void ResetEverything()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      flPhaseWalkDuration[i]    = 0.0;
      iPhaseWalkTickcount[i]    = 0;
      iCreateTickrate[i]        = 0;
      iRemoveTickrate[i]        = 0;
      sEffectName[i][0]         = '\0';

      flRenderDuration[i]       = 0.0;
      iColors[i][0]             = 255;
      iColors[i][1]             = 255;
      iColors[i][2]             = 255;
      iColors[i][3]             = 255;

      flDamageDuration[i]       = 0.0;
      flDamageMultp[i]          = 1.0;
      flDamageKnockbackMultp[i] = 1.0;

      flNoCollisionsDuration[i] = 0.0;
      flTelefragRange[i]        = 50.0;
      flTelefragDamage[i]       = 9999.0;

      flBlockAttackDuration[i]  = 0.0;

      // safe unhook
      SDKUnhook(i, SDKHook_PreThink, Regen);
      SDKUnhook(i, SDKHook_PreThink, PhaseWalk);
      SDKUnhook(i, SDKHook_PreThink, Render);
      SDKUnhook(i, SDKHook_PreThink, Damage);
      SDKUnhook(i, SDKHook_OnTakeDamage, NoDamage);
      SDKUnhook(i, SDKHook_PreThink, NoCollisions);
      SDKUnhook(i, SDKHook_PreThink, BlockAttack);
    }
  }
}

// Thanks to LeAlex14 for sharing MakeAnImage() void
public void MakeAnImage(int client)
{
  float clientPos[3];
  float clientAngles[3];
  float clientVel[3];
  GetClientAbsOrigin(client, clientPos);
  GetEntPropVector(client, Prop_Send, "m_angRotation", clientAngles);
  GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientVel);
  SetEntityRenderMode(client, view_as<RenderMode>(2));

  float duration = iRemoveTickrate[client] / 10.0;

  if (sEffectName[client][0] != '\0')
  {
    int particle = CreateEntityByName("info_particle_system", -1);
    if (IsValidEntity(particle))
    {
      TeleportEntity(particle, clientPos, NULL_VECTOR, NULL_VECTOR);
      DispatchKeyValue(particle, "targetname", "tf2particle");
      DispatchKeyValue(particle, "parentname", "animationentity");
      DispatchKeyValue(particle, "effect_name", sEffectName[client]);
      DispatchSpawn(particle);
      ActivateEntity(particle);
      AcceptEntityInput(particle, "start", -1, -1, 0);

      CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), 2);
    }
  }

  int animationentity = CreateEntityByName("prop_physics_multiplayer", -1);
  if (IsValidEntity(animationentity))
  {
    char model[256];
    GetClientModel(client, model, 256);
    DispatchKeyValue(animationentity, "model", model);
    DispatchKeyValue(animationentity, "solid", "0");
    DispatchSpawn(animationentity);
    SetEntityMoveType(animationentity, MOVETYPE_FLYGRAVITY);
    AcceptEntityInput(animationentity, "TurnOn", animationentity, animationentity, 0);
    SetEntPropEnt(animationentity, view_as<PropType>(0), "m_hOwnerEntity", client, 0);
    if (GetEntProp(client, view_as<PropType>(0), "m_iTeamNum", 4, 0))
    {
      SetEntProp(animationentity, view_as<PropType>(0), "m_nSkin", GetClientTeam(client) + -2, 4, 0);
    }
    else
    {
      SetEntProp(animationentity, view_as<PropType>(0), "m_nSkin", GetEntProp(client, view_as<PropType>(0), "m_nForcedSkin", 4, 0), 4, 0);
    }
    SetEntProp(animationentity, view_as<PropType>(0), "m_nSequence", GetEntProp(client, view_as<PropType>(0), "m_nSequence", 4, 0), 4, 0);
    SetEntPropFloat(animationentity, view_as<PropType>(0), "m_flPlaybackRate", GetEntPropFloat(client, view_as<PropType>(0), "m_flPlaybackRate", 0), 0);
    DispatchKeyValue(client, "disableshadows", "1");
    TeleportEntity(animationentity, clientPos, clientAngles, clientVel);

    CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(animationentity), 2);
  }
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
  int entity = EntRefToEntIndex(entid);
  if (IsValidEdict(entity) && entity > MaxClients)
  {
    TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(entity, "Kill", -1, -1, 0);
  }
  return view_as<Action>(3);
}

int SDKCall_GetMaxHealth(int client)
{
  return SDKGetMaxHealth ? SDKCall(SDKGetMaxHealth, client) : GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

stock bool IsValidClient(int client)
{
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
  if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
  return true;
}