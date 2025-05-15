/*
  "ability_hack"
  {
    // slot is ignored.
    "ragecost"    		  "10.0"			// rage cost per use
    "duration"    		  "10.0"			// Time being hacked - 0 means forever
    "aimbot"    			  "1"					// 1-Aimbot disabled 0 - Aimbot active
    "lastman"				    "1"					// 1-If only one player disable hack ability 0-No disable
    "preventtaunt"		  "1"					// 1-Prevent taunt 0-Don't prevent taunt
    "building"          "1"					// does this ability work on buildings? 1-yes 0-no (this will destroy the building after the duration)

    // HUD Parameters
    "hud"               "1"                       // 1-Enable HUD 0-Disable HUD
    "hud_postion"       "-1.0 ; 0.73"             // X ; Y position (-1.0 = center)
    "hud_norage"        "Not enough rage to hack! (%.0f%% needed)"    // Text when not enough rage
    "hud_norage_color"  "255 ; 255 ; 255 ; 255"   // Text color when not enough rage (rgba : 0-255)
    "hud_ready"         "Hack Ready! (Reload to use)"    // Text when ability is ready
    "hud_ready_color"   "255 ; 0 ; 0 ; 255"       // Text color when ability is ready

    "plugin_name"       "ff2r_hacks"
  }
 */

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Hacks",
  author  = "Naydef, zell",
  version = "1.4",
  url     = ""
};

bool   g_bHudEnabled[MAXPLAYERS + 1];    // HUD enabled
Handle g_hHudSync = null;                // Handle for HUD synchronizer
bool   g_bIsHacked[MAXPLAYERS + 1];      // Internal
float  g_flHackTime[MAXPLAYERS + 1];     // Hacked players time
bool   g_bIsAimBot[MAXPLAYERS + 1];      // Hacked players aimbot
bool   g_bPreventTaunt[MAXPLAYERS + 1];  // 1-Prevent taunt 0-Don't prevent taunt
public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }

  g_hHudSync = CreateHudSynchronizer();

  HookEvent("arena_win_panel", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_win", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);

  AddCommandListener(Command_InterceptTaunt, "+taunt");
  AddCommandListener(Command_InterceptTaunt, "taunt");
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }

  if (g_hHudSync != null)
  {
    CloseHandle(g_hHudSync);
    g_hHudSync = null;
  }

  UnhookEvent("arena_win_panel", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("teamplay_round_win", Event_OnRoundEnd, EventHookMode_PostNoCopy);
  UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
}

public Action Command_InterceptTaunt(int client, const char[] command, int args)
{
  if (IsValidClient(client) && g_bIsHacked[client] && g_bPreventTaunt[client])
  {
    return Plugin_Handled;
  }
  return Plugin_Continue;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    g_bHudEnabled[client]   = false;
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData ability = cfg.GetAbility("ability_hack");
    if (ability.IsMyPlugin())
    {
      g_bHudEnabled[client] = ability.GetBool("hud", true);
    }
  }
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;
  if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)  // Dead Ringer spies
    return;
  if (g_bIsHacked[client])
  {
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }

  if (g_bHudEnabled[client])
  {
    g_bHudEnabled[client] = false;
  }
}

