/*
  "roboticize"
  {
    "mode" "0"    // Mode (0 = Normal, 1 = Giant)

    "plugin_name"    "ff2r_s93_abilities"
  }

  "rage_taunt_slide"
  {
    "plugin_name"    "ff2r_s93_abilities"
  }
  "effect_classreaction"
  {
    "plugin_name"    "ff2r_s93_abilities"
  }

  "rage_thriller_taunt"
  {
  "amount"            "0"    // # of dances
  "uber"            "0"    // Affect ubered players? (1=yes, 0=no)
  "range"            "600"    // Range (if 0, will use ragedist value instead)

  "plugin_name"    "ff2r_s93_abilities"
  }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <adt_array>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

enum VoiceMode
{
  VoiceMode_None = -1,
  VoiceMode_Normal,
  VoiceMode_Robot,
  VoiceMode_GiantRobot,
}

VoiceMode         VOMode[MAXPLAYERS + 1];

static const char ScoutReact[][] = {
  "vo/scout_sf13_magic_reac03.mp3",
  "vo/scout_sf13_magic_reac07.mp3",
  "vo/scout_sf12_badmagic04.mp3"
};

static const char SoldierReact[][] = {
  "vo/soldier_sf13_magic_reac03.mp3",
  "vo/soldier_sf12_badmagic07.mp3",
  "vo/soldier_sf12_badmagic13.mp3"
};

static const char PyroReact[][] = {
  "vo/pyro_autodejectedtie01.mp3",
  "vo/pyro_painsevere02.mp3",
  "vo/pyro_painsevere04.mp3"
};

static const char DemoReact[][] = {
  "vo/demoman_sf13_magic_reac05.mp3",
  "vo/demoman_sf13_bosses02.mp3",
  "vo/demoman_sf13_bosses03.mp3",
  "vo/demoman_sf13_bosses04.mp3",
  "vo/demoman_sf13_bosses05.mp3",
  "vo/demoman_sf13_bosses06.mp3"
};

static const char HeavyReact[][] = {
  "vo/heavy_sf13_magic_reac01.mp3",
  "vo/heavy_sf13_magic_reac03.mp3",
  "vo/heavy_cartgoingbackoffense02.mp3",
  "vo/heavy_negativevocalization02.mp3",
  "vo/heavy_negativevocalization06.mp3"
};

static const char EngyReact[][] = {
  "vo/engineer_sf13_magic_reac01.mp3",
  "vo/engineer_sf13_magic_reac02.mp3",
  "vo/engineer_specialcompleted04.mp3",
  "vo/engineer_painsevere05.mp3",
  "vo/engineer_negativevocalization12.mp3"
};

static const char MedicReact[][] = {
  "vo/medic_sf13_magic_reac01.mp3",
  "vo/medic_sf13_magic_reac02.mp3",
  "vo/medic_sf13_magic_reac03.mp3",
  "vo/medic_sf13_magic_reac04.mp3",
  "vo/medic_sf13_magic_reac07.mp3"
};

static const char SniperReact[][] = {
  "vo/sniper_sf13_magic_reac01.mp3",
  "vo/sniper_sf13_magic_reac02.mp3",
  "vo/sniper_sf13_magic_reac04.mp3"
};

static const char SpyReact[][] = {
  "vo/Spy_sf13_magic_reac01.mp3",
  "vo/Spy_sf13_magic_reac02.mp3",
  "vo/Spy_sf13_magic_reac03.mp3",
  "vo/Spy_sf13_magic_reac04.mp3",
  "vo/Spy_sf13_magic_reac05.mp3",
  "vo/Spy_sf13_magic_reac06.mp3"
};

static const char giant_step[][] = {
  "mvm/giant_common/giant_common_step_01.wav",
  "mvm/giant_common/giant_common_step_02.wav",
  "mvm/giant_common/giant_common_step_03.wav",
  "mvm/giant_common/giant_common_step_04.wav",
  "mvm/giant_common/giant_common_step_05.wav",
  "mvm/giant_common/giant_common_step_06.wav",
  "mvm/giant_common/giant_common_step_07.wav",
  "mvm/giant_common/giant_common_step_08.wav"
};

static const char robot_step[][] = {
  "mvm/player/footsteps/robostep_01.wav",
  "mvm/player/footsteps/robostep_02.wav",
  "mvm/player/footsteps/robostep_03.wav",
  "mvm/player/footsteps/robostep_04.wav",
  "mvm/player/footsteps/robostep_05.wav",
  "mvm/player/footsteps/robostep_06.wav",
  "mvm/player/footsteps/robostep_07.wav",
  "mvm/player/footsteps/robostep_08.wav",
  "mvm/player/footsteps/robostep_09.wav",
  "mvm/player/footsteps/robostep_10.wav",
  "mvm/player/footsteps/robostep_11.wav",
  "mvm/player/footsteps/robostep_12.wav",
  "mvm/player/footsteps/robostep_13.wav",
  "mvm/player/footsteps/robostep_14.wav",
  "mvm/player/footsteps/robostep_15.wav",
  "mvm/player/footsteps/robostep_16.wav",
  "mvm/player/footsteps/robostep_17.wav",
  "mvm/player/footsteps/robostep_18.wav"
};

public Plugin myinfo =
{
  name        = "Freak Fortress 2 Rewrite: Koishi's Abilities Pack",
  author      = "Koishi (SHADoW NiNE TR3S) and Zell",
  description = "Koishi's Abilities Pack (roboticize, taunt slide, class react, thriller)",
  version     = "1.23.0",
};

public void OnPluginStart()
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (IsClientInGame(client))
    {
      OnClientPutInServer(client);

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

public void OnClientPutInServer(int client)
{
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData robot = cfg.GetAbility("roboticize");
    if (robot.IsMyPlugin())
    {
      // Notification Sounds
      AddNormalSoundHook(SoundHook);

      VOMode[client] = VoiceMode_Normal;

      char sound[256];

      for (int i = 0; i < 8; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, giant_step[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 18; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, robot_step[i]);
        PrecacheSound(sound, true);
      }

      int botmode = robot.GetInt("mode");

      if (botmode)
        VOMode[client] = VoiceMode_GiantRobot;
      else
        VOMode[client] = VoiceMode_Robot;
    }

    AbilityData reaction = cfg.GetAbility("effect_classreaction");
    if (reaction.IsMyPlugin())
    {
      // Class Voice Reaction Lines
      char sound[256];
      for (int i = 0; i < 3; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, ScoutReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 3; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, SoldierReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 3; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, PyroReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 6; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, DemoReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 5; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, HeavyReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 5; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, EngyReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 5; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, MedicReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 3; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, SniperReact[i]);
        PrecacheSound(sound, true);
      }
      for (int i = 0; i < 6; i++)
      {
        strcopy(sound, PLATFORM_MAX_PATH, SpyReact[i]);
        PrecacheSound(sound, true);
      }
    }
  }
}

public Action TauntSliding(Handle timer, int client)
{
  if (!GetEntProp(client, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hHighFivePartner")))
  {
    TF2_RemoveCondition(client, TFCond_Taunting);
    float up[3];
    up[2] = 220.0;
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, up);
  }
  else if (TF2_IsPlayerInCondition(client, TFCond_Taunting)) {
    TF2_RemoveCondition(client, TFCond_Taunting);
  }
  return Plugin_Continue;
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 *
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx)
{
  VOMode[clientIdx] = VoiceMode_Normal;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_taunt_slide", false) && cfg.IsMyPlugin())
    CreateTimer(0.1, TauntSliding);

  if (!StrContains(ability, "effect_classreaction", false) && cfg.IsMyPlugin())
  {
    for (int target = 1; target <= MaxClients; target++)
    {
      if (target != client)
        ClassResponses(target, client);
    }
  }

  if (!StrContains(ability, "rage_thriller_taunt", false) && cfg.IsMyPlugin())
  {
    float pos[3], pos2[3], dist;
    int   maxdances = cfg.GetInt("amount");
    int   mode      = cfg.GetInt("uber");
    float maxdist   = cfg.GetFloat("range");

    for (int target = 1; target <= MaxClients; target++)
    {
      if (IsValidClient(target, true) && GetClientTeam(target) != GetClientTeam(client))
      {
        GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
        dist = GetVectorDistance(pos, pos2);
        if (dist < maxdist && GetClientTeam(target) != GetClientTeam(client))
        {
          if (!(GetEntityFlags(target) & FL_ONGROUND)) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_UberBulletResist) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_BulletImmune) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_UberBlastResist) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_BlastImmune) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_UberFireResist) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_FireImmune) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) && !mode) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_Stealthed)) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_StealthedUserBuffFade)) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_Cloaked)) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_DeadRingered)) continue;
          if (TF2_IsPlayerInCondition(target, TFCond_UberchargedCanteen)) continue;

          if (TF2_IsPlayerInCondition(target, TFCond_Taunting))
            TF2_RemoveCondition(target, TFCond_Taunting);
          if (TF2_IsPlayerInCondition(target, TFCond_HalloweenThriller))
            TF2_RemoveCondition(target, TFCond_HalloweenThriller);

          SetVariantInt(0);
          AcceptEntityInput(target, "SetForcedTauntCam");
          TF2_AddCondition(target, TFCond_HalloweenThriller, 3.0);
          FakeClientCommand(target, "taunt");
        }
      }
    }
    if (maxdances > 0)
    {
      Handle pack = CreateDataPack();
      CreateDataTimer(3.0, ThrillerTaunt, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
      WritePackCell(pack, client);
      WritePackCell(pack, maxdances);
      WritePackCell(pack, mode);
      WritePackCell(pack, maxdist);
      ResetPack(pack);
    }
  }
}

public Action ThrillerTaunt(Handle timer, Handle pack)
{
  ResetPack(pack);
  float      pos[3], pos2[3], dist;
  static int dances    = 0;
  static int targets   = 0;
  int        client    = ReadPackCell(pack);
  int        maxdances = ReadPackCell(pack);
  int        mode      = ReadPackCell(pack);
  float      maxdist   = ReadPackCell(pack);

  if (dances >= maxdances - 1 || !IsValidClient(client, true))
  {
    targets = 0;
    dances  = 0;
    return Plugin_Stop;
  }

  GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
  for (int target = 1; target <= MaxClients; target++)
  {
    if (IsValidClient(target, true) && GetClientTeam(target) != GetClientTeam(client))
    {
      GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
      dist = GetVectorDistance(pos, pos2);
      if (dist < maxdist && GetClientTeam(target) != GetClientTeam(client))
      {
        if (!(GetEntityFlags(target) & FL_ONGROUND)) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_UberBulletResist) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_BulletImmune) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_UberBlastResist) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_BlastImmune) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_UberFireResist) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_FireImmune) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) && !mode) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_Stealthed)) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_StealthedUserBuffFade)) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_Cloaked)) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_DeadRingered)) continue;
        if (TF2_IsPlayerInCondition(target, TFCond_UberchargedCanteen)) continue;

        if (TF2_IsPlayerInCondition(target, TFCond_Taunting))
        {
          TF2_RemoveCondition(target, TFCond_Taunting);
        }
        if (TF2_IsPlayerInCondition(target, TFCond_HalloweenThriller))
        {
          TF2_RemoveCondition(target, TFCond_HalloweenThriller);
        }

        SetVariantInt(0);
        AcceptEntityInput(target, "SetForcedTauntCam");
        TF2_AddCondition(target, TFCond_HalloweenThriller, 3.0);
        FakeClientCommand(target, "taunt");
        targets++;
      }
    }
  }

  if (targets)
  {
    dances++;
  }
  return Plugin_Continue;
}

stock void ClassResponses(int client, int boss)  // Simple Class responses
{
  if (IsValidClient(client, true) && GetClientTeam(client) != GetClientTeam(boss))
  {
    char Reaction[PLATFORM_MAX_PATH];
    switch (TF2_GetPlayerClass(client))
    {
      case TFClass_Scout:  // Scout
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, ScoutReact[GetRandomInt(0, sizeof(ScoutReact) - 1)]);
      }
      case TFClass_Soldier:  // Soldier
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, SoldierReact[GetRandomInt(0, sizeof(SoldierReact) - 1)]);
      }
      case TFClass_Pyro:  // Pyro
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, PyroReact[GetRandomInt(0, sizeof(PyroReact) - 1)]);
      }
      case TFClass_DemoMan:  // DemoMan
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, DemoReact[GetRandomInt(0, sizeof(DemoReact) - 1)]);
      }
      case TFClass_Heavy:  // Heavy
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, HeavyReact[GetRandomInt(0, sizeof(HeavyReact) - 1)]);
      }
      case TFClass_Engineer:  // Engineer
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, EngyReact[GetRandomInt(0, sizeof(EngyReact) - 1)]);
      }
      case TFClass_Medic:  // Medic
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, MedicReact[GetRandomInt(0, sizeof(MedicReact) - 1)]);
      }
      case TFClass_Sniper:  // Sniper
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, SniperReact[GetRandomInt(0, sizeof(SniperReact) - 1)]);
      }
      case TFClass_Spy:  // Spy
      {
        strcopy(Reaction, PLATFORM_MAX_PATH, SpyReact[GetRandomInt(0, sizeof(SpyReact) - 1)]);
      }
    }
    EmitSoundToAll(Reaction, client);
  }
}

public Action SoundHook(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
  if (!IsValidClient(entity, false) || channel < 1)
    return Plugin_Continue;

  BossData boss = FF2R_GetBossData(entity);
  if (!boss)
    return Plugin_Continue;

  switch (VOMode[entity])
  {
    case VoiceMode_None:  // NO Voicelines!
    {
      if (channel == SNDCHAN_VOICE)
      {
        return Plugin_Stop;
      }
    }
    case VoiceMode_Robot:  // Robot VO
    {
      if (!TF2_IsPlayerInCondition(entity, TFCond_Disguised))  // Robot voice lines & footsteps
      {
        if (StrContains(sample, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(entity) != TFClass_Medic)
        {
          int rand = GetRandomInt(1, 18);
          Format(sample, sizeof(sample), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
          pitch = GetRandomInt(95, 100);
          EmitSoundToAll(sample, entity, _, _, _, 0.25, pitch);
        }

        if (channel == SNDCHAN_VOICE)
        {
          if (volume == 0.99997) return Plugin_Continue;
          ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/norm/", false);
          ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false);
          char classname[10];
          char classname_mvm[15];
          TF2_GetNameOfClass(TF2_GetPlayerClass(entity), classname, sizeof(classname));
          Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
          ReplaceString(sample, sizeof(sample), classname, classname_mvm, false);
          char nSnd[PLATFORM_MAX_PATH];
          Format(nSnd, sizeof(nSnd), "sound/%s", sample);
          PrecacheSound(sample);
        }
        return Plugin_Changed;
      }
    }
    case VoiceMode_GiantRobot:  // Giant Robot VO
    {
      if (!TF2_IsPlayerInCondition(entity, TFCond_Disguised))  // Giant robot voice lines & footsteps
      {
        if (StrContains(sample, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(entity) != TFClass_Medic)
        {
          Format(sample, sizeof(sample), "mvm/giant_common/giant_common_step_0%i.wav", GetRandomInt(1, 8));
          pitch = GetRandomInt(95, 100);
          EmitSoundToAll(sample, entity, _, _, _, 0.25, pitch);
        }

        if (channel == SNDCHAN_VOICE)
        {
          if (volume == 0.99997) return Plugin_Continue;
          ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/mght/", false);
          char classname[10];
          char classname_mvm_m[20];
          classname = TF2_GetNameOfClass(TF2_GetPlayerClass(entity), classname, sizeof(classname));
          Format(classname_mvm_m, sizeof(classname_mvm_m), "%s_mvm_m", classname);
          ReplaceString(sample, sizeof(sample), classname, classname_mvm_m, false);
          char gSnd[PLATFORM_MAX_PATH];
          Format(gSnd, sizeof(gSnd), "sound/%s", sample);
          PrecacheSound(sample);
        }
        return Plugin_Changed;
      }
    }
  }
  return Plugin_Continue;
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

stock char[] TF2_GetNameOfClass(TFClassType class, char name[10], int maxlen)
{
  switch (class)
  {
    case TFClass_Scout: Format(name, maxlen, "scout");
    case TFClass_Soldier: Format(name, maxlen, "soldier");
    case TFClass_Pyro: Format(name, maxlen, "pyro");
    case TFClass_DemoMan: Format(name, maxlen, "demoman");
    case TFClass_Heavy: Format(name, maxlen, "heavy");
    case TFClass_Engineer: Format(name, maxlen, "engineer");
    case TFClass_Medic: Format(name, maxlen, "medic");
    case TFClass_Sniper: Format(name, maxlen, "sniper");
    case TFClass_Spy: Format(name, maxlen, "spy");
  }
  return name;
}