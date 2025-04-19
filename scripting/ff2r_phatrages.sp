/*
  "rage_ioncannon"
  {
    "timer"			"5"    // Timer    (How long it takes for the ion cannon blast to hit it's target in seconds.)
    "radius"			"500"    // Blast Radius    (Blast radius in units.)
    "damage"			"800"    // Blast Damage    (Amount of damage delivered by the blast.)
    "aimmode"			"0"    // Aim Mode     (0 = ion cannon is aimed at where boss is standing. 1 = ion cannon is aimed at where boss is looking.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_delirium"
  {
    "range" ""  //Range
    "duration" ""  //Duration

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_hellfire"
  {
    "sound"			"true"    // Sound             (0 = No flame sound. 1 = Play flame sound.)
    "damage"			"30"   // Damage        (Amount of damage delivered by the initial fire blast.)
    "range"			"700"  // Range            (Radius of fire blast.)
    "afterburn damage"			"10"   // Afterburn Damage    (Amount of damage delivered by afterburn.)
    "afterburn duration"			"5"    // Afterburn Duration     (Duration of afterburn in seconds.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_scaleboss"
  {
    "scale"			"2.0"    // Scale Factor    (Resize the boss by this factor.)
    "duration"			"7"    // Duration    (Duration of resized effect in seconds.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_scaleplayers"
  {
    "scale"			"2.0"    // Scale Factor    (Resize players by this factor.)
    "duration"			"7"    // Duration    (Duration of resized effect in seconds.)
    "range"			"400"    // Range    (Range of resizing effect.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_drown"
  {
    "duration"			"15"    // Duration    (Duration of drowning effect in seconds.)
    "range"			"600"    // Range    (Range of drowning effect.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_explosion"
  {
    "damage"			"400"   // Damage            (Amount of damage delivered by fireball explosion)
    "range"			"400"    // Range            (Range of fireball explosion.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

/*
  "rage_visualeffect"
  {
    "effect"			"0"   // Visual Effect            (0-8 Choice of visual effect, see below.)
    "duration"			"10"    // Duration    (Duration of visual effect in seconds.)
    "range"			"600"    // Range    (Range of visual effect.)

    "plugin_name"	"ff2r_phatrages"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

// Miscs
#define FFADE_OUT 0x0002  // Fade out
int    gSmoke1;
int    gGlow1;
int    gHalo1;
int    gExplosive1;
int    gLaser1;
int    gAfterburn;
int    gExplosion;
int    fov_offset;
int    zoom_offset;
float  INACTIVE = 100000000.0;

// Ion Cannon
float  distance;
int    IOCDist;
int    IOCdamage;
bool   aimmode;
int    rgba[4];

// Delirium
float  DeliriumDistance;
float  DeliriumDuration;
float  g_DrugAngles[56] = { 0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0, 30.0, 33.0, 36.0, 39.0, 42.0, 39.0, 36.0, 33.0, 30.0, 27.0, 24.0, 21.0, 18.0, 15.0, 12.0, 9.0, 6.0, 3.0, 0.0, -3.0, -6.0, -9.0, -12.0, -15.0, -18.0, -21.0, -24.0, -27.0, -30.0, -33.0, -36.0, -39.0, -42.0, -39.0, -36.0, -33.0, -30.0, -27.0, -24.0, -21.0, -18.0, -15.0, -12.0, -9.0, -6.0, -3.0 };
Handle specialDrugTimers[MAXPLAYERS + 1];

// Hellfire
bool   hellsound;
float  rageDamage;
float  rageDistance;
float  afterBurnDamage;
float  afterBurnDuration;

// Scaling
float  oldScale[MAXPLAYERS + 1];

// Scale Boss
float  BossScale;
float  BossDuration;

// Scale Players
float  PlayerScale;
float  PlayerDuration;
float  PlayerDistance;

// Drown
float  DrownDuration;
float  DrownDistance;

// Visualeffects
int    VisualEffect;
float  EffectDuration;
float  EffectDistance;

// Hitboxes
bool   isHitBoxAvailable = false;

//#include "freak_fortress_2/formula_parser.sp"
public Plugin myinfo =
{
  name    = "Freak Fortress 2 Rewrite: Phat Rages",
  author  = "frog,Kemsan,Peace Maker,LeGone,RainBolt Dash, SHADoW NiNE TR3S, M76030, Zell",
  version = "0.9.8",
};

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      BossData cfg = FF2R_GetBossData(client);
      if (cfg)
      {
        FF2R_OnBossCreated(client, cfg, false);
      }
    }
  }
}

public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client) && FF2R_GetBossData(client))
    {
      FF2R_OnBossRemoved(client);
    }
  }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    fov_offset  = FindSendPropInfo("CBasePlayer", "m_iFOV");
    zoom_offset = FindSendPropInfo("CBasePlayer", "m_iDefaultFOV");

    HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);

    isHitBoxAvailable = ((FindSendPropInfo("CBasePlayer", "m_vecSpecifiedSurroundingMins") != -1) && FindSendPropInfo("CBasePlayer", "m_vecSpecifiedSurroundingMaxs") != -1);

    gLaser1           = PrecacheModel("materials/sprites/laser.vmt");
    gSmoke1           = PrecacheModel("materials/effects/fire_cloud1.vmt");
    gHalo1            = PrecacheModel("materials/sprites/halo01.vmt");
    gGlow1            = PrecacheModel("sprites/blueglow2.vmt", true);
    gExplosive1       = PrecacheModel("materials/sprites/sprite_fire01.vmt");
    PrecacheModel("models/props_wasteland/rockgranite03b.mdl");
    PrecacheSound("misc/flame_engulf.wav", true);
    PrecacheSound("ambient/explosions/citadel_end_explosion2.wav", true);
    PrecacheSound("ambient/explosions/citadel_end_explosion1.wav", true);
    PrecacheSound("ambient/energy/weld1.wav", true);
    PrecacheSound("ambient/halloween/mysterious_perc_01.wav", true);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (!IsValidClient(i))
        continue;
      oldScale[i] = 1.0;
    }

    // Delirium
    DeliriumDuration    = INACTIVE;
    // Scale Boss
    BossDuration        = INACTIVE;
    // Scale Players
    PlayerDuration      = INACTIVE;
    // Drown
    DrownDuration       = INACTIVE;
    // Visualeffects
    EffectDuration      = INACTIVE;

    int BossMeleeweapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
    if (BossMeleeweapon != -1)
    {
      if (GetEntProp(BossMeleeweapon, Prop_Send, "m_iItemDefinitionIndex") == 307)
        SDKHook(client, SDKHook_PreThink, CaberReset);
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  CreateTimer(0.1, EndSickness);
  CreateTimer(0.2, ResetScale);
  CreateTimer(0.3, EndDrowning);
  CreateTimer(0.4, ResetCaber);

  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsValidClient(client))
    {
      oldScale[client] = 1.0;
      // Delirium
      DeliriumDuration = INACTIVE;
      // Scale Boss
      BossDuration     = INACTIVE;
      // Scale Players
      PlayerDuration   = INACTIVE;
      // Drown
      DrownDuration    = INACTIVE;
      // Visualeffects
      EffectDuration   = INACTIVE;
    }
  }
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  SetEntData(client, fov_offset, 90, 4, true);
  SetEntData(client, zoom_offset, 90, 4, true);
  ClientCommand(client, "r_screenoverlay 0");
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_ioncannon", false) && cfg.IsMyPlugin())
  {
    Rage_IonCannon(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_delirium", false) && cfg.IsMyPlugin()) {
    Rage_Delirium(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_hellfire", false) && cfg.IsMyPlugin()) {
    Rage_Hellfire(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_scaleboss", false) && cfg.IsMyPlugin()) {
    Rage_ScaleBoss(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_scaleplayers", false) && cfg.IsMyPlugin()) {
    Rage_ScalePlayers(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_explosion", false) && cfg.IsMyPlugin()) {
    Rage_Explosion(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_drown", false) && cfg.IsMyPlugin()) {
    Rage_Drown(client, ability, cfg);
  }
  else if (!StrContains(ability, "rage_visualeffect", false) && cfg.IsMyPlugin()) {
    Rage_VisualEffect(client, ability, cfg);
  }
}

public void Rage_VisualEffect(int clientIdx, const char[] ability, AbilityData cfg)
{
  VisualEffect   = cfg.GetInt("effect");                        // effect
  EffectDuration = GetEngineTime() + cfg.GetFloat("duration");  // duration
  EffectDistance = cfg.GetFloat("range");                       // range

  float pos[3];
  float pos2[3];

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      if ((GetVectorDistance(pos, pos2) < EffectDistance))
      {
        SetVariantInt(0);
        AcceptEntityInput(i, "SetForcedTauntCam");

        if (VisualEffect == 0)
        {
          ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tp_eyefx.vmt");  // extreme fish eye
        }
        else if (VisualEffect == 1) {
          ClientCommand(i, "r_screenoverlay effects/strider_bulge_dudv.vmt");  // central screen crunch
        }
        else if (VisualEffect == 2) {
          ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye.vmt");  // rainbow flashes
        }
        else if (VisualEffect == 3) {
          ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye2.vmt");  // fire flashes
        }
        else if (VisualEffect == 4) {
          ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye3.vmt");  // blue/green flashes
        }
        else if (VisualEffect == 5) {
          ClientCommand(i, "r_screenoverlay effects/com_shield003a.vmt");  // blue/green web
        }
        else if (VisualEffect == 6) {
          ClientCommand(i, "r_screenoverlay effects/ar2_altfire1.vmt");  // central fire ball
        }
        else if (VisualEffect == 7) {
          ClientCommand(i, "r_screenoverlay effects/screenwarp.vmt");  // golden madness opaque
        }
        else if (VisualEffect == 8) {
          ClientCommand(i, "r_screenoverlay effects/tvscreen_noise002a.vmt");  // tv static transparent
        }
        SDKHook(i, SDKHook_PreThink, Visual_Prethink);
      }
    }
  }
}

public void Visual_Prethink(int client)
{
  EffectTick(client, GetEngineTime());
}

public void EffectTick(int client, float gameTime)
{
  if (gameTime >= EffectDuration)
  {
    EffectDuration = INACTIVE;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i))
        ClientCommand(i, "r_screenoverlay 0");
    }
    SDKUnhook(client, SDKHook_PreThink, Visual_Prethink);
  }
}

public void Rage_Drown(int clientIdx, const char[] ability, AbilityData cfg)
{
  DrownDuration = GetEngineTime() + cfg.GetFloat("duration");  // duration
  DrownDistance = cfg.GetFloat("range");                       // range

  float pos[3];
  float pos2[3];

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      if ((GetVectorDistance(pos, pos2) < DrownDistance))
        SDKHook(i, SDKHook_PreThink, DrownEvent);
    }
  }
}

public void DrownEvent(int client)
{
  SetEntProp(client, Prop_Send, "m_nWaterLevel", 3);
  DrownTick(client, GetEngineTime());
}

public void DrownTick(int client, float gameTime)
{
  if (gameTime >= DrownDuration)
  {
    DrownDuration = INACTIVE;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i))
        SDKUnhook(i, SDKHook_PreThink, DrownEvent);
    }
  }
}

public Action EndDrowning(Handle timer)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i))
      SDKUnhook(i, SDKHook_PreThink, DrownEvent);
  }
  return Plugin_Stop;
}

public void Rage_Explosion(int clientIdx, const char[] ability, AbilityData cfg)
{
  float damage = cfg.GetFloat("damage", 100.0);  // damage
  float range  = cfg.GetFloat("range");          // damage radius

  float vOrigin[3];

  gExplosion = 0;

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", vOrigin);

  Handle data = CreateDataPack();
  CreateDataTimer(0.12, SetExplosion, data, TIMER_REPEAT);
  WritePackFloat(data, vOrigin[0]);
  WritePackFloat(data, vOrigin[1]);
  WritePackFloat(data, vOrigin[2]);
  WritePackCell(data, range);   // Range
  WritePackCell(data, damage);  // Damge
  WritePackCell(data, clientIdx);
  ResetPack(data);
  env_shake(vOrigin, 120.0, 10000.0, 4.0, 50.0);
}

public Action SetExplosion(Handle timer, Handle data)
{
  ResetPack(data);
  float vOrigin[3];
  vOrigin[0]   = ReadPackFloat(data);
  vOrigin[1]   = ReadPackFloat(data);
  vOrigin[2]   = ReadPackFloat(data);
  float range  = ReadPackCell(data);
  float damage = ReadPackCell(data);
  int   client = ReadPackCell(data);

  gExplosion++;

  if (gExplosion >= 15)
  {
    gExplosion = 0;
    return Plugin_Stop;
  }

  for (int i = 0; i < 5; i++)
  {
    int proj = CreateEntityByName("env_explosion");
    DispatchKeyValueFloat(proj, "DamageForce", 180.0);
    SetEntProp(proj, Prop_Data, "m_iMagnitude", 400, 4);
    SetEntProp(proj, Prop_Data, "m_iRadiusOverride", 400, 4);
    SetEntPropEnt(proj, Prop_Data, "m_hOwnerEntity", client);
    DispatchSpawn(proj);

    AcceptEntityInput(proj, "Explode");
    AcceptEntityInput(proj, "kill");
  }
  if (gExplosion % 4 == 1)
    SetExplodeAtClient(client, damage, range, DMG_BLAST);
  return Plugin_Continue;
}

public void Rage_ScaleBoss(int clientIdx, const char[] ability, AbilityData cfg)
{
  oldScale[clientIdx] = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
  BossScale           = cfg.GetFloat("scale");  // scale

  if (BossScale != oldScale[clientIdx])
  {
    if (BossScale > oldScale[clientIdx])
    {
      float curpos[3];
      GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", curpos);
      if (!IsSpotSafe(clientIdx, curpos, BossScale))
      {
        PrintHintText(clientIdx, "You were not resized %f times to avoid getting stuck!", BossScale);
        LogError("[PhatRages] %N was not resized %f times to avoid getting stuck!", clientIdx, BossScale);
        return;
      }
    }

    SetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale", BossScale);
    if (isHitBoxAvailable)
      UpdatePlayerHitbox(clientIdx, BossScale);

    SDKHook(clientIdx, SDKHook_PreThink, Scale_Prethink);
    if (BossDuration != INACTIVE)
      BossDuration = cfg.GetFloat("duration");
    else
      BossDuration = GetEngineTime() + cfg.GetFloat("duration");  // duration
  }
}

public void Rage_ScalePlayers(int clientIdx, const char[] ability, AbilityData cfg)
{
  PlayerScale = cfg.GetFloat("scale");  // scale
  if (PlayerDuration != INACTIVE)
    PlayerDuration += cfg.GetFloat("duration");  // duration
  else
    PlayerDuration = GetEngineTime() + cfg.GetFloat("duration");  // duration
  PlayerDistance = cfg.GetFloat("range");                         // range

  float pos[3];
  float pos2[3];

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      if ((GetVectorDistance(pos, pos2) < PlayerDistance))
      {
        oldScale[i] = GetEntPropFloat(i, Prop_Send, "m_flModelScale");
        if (PlayerScale != oldScale[i])
        {
          if (PlayerScale > oldScale[i])
          {
            float curpos[3];
            GetEntPropVector(i, Prop_Data, "m_vecOrigin", curpos);
            if (!IsSpotSafe(i, curpos, PlayerScale))
            {
              PrintHintText(i, "You were not resized %f times to avoid getting stuck!", PlayerScale);
              LogError("[PhatRages] %N was not resized %f times to avoid getting stuck!", i, PlayerScale);
              return;
            }
          }

          if (isHitBoxAvailable)
          {
            UpdatePlayerHitbox(i, PlayerScale);
          }

          SDKHook(i, SDKHook_PreThink, Scale_Prethink);
          SetEntPropFloat(i, Prop_Send, "m_flModelScale", PlayerScale);
        }
      }
    }
  }
}

public void Scale_Prethink(int client)
{
  ScaleTick(client, GetEngineTime());
}

public void ScaleTick(int client, float gameTime)
{
  if (gameTime >= PlayerDuration)
  {
    PlayerDuration = INACTIVE;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i))
      {
        SDKUnhook(i, SDKHook_PreThink, Scale_Prethink);

        if (oldScale[client] > PlayerScale)
        {
          float curpos[3];
          GetEntPropVector(i, Prop_Data, "m_vecOrigin", curpos);
          if (!IsSpotSafe(i, curpos, oldScale[i]))
          {
            PrintHintText(i, "You were not resized %f times to avoid getting stuck!", oldScale[i]);
            LogError("[PhatRages] %N was not resized %f times to avoid getting stuck!", i, oldScale[i]);
            return;
          }
        }

        SetEntPropFloat(i, Prop_Send, "m_flModelScale", oldScale[i]);
        if (isHitBoxAvailable)
          UpdatePlayerHitbox(i, oldScale[i]);
      }
    }
  }
  if (gameTime >= BossDuration)
  {
    BossDuration = INACTIVE;
    SDKUnhook(client, SDKHook_PreThink, Scale_Prethink);

    if (oldScale[client] > BossScale)
    {
      float curpos[3];
      GetEntPropVector(client, Prop_Data, "m_vecOrigin", curpos);
      if (!IsSpotSafe(client, curpos, oldScale[client]))
      {
        PrintHintText(client, "You were not resized %f times to avoid getting stuck!", oldScale[client]);
        LogError("[PhatRages] %N was not resized %f times to avoid getting stuck!", client, oldScale[client]);
        return;
      }
    }

    SetEntPropFloat(client, Prop_Send, "m_flModelScale", oldScale[client]);
    if (isHitBoxAvailable)
    {
      UpdatePlayerHitbox(client, oldScale[client]);
    }
  }
}

public Action ResetScale(Handle timer)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i))
    {
      SetEntPropFloat(i, Prop_Send, "m_flModelScale", oldScale[i] != 1.0 ? 1.0 : oldScale[i]);
      if (isHitBoxAvailable)
        UpdatePlayerHitbox(i, oldScale[i] != 1.0 ? 1.0 : oldScale[i]);
    }
  }
  return Plugin_Stop;
}

/*
  sarysa's safe resizing code
*/

