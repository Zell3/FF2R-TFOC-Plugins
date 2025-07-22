/* iirc shockwave make server crash
  "rage_gravity" // Ability name can use suffixes
  {
    "slot"            "0"

    "effectmode"      "1"		    // Effect Mode; 1:Enemy, 2:Boss, 3:Boss Team, 4:Everyone except Boss, 5:Everyone in range
    "gravity"         "1.0"		  // Gravity Value; 1.0 = Normal Gravity, 0.001 very low gravity just dont set to 0.0
    "distance"	      "1024.0"	// Effect Distance
    "duration"	      "10.0"	  // Effect Duration

    "plugin_name"	    "ff2r_gravity"
  }

  "rage_shockwave" // Ability name can use suffixes
  {
    "slot"            "0"

    "playerdamage"    "80.0"		  // Player Damage at point blank
    "buildingdamage"  "375.0"	  // Building Damage at point blank
    "distance"	      "99999.0"	// Effect Distance
    "knockback"	      "1500"		  // Knockback Force
    "minz"	          "425"		  // Minimum Z Insenity

    "plugin_name"	    "ff2r_gravity"
  }

  "rage_sigma" // Ability name can use suffixes
  {
    "slot"            "0"

    "position"	      "1"		    // Position; 0:Stand Pos, 1:Aim Pos
    "distance"	      "99999.0"	// Effect Distance
    "upwardforce"     "1200.0"	  // Upward Velocity Force
    "upwardduration"  "1.3"	  // Gravity Force will be applied after this duration
    "gravityforce"    "20.0"	  // Gravity Force
    "gravityduration" "2.2"	  // Gravity Force Duration
    "explodebuilding" "1"   	// Explode Buildings? 0:No 1:Yes
    "damage"	        "0.0"		  // Damage to player
    "particle"	      "ghost_smoke" // Particle Effect to affected player	(Ignored if particle is blank)
    "particlepoint"   "head"	  // Particle Replace Point				(Ignored if particle is blank)

    "plugin_name"	    "ff2r_gravity"
  }
*/
#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

/*
 *	Defines "rage_gravity"
 */
int              GRV_EffectMode[MAXPLAYERS + 1];  // arg1		- EffectMode
float            GRV_Value[MAXPLAYERS + 1];       // arg2		- Gravity Value
float            GRV_Distance[MAXPLAYERS + 1];    // arg3		- Rage Distance
float            GRV_Duration[MAXPLAYERS + 1];    // arg4		- Rage Duration

/*
 *	Defines "rage_shockwave"
 */
float            SHW_PlayerDamage[MAXPLAYERS + 1];    // arg1 		- Player damage at point blank
float            SHW_BuildDamage[MAXPLAYERS + 1];     // arg2		- Building damage at point blank
float            SHW_Distance[MAXPLAYERS + 1];        // arg3		- Distance
float            SHW_KnockbackForce[MAXPLAYERS + 1];  // arg4		- Knockback Force
float            SHW_MinZ[MAXPLAYERS + 1];            // arg5		- Minimum Z Insenity

/*
 *	Defines "rage_sigma"
 */
