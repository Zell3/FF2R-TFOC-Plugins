/*
  "entangle"
  {
    "slot"	         "0"		// Ability Slot
    "amount"	       "3"		// No. of Skills     (No. of skill to be given per rage)
    "duration"	     "5.0"	// Entangle Time        (No. of seconds that will Entangle the entangled player.)
    "stack"	         "1"		// Should skills stack? 1 - yes, 0 - no
    "buttonmode"	   "1"		// ActivationKey     (1 = LeftClick. 2 = RightClick. 3 = ReloadButton. 4 = Special, 5 = Use)
    "firing"	       "0"		// Entangle prevents player from firing weapon? 1: yes, 0: no

    // entaggle color
    "red"	           "0"		// RED value (0-255)
    "green"	         "0"		// GREEN value (0-255)
    "blue"	         "0"		// BLUE value (0-255)
    "alpha"	         "0"		// ALPHA value (0-255)

    "plugin_name"    "ff2r_otokiru_wc3"
  }

  "teleport"
  {
    "slot"	         "0"		// Ability Slot
    "amount"	       "2"		// No. of Skills     (No. of skill to be given per rage)
    "distance"	     "9999.0"	// Teleport Distance    (No. of max distance that the hale can teleport to.)
    "stack"	         "1"		// Should skills stack? 1 - yes, 0 - no
    "buttonmode"	   "2"		// ActivationKey     (1 = LeftClick. 2 = RightClick. 3 = ReloadButton. 4 = Special, 5 = Use)

    "plugin_name"    "ff2r_otokiru_wc3"
  }

  "chainlightning"
  {
    "slot"	         "0"		// Ability Slot
    "amount"	       "3"		// No. of Skills     (No. of skill to be given per rage)
    "distance"	     "9999.0"	// UNKNOWN Distance    (No. of max UNKNOWN distance that either the hale can cast or the lightning can be bounce.)
    "damage"         "100"  // No. of damage that will be dealt on players. Damage is UNSTABLE, if you set 100, it could damage user around 50~150 and sometimes instant-kill. LOL!)
    "stack"	         "1"		// Should skills stack? 1 - yes, 0 - no
    "buttonmode"	   "1"		// ActivationKey     (1 = LeftClick. 2 = RightClick. 3 = ReloadButton. 4 = Special, 5 = Use)

    // chainlightning color
    // (255, 100, 255, 255) is the default color of the orginal chainlightning
    "red"	           "0"		// RED value (0-255)
    "green"	         "0"		// GREEN value (0-255)
    "blue"	         "0"		// BLUE value (0-255)
    "alpha"	         "0"		// ALPHA value (0-255)

    "plugin_name"    "ff2r_otokiru_wc3"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdktools_trace>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define MAXPLAYERSCUSTOM 66
#define entangleSound    "war3source/entanglingrootsdecay1.wav"
#define teleportSound    "war3source/blinkarrival.wav"
#define lightningSound   "war3source/lightningbolt.wav"
#define DMG_ENERGYBEAM   (1 << 10)

Handle teleHUD, lightningHUD, entangleHUD;

int    bTeleports[MAXPLAYERS + 1];
float  bTeleportDistance[MAXPLAYERS + 1];
int    bTeleportButton[MAXPLAYERS + 1];

int    bChainLightningButton[MAXPLAYERS + 1];
int    bChainLightnings[MAXPLAYERS + 1];
int    bChainLightningDamage[MAXPLAYERS + 1];
float  bChainLightningDistance[MAXPLAYERS + 1];
int    bChainLightningColor[MAXPLAYERS + 1][4];  // RGBA

int    bEntangleButton[MAXPLAYERS + 1];
int    bEntangles[MAXPLAYERS + 1];
float  bEntangleDuration[MAXPLAYERS + 1];
// Define the array globally without an initializer
int    bEntangleColor[MAXPLAYERS + 1][4];

int    bEntangleFiring[MAXPLAYERS + 1];  // 0: No, 1: Yes

int    BeamSprite, HaloSprite, BloodSpray, BloodDrop;

int    ignoreClient;
float  emptypos[3];
float  oldpos[MAXPLAYERSCUSTOM][3];
float  teleportpos[MAXPLAYERSCUSTOM][3];
bool   inteleportcheck[MAXPLAYERSCUSTOM];
bool   bBeenHit[MAXPLAYERSCUSTOM][MAXPLAYERSCUSTOM];

public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Otokiru WC3",
  author  = "Otokiru, 93SHADoW, Zell",
  version = "1.4",
};

public void OnPluginStart()
{
  AddFileToDownloadsTable("sound/war3source/entanglingrootsdecay1.wav");
  AddFileToDownloadsTable("sound/war3source/blinkarrival.wav");
  AddFileToDownloadsTable("sound/war3source/lightningbolt.wav");
  BeamSprite = PrecacheModel("materials/sprites/lgtning.vmt");
  HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
  BloodDrop  = PrecacheModel("sprites/blood.vmt");
  BloodSpray = PrecacheModel("sprites/bloodspray.vmt");
  PrecacheSound(entangleSound, true);
  PrecacheSound(teleportSound, true);
  PrecacheSound(lightningSound, true);

  teleHUD      = CreateHudSynchronizer();
  lightningHUD = CreateHudSynchronizer();
  entangleHUD  = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    // Clear everything from players, because FF2:R either disabled/unloaded or this subplugin unloaded
    FF2R_OnBossRemoved(clientIdx);
  }
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidLivingClient(i))
        continue;

      // Make these multi-boss friendly
      bChainLightningDamage[i] = 0;
      bEntangles[i] = bChainLightnings[i] = bTeleports[i] = 0;
      bEntangleDuration[i] = bChainLightningDistance[i] = bTeleportDistance[i] = 0.0;
      bEntangleButton[i] = bChainLightningButton[i] = bTeleportButton[i] = 0;

      CreateTimer(1.0, ShowAbilityStatus, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
      CreateTimer(0.1, AbilityButton, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  // Make these multi-boss friendly
  bChainLightningDamage[clientIdx] = 0;
  bEntangles[clientIdx] = bChainLightnings[clientIdx] = bTeleports[clientIdx] = 0;
  bEntangleDuration[clientIdx] = bChainLightningDistance[clientIdx] = bTeleportDistance[clientIdx] = 0.0;
  bEntangleButton[clientIdx] = bChainLightningButton[clientIdx] = bTeleportButton[clientIdx] = 0;
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "entangle", false))  // We want to use subffixes
  {
    bEntangleButton[clientIdx] = cfg.GetInt("buttonmode", 1);
    switch (bEntangleButton[clientIdx])
    {
      case 2: bEntangleButton[clientIdx] = IN_ATTACK2;  // alt-fire
      case 3: bEntangleButton[clientIdx] = IN_RELOAD;   // reload
      case 4: bEntangleButton[clientIdx] = IN_ATTACK3;  // special
      case 5:                                           // use (requires server to have "tf_allow_player_use" set to 1)
      {
        bEntangleButton[clientIdx] = IN_USE;
        if (!GetConVarBool(FindConVar("tf_allow_player_use")))
        {
          LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
          bEntangleButton[clientIdx] = IN_ATTACK3;
        }
      }
      default: bEntangleButton[clientIdx] = IN_ATTACK;  // primary fire
    }

    int bEntangleCt              = cfg.GetInt("amount", 3);        // No of times skill can be used per rage
    bEntangleDuration[clientIdx] = cfg.GetFloat("duration", 5.0);  // Entangle Time
    if (!cfg.GetInt("stack"))                                      // Stack skills or reset to fixed amount?
    {
      bEntangles[clientIdx] = bEntangleCt;  // ALWAYS RESET
    }
    else
    {
      bEntangles[clientIdx] += bEntangleCt;  // ALLOW STACKING
    }
    bEntangleColor[clientIdx][0] = cfg.GetInt("red", 0);    // RED value (0-255)
    bEntangleColor[clientIdx][1] = cfg.GetInt("green", 0);  // GREEN value (0-255)
    bEntangleColor[clientIdx][2] = cfg.GetInt("blue", 0);   // BLUE value (0-255)
    bEntangleColor[clientIdx][3] = cfg.GetInt("alpha", 0);  // ALPHA value (0-255)
  }
  else if (!StrContains(ability, "teleport", false)) {
    bTeleportButton[clientIdx] = cfg.GetInt("buttonmode", 1);  // Activation Key
    switch (bTeleportButton[clientIdx])
    {
      case 2: bTeleportButton[clientIdx] = IN_ATTACK2;  // alt-fire
      case 3: bTeleportButton[clientIdx] = IN_RELOAD;   // reload
      case 4: bTeleportButton[clientIdx] = IN_ATTACK3;  // special
      case 5:                                           // use (requires server to have "tf_allow_player_use" set to 1)
      {
        bTeleportButton[clientIdx] = IN_USE;
        if (!GetConVarBool(FindConVar("tf_allow_player_use")))
        {
          LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
          bTeleportButton[clientIdx] = IN_ATTACK3;
        }
      }
      default: bTeleportButton[clientIdx] = IN_ATTACK;  // primary fire
    }
    int bTeleportCt              = cfg.GetInt("amount", 2);           // No of times skill can be used per rage
    bTeleportDistance[clientIdx] = cfg.GetFloat("distance", 9999.0);  // Teleport Distance
    if (!cfg.GetInt("stack"))                                         // Stack skills or reset to fixed amount?
    {
      bTeleports[clientIdx] = bTeleportCt;  // ALWAYS RESET
    }
    else
    {
      bTeleports[clientIdx] += bTeleportCt;  // ALLOW STACKING
    }
  }
  else if (!StrContains(ability, "chainlightning", false)) {
    bChainLightningButton[clientIdx] = cfg.GetInt("buttonmode", 1);  // Activation Key
    switch (bChainLightningButton[clientIdx])
    {
      case 2: bChainLightningButton[clientIdx] = IN_ATTACK2;  // alt-fire
      case 3: bChainLightningButton[clientIdx] = IN_RELOAD;   // reload
      case 4: bChainLightningButton[clientIdx] = IN_ATTACK3;  // special
      case 5:                                                 // use (requires server to have "tf_allow_player_use" set to 1)
      {
        bChainLightningButton[clientIdx] = IN_USE;
        if (!GetConVarBool(FindConVar("tf_allow_player_use")))
        {
          LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
          bChainLightningButton[clientIdx] = IN_ATTACK3;
        }
      }
      default: bChainLightningButton[clientIdx] = IN_ATTACK;  // primary fire
    }
    int bChainLightningCt              = cfg.GetInt("amount", 2);           // No of times skill can be used per rage
    bChainLightningDistance[clientIdx] = cfg.GetFloat("distance", 9999.0);  // Chain Lightning Distance
    bChainLightningDamage[clientIdx]   = cfg.GetInt("damage", 100);         // Damage
    if (!cfg.GetInt("stack"))                                               // Stack skills or reset to fixed amount?
    {
      bChainLightnings[clientIdx] = bChainLightningCt;  // ALWAYS RESET
    }
    else
    {
      bChainLightnings[clientIdx] += bChainLightningCt;  // ALLOW STACKING
    }
    bChainLightningColor[clientIdx][0] = cfg.GetInt("red", 255);    // RED value (0-255)
    bChainLightningColor[clientIdx][1] = cfg.GetInt("green", 100);  // GREEN value (0-255)
    bChainLightningColor[clientIdx][2] = cfg.GetInt("blue", 255);   // BLUE value (0-255)
    bChainLightningColor[clientIdx][3] = cfg.GetInt("alpha", 255);  // ALPHA value (0-255)
  }
}

public Action ShowAbilityStatus(Handle timer, int client)
{
  if (!IsValidLivingClient(client))
    return Plugin_Stop;

  char HUDStatus[128];
  if (bTeleports[client])
  {
    SetHudTextParams(-1.0, 0.21, 1.1, 255, 255, 255, 255);
    Format(HUDStatus, sizeof(HUDStatus), "Teleports Left: %i", bTeleports[client]);
    ShowSyncHudText(client, teleHUD, HUDStatus);
  }

  if (bChainLightnings[client])
  {
    SetHudTextParams(-1.0, (!bTeleports[client] ? 0.21 : 0.24), 1.1, 255, 255, 255, 255);
    Format(HUDStatus, sizeof(HUDStatus), "Chain Lightnings Left: %i", bChainLightnings[client]);
    ShowSyncHudText(client, lightningHUD, HUDStatus);
  }

  if (bEntangles[client])
  {
    SetHudTextParams(-1.0, (!bTeleports[client] && !bChainLightnings[client] ? 0.21 : (!bTeleports[client] && bChainLightnings[client] || bTeleports[client] && !bChainLightnings[client]) ? 0.24
                                                                                                                                                                                           : 0.27),
                     1.1, 255, 255, 255, 255);
    Format(HUDStatus, sizeof(HUDStatus), "Entangles Left: %i", bEntangles[client]);
    ShowSyncHudText(client, entangleHUD, HUDStatus);
  }

  return Plugin_Continue;
}

public Action AbilityButton(Handle timer, int client)
{
  if (!IsValidLivingClient(client))
    return Plugin_Stop;

  if (bEntangles[client] > 0)
  {
    if (GetClientButtons(client) & bEntangleButton[client])
    {
      float distance = 0.0;
      int   target;
      float our_pos[3];
      GetClientAbsOrigin(client, our_pos);
      target = War3_GetTargetInViewCone(client, distance);
      if (IsValidLivingClient(target))
      {
        bEntangles[client] = (bEntangles[client] > 0 ? bEntangles[client] - 1 : 0);
        float fVelocity[3] = { 0.0, 0.0, 0.0 };
        TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, fVelocity);
        SetEntityMoveType(target, MOVETYPE_NONE);

        if (bEntangleFiring[client])  // If the entangle prevents firing
        {
          int weapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
          if (weapon && IsValidEdict(weapon))
          {
            SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + bEntangleDuration[client]);
          }
          SetEntPropFloat(target, Prop_Send, "m_flNextAttack", GetGameTime() + bEntangleDuration[client]);
          SetEntPropFloat(target, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + bEntangleDuration[client]);
        }

        CreateTimer(bEntangleDuration[client], StopEntangle, target);
        float effect_vec[3];
        GetClientAbsOrigin(target, effect_vec);
        effect_vec[2] += 15.0;
        TE_SetupBeamRingPoint(effect_vec, 45.0, 44.0, BeamSprite, HaloSprite, 0, 15, bEntangleDuration[client], 5.0, 0.0, bEntangleColor[client], 10, 0);
        TE_SendToAll();
        effect_vec[2] += 15.0;
        TE_SetupBeamRingPoint(effect_vec, 45.0, 44.0, BeamSprite, HaloSprite, 0, 15, bEntangleDuration[client], 5.0, 0.0, bEntangleColor[client], 10, 0);
        TE_SendToAll();
        effect_vec[2] += 15.0;
        TE_SetupBeamRingPoint(effect_vec, 45.0, 44.0, BeamSprite, HaloSprite, 0, 15, bEntangleDuration[client], 5.0, 0.0, bEntangleColor[client], 10, 0);
        TE_SendToAll();
        our_pos[2] += 25.0;
        TE_SetupBeamPoints(our_pos, effect_vec, BeamSprite, HaloSprite, 0, 50, 4.0, 6.0, 25.0, 0, 12.0, bEntangleColor[client], 40);
        TE_SendToAll();
        PrintHintText(target, "You got Entangled!");

        EmitSoundToAll(entangleSound, _, _, _, _, 0.8);
        EmitSoundToAll(entangleSound, _, _, _, _, 0.8);
        
      }
      else
      {
        PrintHintText(client, "No target found!");
      }
    }
  }
  if (bTeleports[client] > 0)
  {
    if (GetClientButtons(client) & bTeleportButton[client])
    {
      War3_Teleport(client, bTeleportDistance[client]);
    }
  }
  if (bChainLightnings[client] > 0)
  {
    if (GetClientButtons(client) & bChainLightningButton[client])
    {
      for (int x = 1; x <= MaxClients; x++)
        bBeenHit[client][x] = false;
      DoChain(client, client, bChainLightningDistance[client], bChainLightningDamage[client], 0);
    }
  }

  return Plugin_Continue;  // We don't need to do anything here, just a placeholder for the timer
}

public void DoChain(int boss, int client, float distance, int dmg, int last_target)
{
  int   target      = 0;
  float target_dist = distance + 1.0;  // just an easy way to do this
  int   caster_team = GetClientTeam(client);
  float start_pos[3];
  if (last_target <= 0)
    GetClientAbsOrigin(client, start_pos);
  else
    GetClientAbsOrigin(last_target, start_pos);
  for (int x = 1; x <= MaxClients; x++)
  {
    if (IsValidLivingClient(x) && !bBeenHit[client][x] && caster_team != GetClientTeam(x))
    {
      float this_pos[3];
      GetClientAbsOrigin(x, this_pos);
      float dist_check = GetVectorDistance(start_pos, this_pos);
      if (dist_check <= target_dist)
      {
        // found a candidate, whom is currently the closest
        target      = x;
        target_dist = dist_check;
      }
    }
  }
  if (target <= 0)
  {
    PrintHintText(client, "No target found!");
  }
  else
  {
    // found someone
    bBeenHit[client][target] = true;  // don't let them get hit twice
    War3_DealDamage(target, dmg, client, DMG_ENERGYBEAM, "ChainLightning");
    PrintHintText(target, "You got hit by Chain Lightning!");
    start_pos[2] += 30.0;  // offset for effect
    float target_pos[3], vecAngles[3];
    GetClientAbsOrigin(target, target_pos);
    target_pos[2] += 30.0;
    TE_SetupBeamPoints(start_pos, target_pos, BeamSprite, HaloSprite, 0, 35, 1.0, 25.0, 25.0, 0, 10.0, bChainLightningColor[boss], 40);
    TE_SendToAll();
    GetClientEyeAngles(target, vecAngles);
    TE_SetupBloodSprite(target_pos, vecAngles, { 200, 20, 20, 255 }, 28, BloodSpray, BloodDrop);
    TE_SendToAll();
    EmitSoundToAll(lightningSound, target, _, SNDLEVEL_TRAIN, _, 0.8);
    int new_dmg = RoundFloat(float(dmg) * 0.66);

    DoChain(boss, client, distance, new_dmg, target);
    bChainLightnings[client] = (bChainLightnings[client] > 0 ? bChainLightnings[client] - 1 : 0);
  }
}

public void War3_DealDamage(int victim, int damage, int attacker, int dmg_type, char[] weapon)
{
  if (victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage > 0)
  {
    char dmg_str[16];
    IntToString(damage, dmg_str, 16);
    char dmg_type_str[32];
    IntToString(dmg_type, dmg_type_str, 32);
    int pointHurt = CreateEntityByName("point_hurt");
    if (pointHurt)
    {
      DispatchKeyValue(victim, "targetname", "war3_hurtme");
      DispatchKeyValue(pointHurt, "DamageTarget", "war3_hurtme");
      DispatchKeyValue(pointHurt, "Damage", dmg_str);
      DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
      if (!StrEqual(weapon, ""))
      {
        DispatchKeyValue(pointHurt, "classname", weapon);
      }
      DispatchSpawn(pointHurt);
      AcceptEntityInput(pointHurt, "Hurt", (attacker > 0) ? attacker : -1);
      DispatchKeyValue(pointHurt, "classname", "point_hurt");
      DispatchKeyValue(victim, "targetname", "war3_donthurtme");
      RemoveEdict(pointHurt);
    }
  }
}

void ShowParticle(float possie[3], char[] particlename, float time)
{
  int particle = CreateEntityByName("info_particle_system");
  if (IsValidEdict(particle))
  {
    TeleportEntity(particle, possie, NULL_VECTOR, NULL_VECTOR);
    DispatchKeyValue(particle, "effect_name", particlename);
    ActivateEntity(particle);
    AcceptEntityInput(particle, "start");
    CreateTimer(time, DeleteParticles, particle);
  }
}

public Action DeleteParticles(Handle timer, any particle)
{
  if (IsValidEntity(particle))
  {
    char classname[32];
    GetEdictClassname(particle, classname, sizeof(classname));
    if (StrEqual(classname, "info_particle_system", false))
    {
      RemoveEdict(particle);
    }
  }
  return Plugin_Continue;
}

void TeleportEffects(float pos[3])
{
  ShowParticle(pos, "pyro_blast", 1.0);
  ShowParticle(pos, "pyro_blast_lines", 1.0);
  ShowParticle(pos, "pyro_blast_warp", 1.0);
  ShowParticle(pos, "pyro_blast_flash", 1.0);
  ShowParticle(pos, "burninggibs", 0.5);
}

public Action checkTeleport(Handle h, any client)
{
  inteleportcheck[client] = false;
  float pos[3];

  GetClientAbsOrigin(client, pos);

  if (GetVectorDistance(teleportpos[client], pos) < 0.001)  // he didnt move in this 0.1 second
  {
    TeleportEntity(client, oldpos[client], NULL_VECTOR, NULL_VECTOR);
    PrintHintText(client, "Cannot teleport there!");
  }
  else {
    bTeleports[client] = (bTeleports[client] > 0 ? bTeleports[client] - 1 : 0);
  }

  return Plugin_Continue;
}

int absincarray[] = { 0, 4, -4, 8, -8, 12, -12, 18, -18, 22, -22, 25, -25 };  //,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller
public bool getEmptyLocationHull(int client, float originalpos[3])
{
  float mins[3];
  float maxs[3];
  GetClientMins(client, mins);
  GetClientMaxs(client, maxs);
  int absincarraysize = sizeof(absincarray);
  int limit           = 5000;
  for (int x = 0; x < absincarraysize; x++)
  {
    if (limit > 0)
    {
      for (int y = 0; y <= x; y++)
      {
        if (limit > 0)
        {
          for (int z = 0; z <= y; z++)
          {
            float pos[3] = { 0.0, 0.0, 0.0 };
            AddVectors(pos, originalpos, pos);
            pos[0] += float(absincarray[x]);
            pos[1] += float(absincarray[y]);
            pos[2] += float(absincarray[z]);
            TR_TraceHullFilter(pos, pos, mins, maxs, MASK_SOLID, CanHitThis, client);
            // int ent;
            if (!TR_DidHit(_))
            {
              AddVectors(emptypos, pos, emptypos);  /// set this global variable
              return true;
            }
            if (limit-- < 0)
            {
              break;
            }
          }
          if (limit-- < 0)
          {
            break;
          }
        }
      }
      if (limit-- < 0)
      {
        break;
      }
    }
  }
  return false;
}

public bool CanHitThis(int entityhit, int mask, any data)
{
  if (entityhit == data)
  {                // Check if the TraceRay hit the itself.
    return false;  // Don't allow self to be hit, skip this result
  }
  if (IsValidLivingClient(entityhit) && IsValidLivingClient(data) && GetClientTeam(entityhit) == GetClientTeam(data))
  {
    return false;  // skip result, prend this space is not taken cuz they on same team
  }
  return true;  // It didn't hit itself
}

stock bool IsValidLivingClient(int client)
{
  return (IsValidClient(client) && IsPlayerAlive(client));
}

stock bool IsValidClient(int clientIdx, bool replaycheck = true)
{
  if (clientIdx <= 0 || clientIdx > MaxClients)
    return false;

  if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
    return false;

  if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
    return false;

  return true;
}

public bool War3_Teleport(int client, float distance)
{
  if (client > 0)
  {
    if (IsPlayerAlive(client) && !inteleportcheck[client])
    {
      float angle[3];
      GetClientEyeAngles(client, angle);
      float endpos[3];
      float startpos[3];
      GetClientEyePosition(client, startpos);
      float dir[3];
      GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
      ScaleVector(dir, distance);
      AddVectors(startpos, dir, endpos);
      GetClientAbsOrigin(client, oldpos[client]);
      ignoreClient = client;
      TR_TraceRayFilter(startpos, endpos, MASK_ALL, RayType_EndPoint, AimTargetFilter);
      TR_GetEndPosition(endpos);
      float distanceteleport = GetVectorDistance(startpos, endpos);
      GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);  /// get dir again
      ScaleVector(dir, distanceteleport - 33.0);

      AddVectors(startpos, dir, endpos);
      emptypos[0] = 0.0;
      emptypos[1] = 0.0;
      emptypos[2] = 0.0;

      endpos[2] -= 30.0;
      getEmptyLocationHull(client, endpos);

      if (GetVectorLength(emptypos) < 1.0)
      {
        PrintHintText(client, "Cannot teleport there!");
        return false;  // it returned 0 0 0
      }

      TeleportEntity(client, emptypos, NULL_VECTOR, NULL_VECTOR);
      EmitSoundToAll(teleportSound, _, _, _, _, 0.8);
      EmitSoundToAll(teleportSound, _, _, _, _, 0.8);

      teleportpos[client][0]  = emptypos[0];
      teleportpos[client][1]  = emptypos[1];
      teleportpos[client][2]  = emptypos[2];
      inteleportcheck[client] = true;
      CreateTimer(0.14, checkTeleport, client);

      float partpos[3];
      GetClientEyePosition(client, partpos);
      partpos[2] -= 20.0;
      TeleportEffects(partpos);
      emptypos[2] += 40.0;
      TeleportEffects(emptypos);

      return true;
    }
  }
  return false;
}

public int War3_GetTargetInViewCone(int client, float max_distance)
{
  if (IsValidLivingClient(client))
  {
    ignoreClient = client;
    if (max_distance < 0.0)
      max_distance = 0.0;
    float PlayerEyePos[3];
    float PlayerAimAngles[3];
    GetClientEyePosition(client, PlayerEyePos);
    GetClientEyeAngles(client, PlayerAimAngles);
    float PlayerAimVector[3];
    GetAngleVectors(PlayerAimAngles, PlayerAimVector, NULL_VECTOR, NULL_VECTOR);
    int   bestTarget = 0;
    float endpos[3];
    if (max_distance > 0.0)
    {
      ScaleVector(PlayerAimVector, max_distance);
    }
    else {
      ScaleVector(PlayerAimVector, 56756.0);
      AddVectors(PlayerEyePos, PlayerAimVector, endpos);
      TR_TraceRayFilter(PlayerEyePos, endpos, MASK_ALL, RayType_EndPoint, AimTargetFilter);
      if (TR_DidHit())
      {
        int entity = TR_GetEntityIndex();
        if (entity > 0 && entity <= MaxClients && IsClientConnected(entity) && IsPlayerAlive(entity) && GetClientTeam(client) != GetClientTeam(entity))
          bestTarget = entity;
      }
    }
    return bestTarget;
  }
  return 0;
}

public bool AimTargetFilter(int entity, int mask)
{
  return !(entity == ignoreClient);
}

public Action StopEntangle(Handle timer, any client)
{
  if (IsClientInGame(client) && IsPlayerAlive(client))
    SetEntityMoveType(client, MOVETYPE_WALK);

  return Plugin_Continue;
}