bool ResizeTraceFailed;
int  ResizeMyTeam;

public bool Resize_TracePlayersAndBuildings(int entity, int contentsMask)
{
  if (IsValidClient(entity, true))
  {
    if (GetClientTeam(entity) != ResizeMyTeam)
      ResizeTraceFailed = true;
  }
  else if (IsValidEntity(entity)) {
    static char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    if ((strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0)
        || (strcmp(classname, "prop_dynamic") == 0) || (strcmp(classname, "func_physbox") == 0) || (strcmp(classname, "func_breakable") == 0))
    {
      ResizeTraceFailed = true;
    }
  }

  return false;
}

stock bool Resize_OneTrace(const float startPos[3], const float endPos[3])
{
  static float result[3];
  TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, Resize_TracePlayersAndBuildings);
  if (ResizeTraceFailed)
    return false;
  TR_GetEndPosition(result);
  if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
    return false;

  return true;
}

// the purpose of this method is to first trace outward, upward, and then back in.
stock bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset)
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
    if (!Resize_OneTrace(tmpOrigin, targetOrigin))
      return false;

  tmpOrigin[0] = targetOrigin[0];
  tmpOrigin[1] = targetOrigin[1];
  tmpOrigin[2] = targetOrigin[2] + zOffset;

  if (!Resize_OneTrace(targetOrigin, tmpOrigin))
    return false;

  targetOrigin[0] = bossOrigin[0];
  targetOrigin[1] = bossOrigin[1];
  targetOrigin[2] = bossOrigin[2] + zOffset;

  if (!(xOffset == 0.0 && yOffset == 0.0))
    if (!Resize_OneTrace(tmpOrigin, targetOrigin))
      return false;

  return true;
}

