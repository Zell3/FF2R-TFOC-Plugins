/*
  "passive_jumpcrits"
  {
    "crits"         "1" // Enable jump crits 0 = no crits, 1 = minicrits on jump, 2 = crits on jump
    "plugin_name"   "ff2r_minecraft"
  }

  // place tnt at the player's feet
  "rage_tnt"
  {
    "lifetime"      "10.0"  // Duration of the TNT to be exploded
    "damage"        "300.0" // Damage of the TNT explosion
    "radius"        "200.0" // Radius of the TNT explosion
    "models"       "models/props_minecraft/tnt.mdl" // Model of the TNT
    "plugin_name"   "ff2r_minecraft"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#define PARTICLE_EXPLOSION "fluidSmokeExpl_ring_mvm"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
  name        = "[FF2R] Jump Crits Hits",
  author      = "Zell",
  description = "Steve!!!!",
  version     = "1.0.0",
};

// passive_jumpcrits
bool bJumpCrits[MAXPLAYERS + 1];
int  iJumpCritsType[MAXPLAYERS + 1];  // 0 = no crits, 1 = minicrits on jump, 2 = crits on jump
int  g_fLastFlags[MAXPLAYERS + 1];
int  g_fLastButtons[MAXPLAYERS + 1];

public void OnPluginStart()
{
  // Initialize all clients' jump crits
  for (int i = 0; i <= MaxClients; i++)
  {
    bJumpCrits[i]     = false;
    iJumpCritsType[i] = 0;  // No crits
    g_fLastFlags[i]   = 0;
    g_fLastButtons[i] = 0;  // Reset last flags and buttons
  }
}

public void OnPluginEnd()
{
  // Initialize all clients' jump crits
  for (int i = 0; i <= MaxClients; i++)
  {
    bJumpCrits[i]     = false;
    iJumpCritsType[i] = 0;  // No crits
    g_fLastFlags[i]   = 0;
    g_fLastButtons[i] = 0;  // Reset last flags and buttons
  }
}

public void FF2R_OnBossRemoved(int client)
{
  // Reset jump crits for the client when the boss is removed
  if (IsValidClient(client))
  {
    bJumpCrits[client]     = false;
    iJumpCritsType[client] = 0;  // No crits
    g_fLastFlags[client]   = 0;
    g_fLastButtons[client] = 0;  // Reset last flags and buttons
    TF2_RemoveCondition(client, TFCond_Buffed);
    TF2_RemoveCondition(client, TFCond_HalloweenCritCandy);
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData passive = cfg.GetAbility("passive_jumpcrits");
    if (passive.IsMyPlugin())
    {
      int crits = passive.GetInt("crits", 2);
      if (crits >= 0 && crits <= 2)
      {
        bJumpCrits[client]     = true;
        iJumpCritsType[client] = crits;  // Store the type of jump crits
      }
      else
      {
        bJumpCrits[client]     = false;
        iJumpCritsType[client] = 0;  // No crits
      }
    }
  }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_tnt", false) && cfg.IsMyPlugin())
  {
    // Handle the rage ability for TNT
    float lifetime = cfg.GetFloat("lifetime", 3.0);
    float damage   = cfg.GetFloat("damage", 300.0);
    float radius   = cfg.GetFloat("radius", 100.0);
    char  model[PLATFORM_MAX_PATH];
    cfg.GetString("models", model, sizeof(model));
    if (model[0] != '\0')
      PrecacheModel(model);

    // get client pos
    float pos[3];
    GetClientAbsOrigin(client, pos);

    // Create the TNT entity at the player's feet
    int tnt = CreateEntityByName("prop_dynamic");
    if (tnt != -1)
    {
      SetEntityModel(tnt, model);
      TeleportEntity(tnt, pos, NULL_VECTOR, NULL_VECTOR);
      DispatchSpawn(tnt);

      DataPack tntPack;
      CreateDataTimer(lifetime, Timer_RemoveTNT, tntPack, TIMER_FLAG_NO_MAPCHANGE);
      tntPack.WriteCell(tnt);
      tntPack.WriteFloat(damage);
      tntPack.WriteFloat(radius);
      tntPack.WriteCell(client);
      tntPack.WriteString(model);
    }
  }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
  // not valid client or not jump crits enabled or not alive
  if (!IsValidClient(client) || !bJumpCrits[client] || !IsPlayerAlive(client))
    return Plugin_Continue;

  int  fCurFlags       = GetEntityFlags(client);
  bool wasOnGround     = (g_fLastFlags[client] & FL_ONGROUND) != 0;
  bool isOnGround      = (fCurFlags & FL_ONGROUND) != 0;
  bool isPressingJump  = (buttons & IN_JUMP) != 0;
  bool wasPressingJump = (g_fLastButtons[client] & IN_JUMP) != 0;

  // Player just pressed jump while on ground
  if (isOnGround && isPressingJump && !wasPressingJump)
  {
    switch (iJumpCritsType[client])
    {
      case 1:  // Minicrits on jump
      {
        TF2_RemoveCondition(client, TFCond_HalloweenCritCandy);
        TF2_AddCondition(client, TFCond_Buffed, TFCondDuration_Infinite);
      }
      case 2:  // Crits on jump
      {
        TF2_RemoveCondition(client, TFCond_Buffed);
        TF2_AddCondition(client, TFCond_HalloweenCritCandy, TFCondDuration_Infinite);
      }
    }
  }
  // Player landed
  else if (!wasOnGround && isOnGround)
  {
    TF2_RemoveCondition(client, TFCond_Buffed);
    TF2_RemoveCondition(client, TFCond_HalloweenCritCandy);
  }

  g_fLastFlags[client]   = fCurFlags;
  g_fLastButtons[client] = buttons;

  return Plugin_Continue;
}

public Action Timer_RemoveTNT(Handle timer, DataPack pack)
{
  // Reset the pack position and read the stored values
  pack.Reset();
  int   tnt    = pack.ReadCell();
  float damage = pack.ReadFloat();
  float radius = pack.ReadFloat();
  int   owner  = pack.ReadCell();
  char  model[PLATFORM_MAX_PATH];
  pack.ReadString(model, sizeof(model));

  // Get TNT position for the explosion
  float pos[3];
  if (IsValidEntity(tnt))
  {
    GetEntPropVector(tnt, Prop_Send, "m_vecOrigin", pos);

    // Create explosion particle effect
    int particle = CreateEntityByName("info_particle_system");
    if (particle != -1)
    {
      TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
      DispatchKeyValue(particle, "effect_name", PARTICLE_EXPLOSION);
      DispatchSpawn(particle);
      ActivateEntity(particle);
      AcceptEntityInput(particle, "Start");
      CreateTimer(3.0, Timer_KillParticle, particle);
    }

    // Deal damage to nearby players
    float targetPos[3];
    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidClient(i) || !IsPlayerAlive(i))
        continue;

      GetClientAbsOrigin(i, targetPos);
      float distance = GetVectorDistance(pos, targetPos);

      if (distance <= radius)
      {
        float scaledDamage = damage * (1.0 - (distance / radius));
        SDKHooks_TakeDamage(i, owner, owner, scaledDamage, DMG_BLAST, -1, NULL_VECTOR, pos);
      }
    }

    // Remove the TNT entity
    AcceptEntityInput(tnt, "Kill");
  }

  return Plugin_Continue;
}

public Action Timer_KillParticle(Handle timer, any entity)
{
  if (IsValidEntity(entity))
  {
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (StrEqual(classname, "info_particle_system", false))
    {
      AcceptEntityInput(entity, "Kill");
    }
  }
  return Plugin_Continue;
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