bool             SIG_Pos[MAXPLAYERS + 1];                 // arg1		- Position; 0:Stand Pos, 0:Aim Pos
float            SIG_Distance[MAXPLAYERS + 1];            // arg2		- Distance
float            SIG_VelForce[MAXPLAYERS + 1];            // arg3		- Upward Velocity Force
float            SIG_VelDuration[MAXPLAYERS + 1];         // arg4		- Gravity Force will be applied after this duration
float            SIG_GravityForce[MAXPLAYERS + 1];        // arg5		- Gravity Force
float            SIG_GravityDuration[MAXPLAYERS + 1];     // arg6		- Gravity Force Duration
bool             SIG_ExplodeBuilding[MAXPLAYERS + 1];     // arg7		- Explode Buildings? 1:Yes, 2:No
float            SIG_Damage[MAXPLAYERS + 1];              // arg8		- Damage to player
char             SIG_Particle[MAXPLAYERS + 1][512];       // arg9		- Particle Effect to affected player	(Ignored if argument is blank)
char             SIG_ParticlePoint[MAXPLAYERS + 1][128];  // arg10		- Particle Replace Point				(Ignored if arg8 is blank)
int              SIG_iParticle[MAXPLAYERS + 1];           // Internal

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Gravity",
  author      = "J0BL3SS",
  description = "Break the laws of quantum and create gravitational fields and shockwaves",
  version     = "1.4.0",
  url         = "www.skyregiontr.com",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!cfg.IsMyPlugin())
    return;

  if (!StrContains(ability, "rage_gravity", false))
  {
    GRV_EffectMode[client] = cfg.GetInt("effectmode", 1);
    GRV_Value[client]      = cfg.GetFloat("gravity", 1.0);
    GRV_Distance[client]   = cfg.GetFloat("distance", 1024.0);
    GRV_Duration[client]   = cfg.GetFloat("duration", 10.0);

    InvokeGravity(client);
  }
  else if (!StrContains(ability, "rage_shockwave", false))
  {
    SHW_PlayerDamage[client]   = cfg.GetFloat("playerdamage", 80.0);
    SHW_BuildDamage[client]    = cfg.GetFloat("buildingdamage", 375.0);
    SHW_Distance[client]       = cfg.GetFloat("distance", 1200.0);
    SHW_KnockbackForce[client] = cfg.GetFloat("knockback", 1500.0);
    SHW_MinZ[client]           = cfg.GetFloat("minz", 425.0);

    SHW_Invoke(client);
  }
  else if (!StrContains(ability, "rage_sigma", false))
  {
    SIG_Pos[client]             = cfg.GetInt("position", 1) == 1;
    SIG_Distance[client]        = cfg.GetFloat("distance", 1024.0);
    SIG_VelForce[client]        = cfg.GetFloat("upwardforce", 1200.0);
    SIG_VelDuration[client]     = cfg.GetFloat("upwardduration", 1.3);
    SIG_GravityForce[client]    = cfg.GetFloat("gravityforce", 20.0);
    SIG_GravityDuration[client] = cfg.GetFloat("gravityduration", 2.2);
    SIG_ExplodeBuilding[client] = cfg.GetInt("explodebuilding", 1) == 1;
    SIG_Damage[client]          = cfg.GetFloat("damage", 0.0);

    cfg.GetString("particle", SIG_Particle[client], sizeof(SIG_Particle[client]));
    cfg.GetString("particlepoint", SIG_ParticlePoint[client], sizeof(SIG_ParticlePoint[client]));

    SIG_Invoke(client);
  }
}

public void SIG_Invoke(int bossClientIdx)
{
  char buffer[PLATFORM_MAX_PATH];
  FF2R_EmitBossSoundToAll("sound_sigma", bossClientIdx, buffer, bossClientIdx, _, SNDLEVEL_TRAFFIC);

  float SigmaPos[3];
  if (SIG_Pos[bossClientIdx])
  {
    GetClientEyePosition(bossClientIdx, SigmaPos);
  }
  else
  {
    GetEntPropVector(bossClientIdx, Prop_Send, "m_vecOrigin", SigmaPos);
  }

  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    if (IsValidClient(iClient) && GetClientTeam(iClient) != GetClientTeam(bossClientIdx) && GetClientTeam(iClient) != view_as<int>(TFTeam_Spectator) && IsPlayerAlive(iClient))
    {
      static float ClientPos[3];
      GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", ClientPos);
      if (GetVectorDistance(ClientPos, SigmaPos) <= SIG_Distance[bossClientIdx])
      {
        static float UPVel[3];
        UPVel[2] = SIG_VelForce[bossClientIdx];

        TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, UPVel);
        if (SIG_Particle[bossClientIdx][0] != '\0')
        {
          if (SIG_ParticlePoint[bossClientIdx][0] != '\0')
            SIG_iParticle[iClient] = CreateParticle(SIG_Particle[bossClientIdx], SIG_ParticlePoint[bossClientIdx], iClient);
          else
            SIG_iParticle[iClient] = CreateParticle(SIG_Particle[bossClientIdx], "head", iClient);
        }

        DataPack pack;
        CreateDataTimer(SIG_VelDuration[bossClientIdx], SIG_FixEverything, pack);
        pack.WriteCell(iClient);
        pack.WriteCell(bossClientIdx);
        pack.WriteFloat(SigmaPos[0]);
        pack.WriteFloat(SigmaPos[1]);
        pack.WriteFloat(SigmaPos[2]);
      }
    }
  }
}