stock bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset)
{
  static float pointA[3];
  static float pointB[3];
  for (int phase = 0; phase <= 7; phase++)
  {
    // going counterclockwise
    if (phase == 0)
    {
      pointA[0] = bossOrigin[0] + 0.0;
      pointA[1] = bossOrigin[1] + ymax;
      pointB[0] = bossOrigin[0] + xmax;
      pointB[1] = bossOrigin[1] + ymax;
    }
    else if (phase == 1) {
      pointA[0] = bossOrigin[0] + xmax;
      pointA[1] = bossOrigin[1] + ymax;
      pointB[0] = bossOrigin[0] + xmax;
      pointB[1] = bossOrigin[1] + 0.0;
    }
    else if (phase == 2) {
      pointA[0] = bossOrigin[0] + xmax;
      pointA[1] = bossOrigin[1] + 0.0;
      pointB[0] = bossOrigin[0] + xmax;
      pointB[1] = bossOrigin[1] + ymin;
    }
    else if (phase == 3) {
      pointA[0] = bossOrigin[0] + xmax;
      pointA[1] = bossOrigin[1] + ymin;
      pointB[0] = bossOrigin[0] + 0.0;
      pointB[1] = bossOrigin[1] + ymin;
    }
    else if (phase == 4) {
      pointA[0] = bossOrigin[0] + 0.0;
      pointA[1] = bossOrigin[1] + ymin;
      pointB[0] = bossOrigin[0] + xmin;
      pointB[1] = bossOrigin[1] + ymin;
    }
    else if (phase == 5) {
      pointA[0] = bossOrigin[0] + xmin;
      pointA[1] = bossOrigin[1] + ymin;
      pointB[0] = bossOrigin[0] + xmin;
      pointB[1] = bossOrigin[1] + 0.0;
    }
    else if (phase == 6) {
      pointA[0] = bossOrigin[0] + xmin;
      pointA[1] = bossOrigin[1] + 0.0;
      pointB[0] = bossOrigin[0] + xmin;
      pointB[1] = bossOrigin[1] + ymax;
    }
    else if (phase == 7) {
      pointA[0] = bossOrigin[0] + xmin;
      pointA[1] = bossOrigin[1] + ymax;
      pointB[0] = bossOrigin[0] + 0.0;
      pointB[1] = bossOrigin[1] + ymax;
    }

    for (int shouldZ = 0; shouldZ <= 1; shouldZ++)
    {
      pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
      if (!Resize_OneTrace(pointA, pointB))
        return false;
    }
  }

  return true;
}