public void OnClientDisconnect_Post(int client)
{
  if (g_bIsHacked[client])
  {
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    g_bIsHacked[client]     = false;
    g_flHackTime[client]    = INACTIVE;
    g_bIsAimBot[client]     = false;
    g_bPreventTaunt[client] = false;
  }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
  if (!IsValidClient(client) || !IsPlayerAlive(client))
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(client);

  if (!boss)
    return Plugin_Continue;

  AbilityData ability = boss.GetAbility("ability_hack");

  if (!ability.IsMyPlugin())
    return Plugin_Continue;

  float  cost      = ability.GetFloat("ragecost", 0.0);
  float  charge    = GetBossCharge(boss, "0");

  bool   lastman   = ability.GetBool("lastman", true);

  TFTeam bossTeam  = TF2_GetClientTeam(client);                             // get boss team
  TFTeam enemyTeam = (bossTeam == TFTeam_Blue) ? TFTeam_Red : TFTeam_Blue;  // get enemy team

  // Show HUD status
  if (g_hHudSync != null && g_bHudEnabled[client])
  {
    char hudPos[64];
    ability.GetString("hud_postion", hudPos, sizeof(hudPos), "-1.0 ; 0.73");

    // Split the position string
    float hudX = -1.0, hudY = 0.73;
    char  positions[2][16];
    if (ExplodeString(hudPos, " ; ", positions, sizeof(positions), sizeof(positions[])) == 2)
    {
      hudX = StringToFloat(positions[0]);
      hudY = StringToFloat(positions[1]);
    }

    char readyText[128], norageText[128];
    ability.GetString("hud_ready", readyText, sizeof(readyText), "Hack Ready! (Reload to use)");
    ability.GetString("hud_norage", norageText, sizeof(norageText), "Not enough rage! (%.0f%% needed)");

    // Get and split color strings
    char readyColorStr[64], norageColorStr[64];
    ability.GetString("hud_ready_color", readyColorStr, sizeof(readyColorStr), "255 ; 0 ; 0 ; 255");
    ability.GetString("hud_norage_color", norageColorStr, sizeof(norageColorStr), "255 ; 255 ; 255 ; 255");

    int  readyColor[4]  = { 255, 0, 0, 255 };
    int  norageColor[4] = { 255, 255, 255, 255 };

    // Split ready color
    char readyColors[4][8];
    if (ExplodeString(readyColorStr, " ; ", readyColors, sizeof(readyColors), sizeof(readyColors[])) == 4)
    {
      readyColor[0] = StringToInt(readyColors[0]);
      readyColor[1] = StringToInt(readyColors[1]);
      readyColor[2] = StringToInt(readyColors[2]);
      readyColor[3] = StringToInt(readyColors[3]);
    }

    // Split norage color
    char norageColors[4][8];
    if (ExplodeString(norageColorStr, " ; ", norageColors, sizeof(norageColors), sizeof(norageColors[])) == 4)
    {
      norageColor[0] = StringToInt(norageColors[0]);
      norageColor[1] = StringToInt(norageColors[1]);
      norageColor[2] = StringToInt(norageColors[2]);
      norageColor[3] = StringToInt(norageColors[3]);
    }

    if (lastman && GetTeamClientAliveCount(enemyTeam) == 1)
    {
      SetHudTextParams(hudX, hudY, 0.15, norageColor[0], norageColor[1], norageColor[2], norageColor[3]);
      ShowSyncHudText(client, g_hHudSync, "You are not allowed to hack the last player!");
    }
    else if (charge >= cost)
    {
      SetHudTextParams(hudX, hudY, 0.15, readyColor[0], readyColor[1], readyColor[2], readyColor[3]);
      ShowSyncHudText(client, g_hHudSync, readyText);
    }
    else
    {
      SetHudTextParams(hudX, hudY, 0.15, norageColor[0], norageColor[1], norageColor[2], norageColor[3]);
      ShowSyncHudText(client, g_hHudSync, norageText, cost, charge);
    }
  }

  if (buttons & IN_RELOAD)
  {
    // prevent last team
    if (GetTeamClientAliveCount(enemyTeam) == 1 && lastman)
    {
      if (!g_bHudEnabled[client])
      {
        PrintHintText(client, "You are not allowed to hack the last player!");
      }

      return Plugin_Continue;
    }

    bool buildingHack = ability.GetBool("building", true);

    if (charge >= cost)
    {
      int  target     = TraceToObject(client);

      // Check if target is a building
      bool isBuilding = false;
      char classname[32];
      if (IsValidEntity(target))
      {
        GetEntityClassname(target, classname, sizeof(classname));
        if (StrEqual(classname, "obj_sentrygun") || StrEqual(classname, "obj_dispenser") || StrEqual(classname, "obj_teleporter"))
        {
          isBuilding = true;
        }
      }

      if (IsValidClient(target) && IsPlayerAlive(target) && !g_bIsHacked[target] && TF2_GetClientTeam(target) == enemyTeam)
      {
        PrintHintText(client, "You hacked %N!", target);
        PrintCenterText(target, "You are hacked!");
        SetBossCharge(boss, "0", charge - cost);
        ConvertToTeam(target, bossTeam);

        g_bIsHacked[target]     = true;
        g_flHackTime[target]    = GetEngineTime() + ability.GetFloat("duration", 10.0);
        g_bIsAimBot[target]     = ability.GetBool("aimbot", false);
        g_bPreventTaunt[target] = ability.GetBool("preventtaunt", false);

        SDKHook(target, SDKHook_PreThink, HackPreThink);
      }
      else if (isBuilding && buildingHack)
      {
        // Handle building hack
        int builder = GetEntPropEnt(target, Prop_Send, "m_hBuilder");
        if (IsValidClient(builder) && GetClientTeam(builder) == view_as<int>(enemyTeam))
        {
          SetBossCharge(boss, "0", charge - cost);
          AcceptEntityInput(target, "SetBuilder", client);
          SetEntPropEnt(target, Prop_Send, "m_hBuilder", client);
          SetEntProp(target, Prop_Send, "m_iTeamNum", view_as<int>(bossTeam));
          SetEntProp(target, Prop_Send, "m_nSkin", view_as<int>(bossTeam) - 2);
          PrintHintText(client, "You hacked %N's building!", builder);
          PrintCenterText(builder, "Your building is hacked!");

          // Optional: Kill the building after duration
          if (ability.GetFloat("duration", 10.0) > 0)
          {
            CreateTimer(ability.GetFloat("duration", 10.0), Timer_DestroyBuilding, EntIndexToEntRef(target));
          }
        }
      }
    }
    else if (!g_bHudEnabled[client])
    {
      PrintHintText(client, "Not enough rage to hack! (%.0f%% needed)", cost, charge);
    }
  }
  return Plugin_Continue;
}