public Action SIG_FixEverything(Handle timer, DataPack pack)
{
  int   iClient, bossClientIdx;
  float SigmaPos[3];
  /* Set to the beginning and unpack it */
  pack.Reset();
  iClient       = pack.ReadCell();
  bossClientIdx = pack.ReadCell();
  SigmaPos[0]   = pack.ReadFloat();
  SigmaPos[1]   = pack.ReadFloat();
  SigmaPos[2]   = pack.ReadFloat();

  if (IsValidClient(iClient))
  {
    if (SIG_Particle[bossClientIdx][0] != '\0' && IsValidEntity(SIG_iParticle[iClient]))
    {
      AcceptEntityInput(SIG_iParticle[iClient], "Kill");
    }

    SetEntityGravity(iClient, SIG_GravityForce[bossClientIdx]);

    if (SIG_Damage[bossClientIdx] > 0.0)
    {
      SDKHooks_TakeDamage(iClient, bossClientIdx, bossClientIdx, SIG_Damage[bossClientIdx]);
    }

    CreateTimer(SIG_GravityDuration[bossClientIdx], FixGravity, iClient, TIMER_FLAG_NO_MAPCHANGE);
  }

  if (SIG_ExplodeBuilding[bossClientIdx])
  {
    int iBuilding = -1;
    while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
    {
      static float BuildingPos[3];
      GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", BuildingPos);
      if (GetVectorDistance(BuildingPos, SigmaPos) <= SIG_Distance[bossClientIdx])
      {
        static char strClassname[15];
        GetEntityClassname(iBuilding, strClassname, sizeof(strClassname));
        if (StrEqual(strClassname, "obj_dispenser") || StrEqual(strClassname, "obj_teleporter") || StrEqual(strClassname, "obj_sentrygun"))
        {
          int iOwner = GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");
          if (IsValidClient(iOwner) && GetClientTeam(iOwner) != GetClientTeam(bossClientIdx))
          {
            SDKHooks_TakeDamage(iBuilding, bossClientIdx, bossClientIdx, 5000.0, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
          }
        }
      }
    }
  }
  return Plugin_Continue;
}

public void SHW_Invoke(int bossClientIdx)
{
  char buffer[PLATFORM_MAX_PATH];
  FF2R_EmitBossSoundToAll("sound_shockwave", bossClientIdx, buffer, bossClientIdx, _, SNDLEVEL_TRAFFIC);

  static float fBossPos[3];
  GetEntPropVector(bossClientIdx, Prop_Send, "m_vecOrigin", fBossPos);

  // Player Damage
  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    if (IsValidClient(iClient))
    {
      if (IsPlayerAlive(iClient) && GetClientTeam(iClient) != GetClientTeam(bossClientIdx))
      {
        static float ClientPos[3];
        GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", ClientPos);
        float flDist = GetVectorDistance(ClientPos, fBossPos);

        if (flDist <= SHW_Distance[bossClientIdx])
        {
          // Knockback
          static float angles[3], velocity[3];
          GetVectorAnglesTwoPoints(fBossPos, ClientPos, angles);
          GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);

          ScaleVector(velocity, SHW_KnockbackForce[bossClientIdx] - (SHW_KnockbackForce[bossClientIdx] * flDist / SHW_Distance[bossClientIdx]));
          if (velocity[2] < SHW_MinZ[bossClientIdx])
            velocity[2] = SHW_MinZ[bossClientIdx];
          TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, velocity);

          // Player Damage
          float damage = SHW_PlayerDamage[bossClientIdx] - (SHW_PlayerDamage[bossClientIdx] * flDist / SHW_Distance[bossClientIdx]);
          if (damage > 0.0)
            SDKHooks_TakeDamage(iClient, bossClientIdx, bossClientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
        }
      }
    }
  }

  // Building Damage
  for (int pass = 0; pass < 3; pass++)
  {
    static char classname[32];

    switch (pass)
    {
      case 0: classname = "obj_sentrygun";
      case 1: classname = "obj_dispenser";
      case 2: classname = "obj_teleporter";
    }

    int iBuilding = -1;
    while ((iBuilding = FindEntityByClassname(iBuilding, classname)) != -1)
    {
      int iOwner = GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");
      if (IsValidClient(iOwner) && GetClientTeam(iOwner) != GetClientTeam(bossClientIdx))
      {
        static float fBuildingPos[3];
        GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", fBuildingPos);
        float flDist = GetVectorDistance(fBuildingPos, fBossPos);

        if (flDist <= SHW_Distance[bossClientIdx])
        {
          float damage = SHW_BuildDamage[bossClientIdx] - (SHW_BuildDamage[bossClientIdx] * flDist / SHW_Distance[bossClientIdx]);
          if (damage > 0.0)
            SDKHooks_TakeDamage(iBuilding, bossClientIdx, bossClientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
        }
      }
    }
  }
}