public bool IsSpotSafe(int clientIdx, float playerPos[3], float sizeMultiplier)
{
  ResizeTraceFailed = false;
  ResizeMyTeam      = GetClientTeam(clientIdx);
  static float mins[3];
  static float maxs[3];
  mins[0] = -24.0 * sizeMultiplier;
  mins[1] = -24.0 * sizeMultiplier;
  mins[2] = 0.0;
  maxs[0] = 24.0 * sizeMultiplier;
  maxs[1] = 24.0 * sizeMultiplier;
  maxs[2] = 82.0 * sizeMultiplier;

  // the eight 45 degree angles and center, which only checks the z offset
  if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

  // 22.5 angles as well, for paranoia sake
  if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
  if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

  // four square tests
  if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
  if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
  if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
  if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;

  return true;
}

/*
  Hitbox scaling
*/
stock void UpdatePlayerHitbox(const int client, float scale)
{
  float vecScaledPlayerMin[3] = { -24.5, -24.5, 0.0 };
  float vecScaledPlayerMax[3] = { 24.5, 24.5, 83.0 };
  ScaleVector(vecScaledPlayerMin, scale);
  ScaleVector(vecScaledPlayerMax, scale);
  SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
  SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}

public void Rage_Hellfire(int clientIdx, const char[] ability, AbilityData cfg)
{
  hellsound         = cfg.GetBool("sound");
  rageDamage        = cfg.GetFloat("damage");
  rageDistance      = cfg.GetFloat("range");
  afterBurnDamage   = cfg.GetFloat("afterburn damage");
  afterBurnDuration = cfg.GetFloat("afterburn duration");

  float vel[3];
  vel[2] = 20.0;
  TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel);
  SetExplodeAtClient(clientIdx, rageDamage, rageDistance, DMG_BURN);

  float pos[3];
  float pos2[3];
  float distancedistance;

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      distancedistance = GetVectorDistance(pos, pos2);
      if (!TF2_IsPlayerInCondition(i, TFCond_Ubercharged) && !TF2_IsPlayerInCondition(i, TFCond_Bonked) && (distancedistance < rageDistance))
      {
        TF2_IgnitePlayer(i, clientIdx);
        ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye2.vmt");  // fire flashes
      }
    }
  }
  if (hellsound)
  {
    EmitSoundToAll("misc/flame_engulf.wav");
    EmitSoundToAll("misc/flame_engulf.wav");
  }

  Handle pack = CreateDataPack();
  gAfterburn  = 0;
  CreateDataTimer(1.0, AfterBurn, pack, TIMER_REPEAT);
  WritePackCell(pack, clientIdx);
  WritePackCell(pack, afterBurnDamage);
  WritePackCell(pack, afterBurnDuration);
  WritePackCell(pack, rageDistance);
  ResetPack(pack);
}