public Action Timer_DestroyBuilding(Handle timer, any buildingRef)
{
  int building = EntRefToEntIndex(buildingRef);
  if (building != INVALID_ENT_REFERENCE && IsValidEntity(building))
  {
    SetVariantInt(9999);
    AcceptEntityInput(building, "RemoveHealth");
  }
  return Plugin_Stop;
}

public void HackPreThink(int client)
{
  if (g_flHackTime[client] < GetEngineTime())
  {
    if (IsValidClient(client) && IsPlayerAlive(client) && g_bIsHacked[client])
    {
      g_bIsHacked[client]     = false;
      g_flHackTime[client]    = INACTIVE;
      g_bIsAimBot[client]     = false;
      g_bPreventTaunt[client] = false;

      PrintCenterText(client, "You are free!");

      TFTeam team      = TF2_GetClientTeam(client);                         // get boss team
      TFTeam enemyTeam = (team == TFTeam_Blue) ? TFTeam_Red : TFTeam_Blue;  // get enemy team
      // return to original team
      ConvertToTeam(client, enemyTeam);
    }
    SDKUnhook(client, SDKHook_PreThink, HackPreThink);
    return;
  }

  if (g_bPreventTaunt[client] && TF2_IsPlayerInCondition(client, TFCond_Taunting))
  {
    // Prevent taunt
    TF2_RemoveCondition(client, TFCond_Taunting);
  }

  if (g_bIsAimBot[client])
  {
    int i = GetClosestClient(client);
    if (i == -1)
      return;

    int buttons = GetClientButtons(client);
    if (buttons & IN_ATTACK)
    {
      // Aimbot
      float clientEye[3], iEye[3], clientAngle[3];
      GetClientEyePosition(client, clientEye);
      GetClientEyePosition(i, iEye);
      GetVectorAnglesTwoPoints(clientEye, iEye, clientAngle);
      AnglesNormalize(clientAngle);
      TeleportEntity(client, NULL_VECTOR, clientAngle, NULL_VECTOR);
    }
  }
}

