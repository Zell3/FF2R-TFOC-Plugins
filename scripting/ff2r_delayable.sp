/*
"delayable_damage"
{
    "slot"			  "0"								// Ability Slot

    "delay"			  "3.0"							// Delay before first use

    "damage"		  "100"							// Damage to deal
    "range"       "1000"                // Range of the ability
    "knockback"   "0"                  // Knockback to apply
    "scale"       "1"                // Scale by distance? 0: No, 1: Yes
    "z"          "0"                  // apply z offset to make knockback more flexible 0: No, 1: Yes

    "plugin_name"	"ff2r_delayable"		// this subplugin name
}

"delayable_destroy_building"
{
    "slot"			  "0"								// Ability Slot

    "delay"			  "3.0"							// Delay before first use

    "range"       "1000"                // Range of the ability
    "sentry"   "1"                  // Destroy sentry? 0: No, 1: Yes
    "dispenser"   "1"                // Destroy dispenser? 0: No, 1: Yes
    "teleporter"   "1"                // Destroy teleporter? 0: No, 1: Yes
    "carried"   "1"                // Also destroy carried buildings? 0: No, 1: Yes

    "plugin_name"	"ff2r_delayable"		// this subplugin name
}

"delayable_particle_effect"
{
    "slot"			  "0"								// Ability Slot

    "delay"			  "3.0"							// Delay before first use

    "duration"	  "3.0"							// Duration of the ability
    "range"       "1000"                // Range of the ability
    "effect"     "ghost_smoke"          // Effect to play
    "target"     "3" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    "plugin_name"	"ff2r_delayable"		// this subplugin name
}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sdktools_functions>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

bool             isDelayAbleDamageActive[MAXPLAYERS + 1];           // check if the ability is active or not
bool             isDelayAbleDestroyBuildingActive[MAXPLAYERS + 1];  // check if the ability is active or not
bool             isDelayAbleParticleEffectActive[MAXPLAYERS + 1];   // check if the ability is active or not
int              entId[MAXPLAYERS + 1];                             // store the entId of the particle effect
public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: delayable subplugin",
  author      = "sarysa, Zell",
  description = "Delayable subplugin for FF2:R original by sarysa",
  version     = "1.0.0",
};

public void FF2R_OnBossRemoved(int client)
{
  isDelayAbleDamageActive[client]          = false;
  isDelayAbleDestroyBuildingActive[client] = false;
  if (isDelayAbleParticleEffectActive[client])
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidClient(i))
      {
        CreateTimer(0.1, RemoveEntityDA, EntIndexToEntRef(entId[i]), TIMER_FLAG_NO_MAPCHANGE);
      }
      entId[i] = 0;
    }
    isDelayAbleParticleEffectActive[client] = false;
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "delayable_damage", false))
  {
    float delay     = cfg.GetFloat("delay", 0.0);
    float damage    = cfg.GetFloat("damage", 0.0);
    float range     = cfg.GetFloat("range", 0.0);
    float knockback = cfg.GetFloat("knockback", 0.0);
    int   isScale   = cfg.GetInt("scale", 0);
    int   isZ       = cfg.GetInt("z", 0);     // apply z offset to make knockback more flexible 0: No, 1: Yes

    if (damage <= 0 || range <= 0)
      return;

    isDelayAbleDamageActive[client] = true;  // set the ability to active

    DataPack pack;
    CreateDataTimer(delay, DoDamage, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);     // clientIdx
    pack.WriteCell(damage);     // damage
    pack.WriteCell(range);      // range
    pack.WriteCell(knockback);  // knockback
    pack.WriteCell(isScale);    // scale
    pack.WriteCell(isZ);        // z offset
  }
  else if (!StrContains(ability, "delayable_destroy_building", false))
  {
    float delay      = cfg.GetFloat("delay", 0.0);
    float range      = cfg.GetFloat("range", 0.0);
    int   sentry     = cfg.GetInt("sentry", 0);      // destroy sentry? 0: No, 1: Yes
    int   dispenser  = cfg.GetInt("dispenser", 0);   // destroy dispenser? 0: No, 1: Yes
    int   teleporter = cfg.GetInt("teleporter", 0);  // destroy teleporter? 0: No, 1: Yes
    int   carried    = cfg.GetInt("carried", 0);     // also destroy carried buildings? 0: No, 1: Yes

    if (range <= 0)
      return;

    isDelayAbleDestroyBuildingActive[client] = true;  // set the ability to active

    DataPack pack;
    CreateDataTimer(delay, DoDestroyBuilding, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);      // clientIdx
    pack.WriteCell(range);       // range
    pack.WriteCell(sentry);      // destroy sentry?
    pack.WriteCell(dispenser);   // destroy dispenser?
    pack.WriteCell(teleporter);  // destroy teleporter?
    pack.WriteCell(carried);     // also destroy carried buildings?
  }
  else if (!StrContains(ability, "delayable_particle_effect", false))
  {
    float delay    = cfg.GetFloat("delay", 0.0);
    float duration = cfg.GetFloat("duration", 0.0);
    float range    = cfg.GetFloat("range", 0.0);
    char  effect[PLATFORM_MAX_PATH];
    cfg.GetString("effect", effect, sizeof(effect));
    int target = cfg.GetInt("target", 0);  // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

    if (duration <= 0 || range <= 0)
      return;

    isDelayAbleParticleEffectActive[client] = true;  // set the ability to active

    DataPack pack;
    CreateDataTimer(delay, DoParticleEffect, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(client);    // clientIdx
    pack.WriteCell(duration);  // duration
    pack.WriteCell(range);     // range
    pack.WriteString(effect);  // effect
    pack.WriteCell(target);    // target
  }
}

public Action DoParticleEffect(Handle timer, DataPack pack)
{
  pack.Reset();
  int   client   = pack.ReadCell();
  float duration = pack.ReadCell();
  float range    = pack.ReadCell();
  char  effect[PLATFORM_MAX_PATH];
  pack.ReadString(effect, sizeof(effect));
  int target = pack.ReadCell();  // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self

  if (!isDelayAbleParticleEffectActive[client])
    return Plugin_Stop;  // check if the ability is active or not

  float pos[3], pos2[3];
  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && IsTarget(client, i, target))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      float distance = GetVectorDistance(pos, pos2);
      if (distance <= range)
      {
        int particle = AttachParticle(i, effect, 75.0);
        if (particle != -1)
          CreateTimer(duration, RemoveEntityDA, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
      }
    }
  }
  return Plugin_Continue;
}

public Action DoDestroyBuilding(Handle timer, DataPack pack)
{
  pack.Reset();
  int   client     = pack.ReadCell();
  float range      = pack.ReadCell();
  int   sentry     = pack.ReadCell();  // destroy sentry? 0: No, 1: Yes
  int   dispenser  = pack.ReadCell();  // destroy dispenser? 0: No, 1: Yes
  int   teleporter = pack.ReadCell();  // destroy teleporter? 0: No, 1: Yes
  int   carried    = pack.ReadCell();  // also destroy carried buildings? 0: No, 1: Yes

  if (!isDelayAbleDestroyBuildingActive[client])
    return Plugin_Stop;  // check if the ability is active or not

  if (sentry)
    DestroyBuildingsOfType("obj_sentrygun", client, carried, range);
  if (dispenser)
    DestroyBuildingsOfType("obj_dispenser", client, carried, range);
  if (teleporter)
    DestroyBuildingsOfType("obj_teleporter", client, carried, range);

  return Plugin_Continue;
}

public Action DoDamage(Handle timer, DataPack pack)
{
  pack.Reset();
  int   client    = pack.ReadCell();
  float damage    = pack.ReadCell();
  float range     = pack.ReadCell();
  float knockback = pack.ReadCell();
  bool  isScale   = pack.ReadCell() == 1;
  bool  isZ       = pack.ReadCell() == 1;  // apply z offset to make knockback more flexible 0: No, 1: Yes

  if (!isDelayAbleDamageActive[client])
    return Plugin_Stop;  // check if the ability is active or not

  float pos[3], pos2[3], kbTarget[3];
  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidLivingClient(i) && IsTarget(client, i, 3))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      float distance = GetVectorDistance(pos, pos2);
      if (distance <= range)
      {
        SDKHooks_TakeDamage(i, client, client, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);

        if (knockback > 0.0)
        {
          MakeVectorFromPoints(pos, pos2, kbTarget);
          NormalizeVector(kbTarget, kbTarget);

          // replace low Z values to give some lift, and give the hale designer more flexibility with the knockback.
          if (kbTarget[2] < 0.1 && !(kbTarget[2] < 0 && isZ))
            kbTarget[2] = 0.1;

          ScaleVector(kbTarget, (!isScale ? knockback : (knockback * (((range - distance) * 2) / range))));  // can opt to factor distance

          TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, kbTarget);
        }
      }
    }
  }
  return Plugin_Continue;
}

stock void DestroyBuildingsOfType(char[] classname, int client, bool carried, float range)
{
  int building = 0;
  while ((building = FindEntityByClassname(building, classname)) != -1)
  {
    float pos[3], pos2[3];

    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
    GetEntPropVector(building, Prop_Send, "m_vecOrigin", pos2);
    if (GetVectorDistance(pos, pos) > range)
      continue;

    if (!carried)
      SDKHooks_TakeDamage(building, client, client, 5000.0, DMG_GENERIC, -1);
    else if (!(GetEntProp(building, Prop_Send, "m_bCarried") == 0 && GetEntProp(building, Prop_Send, "m_bPlacing") != 0))
    {
      if (GetEntProp(building, Prop_Send, "m_bPlacing"))
        RemoveEntity(building);
      else
        SDKHooks_TakeDamage(building, client, client, 5000.0, DMG_GENERIC, -1);
    }
  }
}

public Action RemoveEntityDA(Handle timer, int entid)
{
  int entity = EntRefToEntIndex(entid);
  if (IsValidEdict(entity) && entity > MAXPLAYERS + 1)
  {
    AcceptEntityInput(entity, "Kill");
  }
  return Plugin_Continue;
}

stock bool IsValidLivingClient(int client)  // Checks if a client is a valid living one.
{
  if (client <= 0 || client > MaxClients) return false;
  return IsValidClient(client) && IsPlayerAlive(client);
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
  if (client <= 0 || client > MaxClients)
    return false;

  if (!IsClientInGame(client) || !IsClientConnected(client))
    return false;

  if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
    return false;

  return true;
}

stock bool IsTarget(int client, int target, int type)
{
  switch (type)
  {
    case 1:  // if target is boss,
    {
      if (client == target)
        return true;
      else return false;
    }
    case 2:  // if target's team same team as boss's team
    {
      if (GetClientTeam(target) == GetClientTeam(client))
        return true;
      else return false;
    }
    case 3:  // if target's team is not same team as boss's team
    {
      if (GetClientTeam(target) != GetClientTeam(client))
        return true;
      else return false;
    }
    case 4:  // if target is not boss
    {
      if (client != target)
        return true;
      else return false;
    }
    default:  // effect everyone
    {
      return true;
    }
  }
}

stock int AttachParticle(int entity, char[] particleType, float offset = 0.0, bool attach = true)
{
  int particle = CreateEntityByName("info_particle_system");
  if (!IsValidEntity(particle))
    return -1;

  char  targetName[128];
  float position[3];
  GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
  position[2] += offset;
  TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

  Format(targetName, sizeof(targetName), "target%i", entity);
  DispatchKeyValue(entity, "targetname", targetName);

  DispatchKeyValue(particle, "targetname", "tf2particle");
  DispatchKeyValue(particle, "parentname", targetName);
  DispatchKeyValue(particle, "effect_name", particleType);
  DispatchSpawn(particle);
  SetVariantString(targetName);
  if (attach)
  {
    AcceptEntityInput(particle, "SetParent", particle, particle, 0);
    SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
  }
  ActivateEntity(particle);
  AcceptEntityInput(particle, "start");
  return particle;
}