public Action AfterBurn(Handle timer, Handle pack)
{
  ResetPack(pack);
  int   client                = ReadPackCell(pack);
  float packafterBurnDamage   = ReadPackCell(pack);
  float packafterBurnDuration = ReadPackCell(pack);
  float packDistance          = ReadPackCell(pack);

  if (gAfterburn >= packafterBurnDuration)
  {
    gAfterburn = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i) && IsPlayerAlive(i))
        ClientCommand(i, "r_screenoverlay 0");
    }
    return Plugin_Stop;
  }
  SetExplodeAtClient(client, packafterBurnDamage, packDistance, DMG_BURN);
  gAfterburn++;

  return Plugin_Continue;
}

public void SetExplodeAtClient(int client, float damage, float radius, int dmgtype)
{
  if (IsClientInGame(client) && IsPlayerAlive(client))
  {
    float pos[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
      TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
      DispatchKeyValue(particle, "effect_name", "cinefx_goldrush");
      ActivateEntity(particle);
      AcceptEntityInput(particle, "start");

      char strAddOutput[64];
      Format(strAddOutput, sizeof(strAddOutput), "OnUser1 !self:kill::%f:1", 0.5);
      SetVariantString(strAddOutput);
      AcceptEntityInput(particle, "AddOutput");
      AcceptEntityInput(particle, "FireUser1");

      SetDamageRadial(client, damage, pos, radius, dmgtype);
    }
  }
}

public void SetDamageRadial(int attacker, float dmg, float pos[3], float Radiusradius, int dmgtype)
{
  float dist;

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(attacker))
    {
      float pos2[3];
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      dist = GetVectorDistance(pos2, pos);

      pos[2] += 60;
      if (dist <= Radiusradius)
      {
        if (dmgtype & DMG_BURN)
          ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye2.vmt");  // fire flashes
        SDKHooks_TakeDamage(i, attacker, attacker, dmg, dmgtype, GetPlayerWeaponSlot(attacker, 1));
      }
    }
  }
}

public void Rage_IonCannon(int clientIdx, const char[] ability, AbilityData cfg)
{
  distance  = cfg.GetFloat("timer");
  IOCDist   = cfg.GetInt("radius");
  IOCdamage = cfg.GetInt("damage");
  aimmode   = cfg.GetBool("aimmode");

  char buffer[4][4];
  char color[256];
  cfg.GetString("rgba", color, sizeof(color), "0 150 255 255");
  ExplodeString(color, " ", buffer, sizeof(buffer), sizeof(buffer));
  rgba[0]  = StringToInt(buffer[0]);
  rgba[1]  = StringToInt(buffer[1]);
  rgba[2]  = StringToInt(buffer[2]);
  rgba[3]  = StringToInt(buffer[3]);

  distance = distance * 29;

  float vAngles[3];
  float vOrigin[3];
  float vStart[3];

  GetClientEyePosition(clientIdx, vOrigin);
  GetClientEyeAngles(clientIdx, vAngles);

  if (!aimmode)
  {
    Handle data = CreateDataPack();
    WritePackFloat(data, vOrigin[0]);
    WritePackFloat(data, vOrigin[1]);
    WritePackFloat(data, vOrigin[2]);
    WritePackCell(data, distance);   // Distance
    WritePackFloat(data, 0.0);       // nphi
    WritePackCell(data, IOCDist);    // Range
    WritePackCell(data, IOCdamage);  // Damge
    ResetPack(data);
    IonAttack(data);
  }
  else {
    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

    if (TR_DidHit(trace))
    {
      TR_GetEndPosition(vStart, trace);

      CloseHandle(trace);

      Handle data = CreateDataPack();
      WritePackFloat(data, vStart[0]);
      WritePackFloat(data, vStart[1]);
      WritePackFloat(data, vStart[2]);
      WritePackCell(data, distance);   // Distance
      WritePackFloat(data, 0.0);       // nphi
      WritePackCell(data, IOCDist);    // Range
      WritePackCell(data, IOCdamage);  // Damge
      ResetPack(data);

      IonAttack(data);
    }
    else
    {
      CloseHandle(trace);
    }
  }
}

public void DrawIonBeam(float startPosition[3])
{
  float position[3];
  position[0] = startPosition[0];
  position[1] = startPosition[1];
  position[2] = startPosition[2] + 1500.0;

  TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 0.15, 25.0, 25.0, 0, 1.0, rgba, 3);
  TE_SendToAll();
  position[2] -= 1490.0;
  TE_SetupSmoke(startPosition, gSmoke1, 10.0, 2);
  TE_SendToAll();
  TE_SetupGlowSprite(startPosition, gGlow1, 1.0, 1.0, 255);
  TE_SendToAll();
}