public void InvokeGravity(int bossClientIdx)
{
  char buffer[PLATFORM_MAX_PATH];
  FF2R_EmitBossSoundToAll("sound_gravity", bossClientIdx, buffer, bossClientIdx, _, SNDLEVEL_TRAFFIC);

  float BossPos[3], ClientPos[3];

  GetEntPropVector(bossClientIdx, Prop_Send, "m_vecOrigin", BossPos);
  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    if (IsValidClient(iClient))
    {
      GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", ClientPos);
      if (GetVectorDistance(BossPos, ClientPos) <= GRV_Distance[bossClientIdx])
      {
        switch (GRV_EffectMode[bossClientIdx])
        {
          case 1:
          {
            if (GetClientTeam(iClient) != GetClientTeam(bossClientIdx))  // for only enemy team
              SetEntityGravity(iClient, GRV_Value[bossClientIdx]);
          }
          case 2:
          {
            if (iClient == bossClientIdx)  // For only boss
              SetEntityGravity(iClient, GRV_Value[bossClientIdx]);
          }
          case 3:
          {
            if (GetClientTeam(iClient) == GetClientTeam(bossClientIdx))  // for only boss team
              SetEntityGravity(iClient, GRV_Value[bossClientIdx]);
          }
          case 4:
          {
            if (iClient != bossClientIdx)  // everyone expect boss
              SetEntityGravity(iClient, GRV_Value[bossClientIdx]);
          }
          case 5:
          {
            SetEntityGravity(iClient, GRV_Value[bossClientIdx]);  // everyone in range
          }
        }
        // int UserIdx = GetClientUserId(iClient);
        CreateTimer(GRV_Duration[bossClientIdx], FixGravity, iClient, TIMER_FLAG_NO_MAPCHANGE);
      }
    }
  }
}

public Action FixGravity(Handle timer, int iClient /*UserIdx*/)
{
  // int iClient = GetClientOfUserId(UserIdx);
  if (/*!iClient && */ IsValidClient(iClient))
  {
    // GetClientFromSerial and GetClientOfUserId returns 0 if serial was invalid aka that client left, only checking if it's not 0 should be enough
    SetEntityGravity(iClient, 1.0);
  }
  return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
  if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
  return true;
}

stock float GetVectorAnglesTwoPoints(const float startPos[3], const float endPos[3], float angles[3])
{
  static float tmpVec[3];
  tmpVec[0] = endPos[0] - startPos[0];
  tmpVec[1] = endPos[1] - startPos[1];
  tmpVec[2] = endPos[2] - startPos[2];
  GetVectorAngles(tmpVec, angles);
}

stock int CreateParticle(const char[] particle, const char[] attachpoint, int client)
{
  float pos[3];

  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

  int entity = CreateEntityByName("info_particle_system");
  TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
  DispatchKeyValue(entity, "effect_name", particle);

  SetVariantString("!activator");
  AcceptEntityInput(entity, "SetParent", client, entity, 0);

  SetVariantString(attachpoint);
  AcceptEntityInput(entity, "SetParentAttachment", entity, entity, 0);

  char t_Name[128];
  Format(t_Name, sizeof(t_Name), "target%i", client);

  DispatchKeyValue(entity, "targetname", t_Name);

  DispatchSpawn(entity);
  ActivateEntity(entity);
  AcceptEntityInput(entity, "start");
  return entity;
}