stock int GetClosestClient(int client)
{
  float fClientLocation[3];
  float fEntityOrigin[3];
  GetClientAbsOrigin(client, fClientLocation);

  int   iClosestEntity   = -1;
  float fClosestDistance = -1.0;
  for (int i = 1; i < MaxClients; i++)
  {
    if (IsValidClient(i) && GetClientTeam(i) != GetClientTeam(client) && IsPlayerAlive(i) && i != client)
    {
      GetClientAbsOrigin(i, fEntityOrigin);
      float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
      if ((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
      {
        if (CanSeeTarget(client, i, GetClientTeam(client), false))
        {
          fClosestDistance = fEntityDistance;
          iClosestEntity   = i;
        }
      }
    }
  }
  return iClosestEntity;
}

public int TraceToObject(int client)
{
  float vecClientEyePos[3], vecClientEyeAng[3];
  GetClientEyePosition(client, vecClientEyePos);
  GetClientEyeAngles(client, vecClientEyeAng);

  Handle trace  = TR_TraceRayFilterEx(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayGrab, client);

  int    entity = -1;
  if (TR_DidHit(trace))
  {
    entity = TR_GetEntityIndex(trace);
  }
  delete trace;
  return entity;
}

stock void AnglesNormalize(float vAngles[3])
{
  while (vAngles[0] > 89.0)
    vAngles[0] -= 360.0;
  while (vAngles[0] < -89.0)
    vAngles[0] += 360.0;
  while (vAngles[1] > 180.0)
    vAngles[1] -= 360.0;
  while (vAngles[1] < -180.0)
    vAngles[1] += 360.0;
}

stock void GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
  static float tmpVec[3];
  tmpVec[0] = vEndPos[0] - vStartPos[0];
  tmpVec[1] = vEndPos[1] - vStartPos[1];
  tmpVec[2] = vEndPos[2] - vStartPos[2];
  GetVectorAngles(tmpVec, vAngles);
}

public bool CanSeeTarget(int iClient, int iTarget, int iTeam, bool bCheckFOV)
{
  float flStart[3], flEnd[3];
  GetClientEyePosition(iClient, flStart);
  GetClientEyePosition(iTarget, flEnd);

  TR_TraceRayFilter(flStart, flEnd, MASK_SOLID, RayType_EndPoint, TraceRayFilterClients, iTarget);
  if (TR_GetEntityIndex() == iTarget)
  {
    if (TF2_GetPlayerClass(iTarget) == TFClass_Spy)
    {
      if (TF2_IsPlayerInCondition(iTarget, TFCond_Cloaked) || TF2_IsPlayerInCondition(iTarget, TFCond_Disguised))
      {
        if (TF2_IsPlayerInCondition(iTarget, TFCond_CloakFlicker)
            || TF2_IsPlayerInCondition(iTarget, TFCond_OnFire)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Jarated)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Milked)
            || TF2_IsPlayerInCondition(iTarget, TFCond_Bleeding))
        {
          return true;
        }

        return false;
      }
      if (TF2_IsPlayerInCondition(iTarget, TFCond_Disguised) && GetEntProp(iTarget, Prop_Send, "m_nDisguiseTeam") == iTeam)
      {
        return false;
      }

      return true;
    }

    if (TF2_IsPlayerInCondition(iTarget, TFCond_Ubercharged)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedHidden)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedCanteen)
        || TF2_IsPlayerInCondition(iTarget, TFCond_UberchargedOnTakeDamage)
        || TF2_IsPlayerInCondition(iTarget, TFCond_PreventDeath)
        || TF2_IsPlayerInCondition(iTarget, TFCond_Bonked))
    {
      return false;
    }
    if (bCheckFOV)
    {
      return true;
    }

    return true;
  }
  return false;
}

public bool TraceRayFilterClients(int iEntity, int iMask, any hData)
{
  if (iEntity > 0 && iEntity <= MaxClients)
  {
    if (iEntity == hData)
    {
      return true;
    }
    else
    {
      return false;
    }
  }
  return true;
}

// Modify TraceRayGrab to include buildings
public bool TraceRayGrab(int entityhit, int mask, any self)
{
  if (entityhit > 0)
  {
    if (entityhit <= MaxClients)
    {
      if (IsPlayerAlive(entityhit) && entityhit != self)
      {
        return true;
      }
    }
    else
    {
      char classname[32];
      if (GetEntityClassname(entityhit, classname, sizeof(classname)))
      {
        if (StrEqual(classname, "prop_physics") || StrEqual(classname, "tf_ammo_pack") || !StrContains(classname, "tf_projectil") || StrEqual(classname, "obj_sentrygun") || StrEqual(classname, "obj_dispenser") || StrEqual(classname, "obj_teleporter"))
        {
          return true;
        }
      }
    }
  }
  return false;
}

public void ConvertToTeam(int client, TFTeam team)
{
  SetEntProp(client, Prop_Send, "m_lifeState", 2);

  ChangeClientTeam(client, view_as<int>(team));

  SetEntProp(client, Prop_Send, "m_lifeState", 0);

  if (GetEntProp(client, Prop_Send, "m_bDucked"))
  {
    float collisionvec[3];
    collisionvec[0] = 24.0;
    collisionvec[1] = 24.0;
    collisionvec[2] = 62.0;
    SetEntPropVector(client, Prop_Send, "m_vecMaxs", collisionvec);
    SetEntProp(client, Prop_Send, "m_bDucked", 1);
    SetEntityFlags(client, FL_DUCKING);
  }
}

public float GetBossCharge(ConfigData cfg, const char[] slot)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  return cfg.GetFloat(buffer);
}

public void SetBossCharge(ConfigData cfg, const char[] slot, float amount)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  cfg.SetFloat(buffer, amount);
}

stock int GetTeamClientAliveCount(TFTeam team)
{
  int count = 0;
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == team)  // Fixed variable name
    {
      count++;
    }
  }
  return count;
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