public void IonAttack(Handle data)
{
  float startPosition[3];
  float position[3];

  startPosition[0]  = ReadPackFloat(data);
  startPosition[1]  = ReadPackFloat(data);
  startPosition[2]  = ReadPackFloat(data);
  float Iondistance = ReadPackCell(data);
  float nphi        = ReadPackFloat(data);
  int   Ionrange    = ReadPackCell(data);
  int   Iondamage   = ReadPackCell(data);

  if (Iondistance > 0)
  {
    EmitSoundToAll("ambient/energy/weld1.wav", 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, startPosition);

    // Stage 1
    float s     = Sine(nphi / 360 * 6.28) * Iondistance;
    float c     = Cosine(nphi / 360 * 6.28) * Iondistance;

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[2] = startPosition[2];

    position[0] += s;
    position[1] += c;
    DrawIonBeam(position);

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] -= s;
    position[1] -= c;
    DrawIonBeam(position);

    // Stage 2
    s           = Sine((nphi + 45.0) / 360 * 6.28) * Iondistance;
    c           = Cosine((nphi + 45.0) / 360 * 6.28) * Iondistance;

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] += s;
    position[1] += c;
    DrawIonBeam(position);

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] -= s;
    position[1] -= c;
    DrawIonBeam(position);

    // Stage 3
    s           = Sine((nphi + 90.0) / 360 * 6.28) * Iondistance;
    c           = Cosine((nphi + 90.0) / 360 * 6.28) * Iondistance;

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] += s;
    position[1] += c;
    DrawIonBeam(position);

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] -= s;
    position[1] -= c;
    DrawIonBeam(position);

    // Stage 3
    s           = Sine((nphi + 135.0) / 360 * 6.28) * Iondistance;
    c           = Cosine((nphi + 135.0) / 360 * 6.28) * Iondistance;

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] += s;
    position[1] += c;
    DrawIonBeam(position);

    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[0] -= s;
    position[1] -= c;
    DrawIonBeam(position);

    if (nphi >= 360)
      nphi = 0.0;
    else
      nphi += 5.0;
  }
  Iondistance -= 5;

  Handle nData = CreateDataPack();

  WritePackFloat(nData, startPosition[0]);
  WritePackFloat(nData, startPosition[1]);
  WritePackFloat(nData, startPosition[2]);
  WritePackCell(nData, Iondistance);
  WritePackFloat(nData, nphi);
  WritePackCell(nData, Ionrange);
  WritePackCell(nData, Iondamage);
  ResetPack(nData);

  if (Iondistance > -50)
    CreateTimer(0.1, DrawIon, nData, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
  else {
    position[0] = startPosition[0];
    position[1] = startPosition[1];
    position[2] += 1500.0;
    TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 5.0, 30.0, 30.0, 0, 1.0, { 255, 255, 255, 255 }, 3);
    TE_SendToAll();
    TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 4.0, 50.0, 50.0, 0, 1.0, { 200, 255, 255, 255 }, 3);
    TE_SendToAll();
    TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 3.0, 80.0, 80.0, 0, 1.0, { 100, 255, 255, 255 }, 3);
    TE_SendToAll();
    TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 2.0, 100.0, 100.0, 0, 1.0, { 0, 255, 255, 255 }, 3);
    TE_SendToAll();

    TE_SetupSmoke(startPosition, gSmoke1, 350.0, 15);
    TE_SendToAll();
    TE_SetupGlowSprite(startPosition, gGlow1, 3.0, 15.0, 255);
    TE_SendToAll();

    makeexplosion(0, -1, startPosition, "", Iondamage, Ionrange);

    position[2]         = startPosition[2] + 50.0;
    float fDirection[3] = { -90.0, 0.0, 0.0 };
    env_shooter(fDirection, 25.0, 0.1, fDirection, 800.0, 120.0, 120.0, position, "models/props_wasteland/rockgranite03b.mdl");

    env_shake(startPosition, 120.0, 10000.0, 15.0, 250.0);

    TE_SetupExplosion(startPosition, gExplosive1, 10.0, 1, 0, 0, 5000);
    TE_SendToAll();

    TE_SetupBeamRingPoint(position, 0.0, 1500.0, gGlow1, gHalo1, 0, 0, 0.5, 100.0, 5.0, { 150, 255, 255, 255 }, 0, 0);
    TE_SendToAll();
    TE_SetupBeamRingPoint(position, 0.0, 1500.0, gGlow1, gHalo1, 0, 0, 5.0, 100.0, 5.0, { 255, 255, 255, 255 }, 0, 0);
    TE_SendToAll();
    TE_SetupBeamRingPoint(position, 0.0, 1500.0, gGlow1, gHalo1, 0, 0, 2.5, 100.0, 5.0, { 255, 255, 255, 255 }, 0, 0);
    TE_SendToAll();
    TE_SetupBeamRingPoint(position, 0.0, 1500.0, gGlow1, gHalo1, 0, 0, 6.0, 100.0, 5.0, { 255, 255, 255, 255 }, 0, 0);
    TE_SendToAll();

    // Light
    int ent = CreateEntityByName("light_dynamic");

    DispatchKeyValue(ent, "_light", "255 255 255 255");
    DispatchKeyValue(ent, "brightness", "5");
    DispatchKeyValueFloat(ent, "spotlight_radius", 500.0);
    DispatchKeyValueFloat(ent, "distance", 500.0);
    DispatchKeyValue(ent, "style", "6");

    DispatchSpawn(ent);
    AcceptEntityInput(ent, "TurnOn");

    TeleportEntity(ent, position, NULL_VECTOR, NULL_VECTOR);

    CustomRemoveEntity(ent, 3.0);

    // Sound
    EmitSoundToAll("ambient/explosions/citadel_end_explosion1.wav", 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, startPosition);
    EmitSoundToAll("ambient/explosions/citadel_end_explosion2.wav", 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, startPosition);

    // Blend
    sendfademsg(0, 10, 200, FFADE_OUT, 255, 255, 255, 150);

    // Knockback
    float vReturn[3];
    float vClientPosition[3];
    float dist;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
      {
        GetClientEyePosition(i, vClientPosition);

        dist = GetVectorDistance(vClientPosition, position, false);
        if (dist < Ionrange)
        {
          MakeVectorFromPoints(position, vClientPosition, vReturn);
          NormalizeVector(vReturn, vReturn);
          ScaleVector(vReturn, 10000.0 - dist * 10);

          TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vReturn);
        }
      }
    }
  }
}

public Action DrawIon(Handle timer, Handle data)
{
  IonAttack(data);
  return Plugin_Stop;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
  return (entity > MaxClients || !entity);
}

stock bool makeexplosion(int attacker, int inflictor, const float attackposition[3], const char[] weaponname, int magnitude, int radiusoverride)
{
  float damageforce = 0.0;
  int   flags       = 0;
  int   explosion   = CreateEntityByName("env_explosion");

  if (explosion != -1)
  {
    DispatchKeyValueVector(explosion, "Origin", attackposition);

    char intbuffer[64];
    IntToString(magnitude, intbuffer, 64);
    DispatchKeyValue(explosion, "iMagnitude", intbuffer);
    if (radiusoverride > 0)
    {
      IntToString(radiusoverride, intbuffer, 64);
      DispatchKeyValue(explosion, "iRadiusOverride", intbuffer);
    }

    if (damageforce > 0.0)
      DispatchKeyValueFloat(explosion, "DamageForce", damageforce);

    if (flags != 0)
    {
      IntToString(flags, intbuffer, 64);
      DispatchKeyValue(explosion, "spawnflags", intbuffer);
    }

    if (!StrEqual(weaponname, "", false))
      DispatchKeyValue(explosion, "classname", weaponname);

    DispatchSpawn(explosion);
    if (IsClientConnectedIngame(attacker))
      SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", attacker);

    if (inflictor != -1)
      SetEntPropEnt(explosion, Prop_Data, "m_hInflictor", inflictor);

    AcceptEntityInput(explosion, "Explode");
    AcceptEntityInput(explosion, "Kill");

    return true;
  }
  else
    return false;
}

stock void env_shooter(float Angles[3], float iGibs, float Delay, float GibAngles[3], float Velocity, float Variance, float Giblife, float Location[3], char[] ModelType)
{
  // decl Ent;

  // Initialize:
  int Ent = CreateEntityByName("env_shooter");

  // Spawn:
  if (Ent == -1)
    return;

  // if (Ent>0 && IsValidEdict(Ent))

  if (Ent > 0 && IsValidEntity(Ent) && IsValidEdict(Ent))
  {
    // Properties:
    // DispatchKeyValue(Ent, "targetname", "flare");

    // Gib Direction (Pitch Yaw Roll) - The direction the gibs will fly.
    DispatchKeyValueVector(Ent, "angles", Angles);

    // Number of Gibs - Total number of gibs to shoot each time it's activated
    DispatchKeyValueFloat(Ent, "m_iGibs", iGibs);

    // Delay between shots - Delay (in seconds) between shooting each gib. If 0, all gibs shoot at once.
    DispatchKeyValueFloat(Ent, "delay", Delay);

    // <angles> Gib Angles (Pitch Yaw Roll) - The orientation of the spawned gibs.
    DispatchKeyValueVector(Ent, "gibangles", GibAngles);

    // Gib Velocity - Speed of the fired gibs.
    DispatchKeyValueFloat(Ent, "m_flVelocity", Velocity);

    // Course Variance - How much variance in the direction gibs are fired.
    DispatchKeyValueFloat(Ent, "m_flVariance", Variance);

    // Gib Life - Time in seconds for gibs to live +/- 5%.
    DispatchKeyValueFloat(Ent, "m_flGibLife", Giblife);

    // <choices> Used to set a non-standard rendering mode on this entity. See also 'FX Amount' and 'FX Color'.
    DispatchKeyValue(Ent, "rendermode", "5");

    // Model - Thing to shoot out. Can be a .mdl (model) or a .vmt (material/sprite).
    DispatchKeyValue(Ent, "shootmodel", ModelType);

    // <choices> Material Sound
    DispatchKeyValue(Ent, "shootsounds", "-1");  // No sound

    // <choices> Simulate, no idea what it realy does tbh...
    // could find out but to lazy and not worth it...
    // DispatchKeyValue(Ent, "simulation", "1");

    SetVariantString("spawnflags 4");
    AcceptEntityInput(Ent, "AddOutput");

    ActivateEntity(Ent);

    // Input:
    //  Shoot!
    AcceptEntityInput(Ent, "Shoot", 0);

    // Send:
    TeleportEntity(Ent, Location, NULL_VECTOR, NULL_VECTOR);

    // Delete:
    // AcceptEntityInput(Ent, "kill");
    CustomRemoveEntity(Ent, 1.0);
  }
}

stock void env_shake(float Origin[3], float Amplitude, float Radius, float Duration, float Frequency)
{
  // Initialize:
  int Ent = CreateEntityByName("env_shake");

  // Spawn:
  if (DispatchSpawn(Ent))
  {
    // Properties:
    DispatchKeyValueFloat(Ent, "amplitude", Amplitude);
    DispatchKeyValueFloat(Ent, "radius", Radius);
    DispatchKeyValueFloat(Ent, "duration", Duration);
    DispatchKeyValueFloat(Ent, "frequency", Frequency);

    SetVariantString("spawnflags 8");
    AcceptEntityInput(Ent, "AddOutput");

    // Input:
    AcceptEntityInput(Ent, "StartShake", 0);

    // Send:
    TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

    // Delete:
    CustomRemoveEntity(Ent, 30.0);
  }
}

stock void CustomRemoveEntity(int entity, float time)
{
  if (time == 0.0)
  {
    if (IsValidEntity(entity))
    {
      char edictname[32];
      GetEdictClassname(entity, edictname, 32);

      if (StrEqual(edictname, "player"))
        KickClient(entity);  // HaHa =D
      else
        AcceptEntityInput(entity, "kill");
    }
  }
  else {
    CreateTimer(time, RemoveEntityTimer, entity, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action RemoveEntityTimer(Handle timer, int entity)
{
  if (IsValidEntity(entity))
    AcceptEntityInput(entity, "kill");  // RemoveEdict(entity);

  return Plugin_Stop;
}

stock bool IsClientConnectedIngame(int client)
{
  if (client > 0 && client <= MaxClients)
    if (IsClientInGame(client))
      return true;

  return false;
}

stock void sendfademsg(int client, int duration, int holdtime, int fadeflag, int r, int g, int b, int a)
{
  Handle fademsg;

  if (client == 0)
    fademsg = StartMessageAll("Fade");
  else
    fademsg = StartMessageOne("Fade", client);

  BfWriteShort(fademsg, duration);
  BfWriteShort(fademsg, holdtime);
  BfWriteShort(fademsg, fadeflag);
  BfWriteByte(fademsg, r);
  BfWriteByte(fademsg, g);
  BfWriteByte(fademsg, b);
  BfWriteByte(fademsg, a);
  EndMessage();
}

public void Rage_Delirium(int clientIdx, const char[] ability, AbilityData cfg)
{
  DeliriumDistance = cfg.GetFloat("range");  // rage distance

  float pos[3];
  float pos2[3];
  float Delidistance;

  TF2_RemoveCondition(clientIdx, TFCond_Taunting);

  float vel[3];
  vel[2] = 20.0;

  TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vel);
  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
    {
      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      Delidistance = GetVectorDistance(pos, pos2);
      if (Delidistance < DeliriumDistance && GetClientTeam(i) != GetClientTeam(clientIdx))
      {
        SetVariantInt(0);
        AcceptEntityInput(i, "SetForcedTauntCam");
        fxDrug_Create(i);
        SDKHook(i, SDKHook_PreThink, Delirium_Prethink);
      }
    }
  }

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);

  float vec[3];
  GetClientAbsOrigin(clientIdx, vec);
  vec[2] += 10;

  TE_SetupBeamRingPoint(vec, 10.0, DeliriumDistance / 2, gLaser1, gHalo1, 0, 15, 0.5, 10.0, 0.0, { 128, 128, 128, 255 }, 10, 0);
  TE_SendToAll();
  TE_SetupBeamRingPoint(vec, 10.0, DeliriumDistance / 2, gLaser1, gHalo1, 0, 10, 0.6, 20.0, 0.5, { 75, 75, 255, 255 }, 10, 0);
  TE_SendToAll();
  TE_SetupBeamRingPoint(vec, 0.0, DeliriumDistance, gLaser1, gHalo1, 0, 0, 0.5, 100.0, 5.0, { 255, 255, 255, 255 }, 0, 0);
  TE_SendToAll();
  TE_SetupBeamRingPoint(vec, 0.0, DeliriumDistance, gLaser1, gHalo1, 0, 0, 5.0, 100.0, 5.0, { 64, 64, 128, 255 }, 0, 0);
  TE_SendToAll();
  TE_SetupBeamRingPoint(vec, 0.0, DeliriumDistance, gLaser1, gHalo1, 0, 0, 2.5, 100.0, 5.0, { 32, 32, 64, 255 }, 0, 0);
  TE_SendToAll();
  TE_SetupBeamRingPoint(vec, 0.0, DeliriumDistance, gLaser1, gHalo1, 0, 0, 6.0, 100.0, 5.0, { 16, 16, 32, 255 }, 0, 0);
  TE_SendToAll();

  DeliriumDuration = GetEngineTime() + cfg.GetFloat("duration");  // rage duration
}

public void Delirium_Prethink(int client)
{
  DrunkTick(client, GetEngineTime());
}

public void DrunkTick(int client, float gameTime)
{
  if (gameTime >= DeliriumDuration)
  {
    DeliriumDuration = INACTIVE;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsClientInGame(i) && IsPlayerAlive(i))
      {
        fxDrug_Kill(i);
        SDKUnhook(i, SDKHook_PreThink, Delirium_Prethink);
      }
    }
  }
}

public Action EndSickness(Handle timer)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i))
    {
      fxDrug_Kill(i);
      SDKUnhook(i, SDKHook_PreThink, Delirium_Prethink);
    }
  }
  return Plugin_Stop;
}

/*
 * Create colorfull drug on client
 */
stock void fxDrug_Create(int client)
{
  specialDrugTimers[client] = CreateTimer(0.1, fxDrug_Timer, client, TIMER_REPEAT);
}

/*
 * Kill drug on selected client
 */
stock void fxDrug_Kill(int client)
{
  if (IsClientInGame(client) && IsClientConnected(client))
  {
    specialDrugTimers[client] = INVALID_HANDLE;

    float angs[3];
    GetClientEyeAngles(client, angs);

    angs[2] = 0.0;

    TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);

    ClientCommand(client, "r_screenoverlay 0");

    SetEntData(client, fov_offset, 90, 4, true);
    SetEntData(client, zoom_offset, 90, 4, true);
  }
}

/*
 * Kill drug on client after X seconds
 */
public Action fxDrug_KillTimer(Handle timer, int client)
{
  if (client > 0)
    if (IsClientInGame(client) && IsClientConnected(client))
      fxDrug_Kill(client);
  return Plugin_Stop;
}

/*
 * Run drug timer
 */
public Action fxDrug_Timer(Handle timer, int client)
{
  static int Repeat = 0;

  if (!IsClientInGame(client))
  {
    fxDrug_Kill(client);
    return Plugin_Stop;
  }

  if (!IsPlayerAlive(client))
  {
    fxDrug_Kill(client);
    return Plugin_Stop;
  }

  if (specialDrugTimers[client] == INVALID_HANDLE)
  {
    fxDrug_Kill(client);
    return Plugin_Stop;
  }

  SetVariantInt(0);
  AcceptEntityInput(client, "SetForcedTauntCam");

  float angs[3];
  GetClientEyeAngles(client, angs);

  angs[2] = g_DrugAngles[Repeat % 56];
  angs[1] = g_DrugAngles[(Repeat + 14) % 56];
  angs[0] = g_DrugAngles[(Repeat + 21) % 56];

  TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);

  SetEntData(client, fov_offset, 160, 4, true);
  SetEntData(client, zoom_offset, 160, 4, true);

  if (Repeat == 0)
  {
    EmitSoundToClient(client, "ambient/halloween/mysterious_perc_01.wav");
  }
  else if ((Repeat % 15) == 0) {
    EmitSoundToClient(client, "ambient/halloween/mysterious_perc_01.wav");
  }

  ClientCommand(client, "r_screenoverlay effects/tp_eyefx/tpeye.vmt");  // rainbow flashes

  Repeat++;

  int clients[2];
  clients[0] = client;

  sendfademsg(client, 255, 255, FFADE_OUT, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 150);

  return Plugin_Handled;
}

public void CaberReset(int client)
{
  int stickbomb = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
  if (stickbomb <= MaxClients || !IsValidEdict(stickbomb))
    return;
  SetEntProp(stickbomb, Prop_Send, "m_iDetonated", 0);
  SetEntProp(stickbomb, Prop_Send, "m_bBroken", 0);
}

public Action ResetCaber(Handle timer)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i))
      SDKUnhook(i, SDKHook_PreThink, CaberReset);
  }
  return Plugin_Stop;
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