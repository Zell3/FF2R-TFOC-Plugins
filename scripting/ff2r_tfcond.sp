/*
  "rage_tfcondition"	// Ability name can use suffixes
  {
    "slot"			"0"						// Ability slot
    "selfconds"		"5 ; 5.8"				// Self conditions
    "allyconds"		"5 ; 2.7"				// Ally conditions
    "allyrange"		"1024.0"				// Ally range
    "enemyconds"	"27 ; 7.7 ; 24 ; 7.7"	// Enemy conditions
    "enemyrange"	"1337.0"				// Enemy range

    "plugin_name"	"ff2r_tfcond"
  }

  "tweak_tfcondition"	// Ability name can't use suffixes, no multiple instances
  {
    "selfconds"							"11 ; -1.0"				// Self conditions

    "allyconds"							"5 ; 20.0"				// Ally conditions
    "remove allyconds on boss death"	"true"					// Remove allyconds on boss death
    "apply allyconds upon respawn"		"true"					// Apply allyconds to allied players when they are respawn
                                  // (Only unlimited duration conditions re-apply & conditions don't re-apply if boss is dead)

    "enemyconds"						"27 ; 7.7 ; 24 ; -1.0"	// Enemy conditions
    "remove enemyconds on boss death"	"true"					// Remove enemyconds on boss death
    "apply enemyconds upon respawn"		"true"					// Apply enemyconds to enemy players when they are respawn
                                  // (Only unlimited duration conditions re-apply & conditions don't re-apply if boss is dead)
    "plugin_name"						"ff2r_tfcond"
  }

    "special_tfcondition"
  {
    "slot"				"0"				// Ability slot
    "selfconds"         "28 ; 32"       // Conditions boss receives upon activation
    "allyconds"			"5 ; 2.7"				// Ally conditions
    "allyrange"			"1024.0"				// Ally range
    "enemyconds"		"27 ; 7.7 ; 24 ; 7.7"	// Enemy conditions
    "enemyrange"		"1337.0"				// Enemy range
    "ragemin"	        "20.0"          // Minimum required RAGE to use
    "ragedrain"         "0.04"          // RAGE Drain RATE per tick
    "buttonmode"	    "1"             // Buttonmode (0=Alt-fire, 1=RELOAD, 2=SPECIAL)
    "cooldown"			"3"				// Start count after stop using ability

    // HUD - NORAGE : Rage is not enough
    "POSnorage"			"-1.0 ; 0.88"				// Position of text
    "TEXTnorage"		"Insufficient RAGE! You need a minimum of %i percent RAGE to use!"				// Text
    "RGBAnorage"		"255 ; 64 ; 64 ; 255"		// Colour of text

    // HUD - READY : Rage is enough
    "POSready"			"-1.0 ; 0.88"					// Position of text
    "TEXTready"			"Hold R to use the Condition Powerup"				// Text
    "RGBAready"			"255 ; 64 ; 64 ; 255"			// Colour of text

    "plugin_name"	"ff2r_tfcond"
  }

  "charge_tfcondition"
  {
    "arg0"				"1"						// Charge slot can be 1 or 2
    "arg1"			"1.5"					// Time to fully charge
    "arg2"			"5.0"					// Cooldown after use
    "arg3"			"25.0"					// RAGE Cost to use

    "selfconds"			"28 ; 10 ; 66 ; 7"		// Boss Conditions (TFCond ; Duration)
    "allyconds"			"5 ; 2.7"				// Ally conditions
    "allyrange"			"1024.0"				// Ally range
    "enemyconds"		"27 ; 7.7 ; 24 ; 7.7"	// Enemy conditions
    "enemyrange"		"1337.0"				// Enemy range

    "Position"			"-1.0 ; 0.88"			// HUD text Position
    "TEXTcharge"		"TFConditions is %i percent ready. When at 100 percent look up and stand up."	// HUD Strings - charge status
    "RGBAcharge"		"255 ; 255 ; 255 ; 255"

    "TEXTcooldown"		"TFConditions will be avaliable in %i second(s)."	// HUD Strings - cooldown status
    "RGBAcooldown"		"255 ; 64 ; 64 ; 255"

    "TEXTready"			"Crouch or Press Alt-fire to use TFConds!"			// HUD Strings - Charge uses RAGE
    "RGBAready"			"64 ; 255 ; 64 ; 255"

    "TEXTDuper"			"Super Duper jump is ready!"						// HUD Strings -  Super-duper jump
    "RGBADuper"			"255 ; 64 ; 64 ; 255"

    "buttonmode"		"1"		// 1 for alt-fire/duck , 2 for reload

    "plugin_name"	"ff2r_tfcond"
  }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: TFCond"
#define PLUGIN_AUTHOR   "J0BL3SS, Zell"
#define PLUGIN_DESC     "Subplugin for applying conditions to players"

#define MAJOR_REVISION  "1"
#define MINOR_REVISION  "1"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION  MAJOR_REVISION... "." ... MINOR_REVISION... "." ... STABLE_REVISION

#define PLUGIN_URL      ""

#define MAXTF2PLAYERS   MAXPLAYERS + 1
// tweak
char   TWEAK_AllyConditions[MAXTF2PLAYERS][512];
char   TWEAK_EnemyConditions[MAXTF2PLAYERS][512];

// special - dot
char   SpecialTFCondTweakConditions[MAXTF2PLAYERS][512];
int    buttonmode[MAXTF2PLAYERS];
float  dotCost[MAXTF2PLAYERS];
float  minCost[MAXTF2PLAYERS];
float  curRage[MAXTF2PLAYERS];

char   HudNoRageStrings[MAXTF2PLAYERS][768];
int    HudNoRageColor[MAXTF2PLAYERS][4];
float  HudNoRageCordinate[MAXTF2PLAYERS][2];

char   HudRageStrings[MAXTF2PLAYERS][768];
int    HudRageColor[MAXTF2PLAYERS][4];
float  HudRageCordinate[MAXTF2PLAYERS][2];

// charge
float  HudChargeCordinate[MAXTF2PLAYERS][2];
bool   bEnableSuperDuperJump[MAXPLAYERS + 1];
int    HudChargeColor[MAXTF2PLAYERS][4];
int    HudChargeCooldownColor[MAXTF2PLAYERS][4];
int    HudChargeReadyColor[MAXTF2PLAYERS][4];
int    HudChargeDuperColor[MAXTF2PLAYERS][4];

Handle ChargeHud;
Handle DotHud;

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTHOR,
  description = PLUGIN_DESC,
  version     = PLUGIN_VERSION,
  url         = PLUGIN_URL,
};

public void OnPluginStart2()
{
  ChargeHud = CreateHudSynchronizer();
  DotHud    = CreateHudSynchronizer();
  HookEvent("post_inventory_application", Event_PlayerInventoryApplication);
  HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);

  HookEvent("arena_win_panel", Event_RoundEnd);
  HookEvent("teamplay_round_win", Event_RoundEnd);  // for non-arena maps

  for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
  {
    if (IsClientInGame(clientIdx))
    {
      BossData cfg = FF2R_GetBossData(clientIdx);
      if (cfg)
        FF2R_OnBossCreated(clientIdx, cfg, false);
    }
  }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  for (int client = 1; client <= MaxClients; client++)
  {
    if (!IsValidClient(client))
      continue;

    if (FF2R_GetBossData(client))
    {
      FF2R_OnBossRemoved(client);
    }
  }
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int clientIdx = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(clientIdx))
    return;

  FF2R_OnBossRemoved(clientIdx);
}

public void Event_PlayerInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
  int victim = GetEventInt(event, "userid");
  if (IsValidClient(victim))
  {
    for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
    {
      if (IsValidClient(clientIdx) && IsPlayerAlive(clientIdx) && clientIdx != victim)
      {
        BossData cfg = FF2R_GetBossData(clientIdx);
        if (cfg)
        {
          AbilityData ability = cfg.GetAbility("tweak_tfcondition");
          if (ability.IsMyPlugin())  // Incase of duplicated ability names
          {
            if (!ability.GetBool("enabled"))
              return;

            if (GetClientTeam(victim) == GetClientTeam(clientIdx))
            {
              if (ability.GetBool("apply allyconds upon respawn"))
              {
                AddOnlyUnlimitedCondition(victim, TWEAK_AllyConditions[clientIdx]);
              }
            }
            else
            {
              if (ability.GetBool("apply enemyconds upon respawn"))
              {
                AddOnlyUnlimitedCondition(victim, TWEAK_EnemyConditions[clientIdx]);
              }
            }
          }
        }
      }
    }
  }
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
  if (!setup || FF2R_GetGamemodeType() != 2)
  {
    AbilityData tweak = cfg.GetAbility("tweak_tfcondition");
    if (tweak.IsMyPlugin())  // Incase of duplicated ability names
    {
      char buffer[256];
      if (tweak.GetString("selfconds", buffer, sizeof(buffer)))
      {
        RemoveCondition(clientIdx, buffer);
        AddCondition(clientIdx, buffer);
      }

      for (int victim = 1; victim <= MaxClients; victim++)
      {
        if (IsValidClient(victim) && IsPlayerAlive(victim) && victim != clientIdx)
        {
          if (GetClientTeam(victim) == GetClientTeam(clientIdx))
          {
            if (tweak.GetString("allyconds", buffer, sizeof(buffer)))
            {
              strcopy(TWEAK_AllyConditions[clientIdx], sizeof(TWEAK_AllyConditions[]), buffer);
              RemoveCondition(victim, buffer);
              AddCondition(victim, buffer);
            }
          }
          else
          {
            if (tweak.GetString("enemyconds", buffer, sizeof(buffer)))
            {
              strcopy(TWEAK_EnemyConditions[clientIdx], sizeof(TWEAK_EnemyConditions[]), buffer);
              RemoveCondition(victim, buffer);
              AddCondition(victim, buffer);
            }
          }
        }
      }
    }

    AbilityData special = cfg.GetAbility("special_tfcondition");
    if (special.IsMyPlugin())  // Incase of duplicated ability names
    {
      char biffer[256];
      if (special.GetString("selfconds", biffer, sizeof(biffer)))
        special.GetString("selfconds", SpecialTFCondTweakConditions[clientIdx], sizeof(SpecialTFCondTweakConditions[]));

      minCost[clientIdx]    = special.GetFloat("ragemin", 0.0);
      dotCost[clientIdx]    = special.GetFloat("ragedrain", 0.0);
      buttonmode[clientIdx] = special.GetInt("buttonmode", 0);

      char Position[1024];
      char Color[1024];

      special.GetString("TEXTnorage", HudNoRageStrings[clientIdx], 768, "Insufficient RAGE! You need a minimum of %i percent RAGE to use!");
      special.GetString("POSnorage", Position, 1024, "-1.0 ; 0.77");
      special.GetString("RGBAnorage", Color, 1024, "255 ; 64 ; 64 ; 255");

      char buffer[32][32];
      ExplodeString(Position, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudNoRageCordinate[clientIdx][0] = StringToFloat(buffer[0]);
      HudNoRageCordinate[clientIdx][1] = StringToFloat(buffer[1]);

      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudNoRageColor[clientIdx][0] = StringToInt(buffer[0]);
      HudNoRageColor[clientIdx][1] = StringToInt(buffer[1]);
      HudNoRageColor[clientIdx][2] = StringToInt(buffer[2]);
      HudNoRageColor[clientIdx][3] = StringToInt(buffer[3]);

      special.GetString("TEXTready", HudRageStrings[clientIdx], 768);
      special.GetString("POSready", Position, 1024, "-1.0 ; 0.77");
      special.GetString("RGBAready", Color, 1024, "65 ; 255 ; 64 ; 255");

      ExplodeString(Position, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudRageCordinate[clientIdx][0] = StringToFloat(buffer[0]);
      HudRageCordinate[clientIdx][1] = StringToFloat(buffer[1]);

      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudRageColor[clientIdx][0] = StringToInt(buffer[0]);
      HudRageColor[clientIdx][1] = StringToInt(buffer[1]);
      HudRageColor[clientIdx][2] = StringToInt(buffer[2]);
      HudRageColor[clientIdx][3] = StringToInt(buffer[3]);

      SDKHook(clientIdx, SDKHook_PreThink, PersistentTFCondition_PreThink);
    }

    AbilityData charge = cfg.GetAbility("charge_tfcondition");
    if (charge.IsMyPlugin())  // Incase of duplicated ability names
    {
      bEnableSuperDuperJump[clientIdx] = false;

      char Position[1024];
      char Color[1024];

      charge.GetString("Position", Position, 1024, "-1.0 ; 0.77");

      char buffer[32][32];
      ExplodeString(Position, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudChargeCordinate[clientIdx][0] = StringToFloat(buffer[0]);
      HudChargeCordinate[clientIdx][1] = StringToFloat(buffer[1]);

      charge.GetString("RGBAcharge", Color, 1024, "255 ; 255 ; 255 ; 255");
      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudChargeColor[clientIdx][0] = StringToInt(buffer[0]);
      HudChargeColor[clientIdx][1] = StringToInt(buffer[1]);
      HudChargeColor[clientIdx][2] = StringToInt(buffer[2]);
      HudChargeColor[clientIdx][3] = StringToInt(buffer[3]);

      charge.GetString("RGBAcooldown", Color, 1024, "255 ; 64 ; 64 ; 255");
      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudChargeCooldownColor[clientIdx][0] = StringToInt(buffer[0]);
      HudChargeCooldownColor[clientIdx][1] = StringToInt(buffer[1]);
      HudChargeCooldownColor[clientIdx][2] = StringToInt(buffer[2]);
      HudChargeCooldownColor[clientIdx][3] = StringToInt(buffer[3]);

      charge.GetString("RGBAready", Color, 1024, "64 ; 255 ; 64 ; 255");
      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudChargeReadyColor[clientIdx][0] = StringToInt(buffer[0]);
      HudChargeReadyColor[clientIdx][1] = StringToInt(buffer[1]);
      HudChargeReadyColor[clientIdx][2] = StringToInt(buffer[2]);
      HudChargeReadyColor[clientIdx][3] = StringToInt(buffer[3]);

      charge.GetString("RGBADuper", Color, 1024, "255 ; 64 ; 64 ; 255");
      ExplodeString(Color, " ; ", buffer, sizeof(buffer), sizeof(buffer));
      HudChargeDuperColor[clientIdx][0] = StringToInt(buffer[0]);
      HudChargeDuperColor[clientIdx][1] = StringToInt(buffer[1]);
      HudChargeDuperColor[clientIdx][2] = StringToInt(buffer[2]);
      HudChargeDuperColor[clientIdx][3] = StringToInt(buffer[3]);
    }
  }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
  BossData    cfg   = FF2R_GetBossData(clientIdx);
  AbilityData tweak = cfg.GetAbility("tweak_tfcondition");
  if (tweak.IsMyPlugin())  // Incase of duplicated ability names
  {
    for (int victim = 1; victim <= MaxClients; victim++)
    {
      if (IsValidClient(victim) && IsPlayerAlive(victim) && victim != clientIdx)
      {
        if (GetClientTeam(victim) == GetClientTeam(clientIdx))
        {
          if (tweak.GetBool("remove allyconds on boss death", true))
          {
            RemoveCondition(victim, TWEAK_AllyConditions[clientIdx]);
          }
        }
        else
        {
          if (tweak.GetBool("remove enemyconds on boss death", true))
          {
            RemoveCondition(victim, TWEAK_AllyConditions[clientIdx]);
          }
        }
      }
    }
  }

  AbilityData special = cfg.GetAbility("special_tfcondition");
  if (special.IsMyPlugin())  // Incase of duplicated ability names
  {
    SDKUnhook(clientIdx, SDKHook_PreThink, PersistentTFCondition_PreThink);
  }
  bEnableSuperDuperJump[clientIdx] = false;
}

public void PersistentTFCondition_PreThink(int client)
{
  if (!IsPlayerAlive(client) || !IsValidClient(client, false))  // Round ended or boss was defeated?
    return;

  BossData boss = FF2R_GetBossData(client);
  if (!boss)
    return;

  AbilityData special = boss.GetAbility("special_tfcondition");
  if (!special.IsMyPlugin())
    return;

  curRage[client] = GetBossCharge(boss, "0");
  if (curRage[client] <= minCost[client] - 1.0 && !IsPlayerInSpecificConditions(client, SpecialTFCondTweakConditions[client]) || curRage[client] <= 0.44)
  {
    SetHudTextParams(HudNoRageCordinate[client][0],
                     HudNoRageCordinate[client][1],
                     0.2,
                     HudNoRageColor[client][0],
                     HudNoRageColor[client][1],
                     HudNoRageColor[client][2],
                     HudNoRageColor[client][3]);
    ShowSyncHudText(client, DotHud, HudNoRageStrings[client], RoundFloat(minCost[client]));
    return;
  }
  else
  {
    SetHudTextParams(HudRageCordinate[client][0],
                     HudRageCordinate[client][1],
                     0.2,
                     HudRageColor[client][0],
                     HudRageColor[client][1],
                     HudRageColor[client][2],
                     HudRageColor[client][3]);
    ShowSyncHudText(client, DotHud, HudRageStrings[client]);
    if (!buttonmode[client] && (GetClientButtons(client) & IN_ATTACK2) || buttonmode[client] == 1 && (GetClientButtons(client) & IN_RELOAD) || buttonmode[client] == 2 && (GetClientButtons(client) & IN_ATTACK3))
    {
      SetBossCharge(boss, "0", curRage[client] - dotCost[client]);
      SetPersistentCondition(client, SpecialTFCondTweakConditions[client]);
    }
    return;
  }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
  if (!StrContains(ability, "rage_tfcondition", false) && cfg.IsMyPlugin())
  {
    Rage_TFCond(clientIdx, ability, cfg);
  }
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
  if (!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
    return Plugin_Continue;  // Because some FF2 forks still allow RAGE to be activated when the round is over....

  int         client = GetClientOfUserId(FF2_GetBossUserId(boss));

  BossData    cfg    = FF2R_GetBossData(client);
  AbilityData charge = cfg.GetAbility(ability_name);
  if (!strcmp(ability_name, "charge_tfcondition") && charge.IsMyPlugin())
  {
    int slot = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
    Charge_TFCondition(ability_name, boss, slot, status, client);
  }
  return Plugin_Continue;
}

public void Charge_TFCondition(const char[] ability_name, int boss, int slot, int action, int bClient)
{
  BossData    cfg     = FF2R_GetBossData(bClient);
  AbilityData ability = cfg.GetAbility(ability_name);

  char        cHUDText[512], cHUDText2[512], cSDJHUDText[512], cRCOSTHUDTXT[512];
  float       charge = FF2_GetBossCharge(boss, slot), bCharge = FF2_GetBossCharge(boss, 0);
  float       rCost = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3);

  // HUD Strings
  ability.GetString("TEXTcharge", cHUDText, sizeof(cHUDText));
  ability.GetString("TEXTcooldown", cHUDText2, sizeof(cHUDText2));
  ability.GetString("TEXTready", cRCOSTHUDTXT, sizeof(cRCOSTHUDTXT));
  ability.GetString("TEXTDuper", cSDJHUDText, sizeof(cSDJHUDText));

  if (rCost && !bEnableSuperDuperJump[boss])
    if (bCharge < rCost)
      return;

  switch (action)
  {
    case 1:
    {
      SetHudTextParams(HudChargeCordinate[bClient][0], HudChargeCordinate[bClient][1], 0.15, HudChargeCooldownColor[bClient][0], HudChargeCooldownColor[bClient][1], HudChargeCooldownColor[bClient][2], HudChargeCooldownColor[bClient][3]);
      // SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
      ShowSyncHudText(bClient, ChargeHud, cHUDText2, -RoundFloat(charge));
    }
    case 2:
    {
      SetHudTextParams(HudChargeCordinate[bClient][0], HudChargeCordinate[bClient][1], 0.15, HudChargeColor[bClient][0], HudChargeColor[bClient][1], HudChargeColor[bClient][2], HudChargeColor[bClient][3]);
      // SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
      if (bEnableSuperDuperJump[boss] && slot == 1)
      {
        SetHudTextParams(HudChargeCordinate[bClient][0], HudChargeCordinate[bClient][1], 0.15, HudChargeDuperColor[bClient][0], HudChargeDuperColor[bClient][1], HudChargeDuperColor[bClient][2], HudChargeDuperColor[bClient][3]);
        // SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
        ShowSyncHudText(bClient, ChargeHud, cSDJHUDText);
      }
      else
      {
        ShowSyncHudText(bClient, ChargeHud, cHUDText, RoundFloat(charge));
      }
    }
    case 3:
    {
      if (bEnableSuperDuperJump[boss] && slot == 1)
      {
        float vel[3], rot[3];
        GetEntPropVector(bClient, Prop_Data, "m_vecVelocity", vel);
        GetClientEyeAngles(bClient, rot);
        vel[2] = 750.0 + 500.0 * charge / 70 + 2000;
        vel[0] += Cosine(DegToRad(rot[0])) * Cosine(DegToRad(rot[1])) * 500;
        vel[1] += Cosine(DegToRad(rot[0])) * Sine(DegToRad(rot[1])) * 500;
        bEnableSuperDuperJump[boss] = false;
        TeleportEntity(bClient, NULL_VECTOR, NULL_VECTOR, vel);
      }
      else
      {
        if (charge < 100)
        {
          CreateTimer(0.1, ResetCharge, boss * 10000 + slot);
          return;
        }
        if (rCost)
        {
          FF2_SetBossCharge(boss, 0, bCharge - rCost);
        }

        char buffer[256];
        if (ability.GetString("selfconds", buffer, sizeof(buffer)))
        {
          RemoveCondition(bClient, buffer);
          AddCondition(bClient, buffer);
        }

        float pos[3], pos2[3];

        GetEntPropVector(bClient, Prop_Send, "m_vecOrigin", pos);

        for (int victim = 1; victim <= MaxClients; victim++)
        {
          if (IsValidClient(victim) && IsPlayerAlive(bClient))
          {
            if (victim == bClient)
              continue;

            GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

            if (GetClientTeam(victim) == GetClientTeam(bClient))
            {
              if (ability.GetString("allyconds", buffer, sizeof(buffer)))
              {
                if (GetVectorDistance(pos, pos2) < ability.GetFloat("allyrange", 10000.0))
                {
                  RemoveCondition(victim, buffer);
                  AddCondition(victim, buffer);
                }
              }
            }
            else
            {
              if (ability.GetString("enemyconds", buffer, sizeof(buffer)))
              {
                if (GetVectorDistance(pos, pos2) < ability.GetFloat("enemyrange", 10000.0))
                {
                  RemoveCondition(victim, buffer);
                  AddCondition(victim, buffer);
                }
              }
            }
          }
        }

        float position[3];
        char  sound[PLATFORM_MAX_PATH];
        if (FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, boss, slot))
        {
          EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);
          EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);

          for (int target = 1; target <= MaxClients; target++)
          {
            if (IsClientInGame(target) && target != boss)
            {
              EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
              EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
            }
          }
        }
      }
    }
    default:
    {
      if (rCost && charge <= 0.2 && !bEnableSuperDuperJump[boss])
      {
        SetHudTextParams(HudChargeCordinate[bClient][0], HudChargeCordinate[bClient][1], 0.15, HudChargeReadyColor[bClient][0], HudChargeReadyColor[bClient][1], HudChargeReadyColor[bClient][2], HudChargeReadyColor[bClient][3]);
        // SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
        ShowSyncHudText(bClient, ChargeHud, cRCOSTHUDTXT);
      }
    }
  }
}

public Action FF2_OnTriggerHurt(int boss, int triggerhurt, float &damage)
{
  if (!bEnableSuperDuperJump[boss])
  {
    bEnableSuperDuperJump[boss] = true;
    if (FF2_GetBossCharge(boss, 1) < 0)
      FF2_SetBossCharge(boss, 1, 0.0);
  }
  return Plugin_Continue;
}

public Action ResetCharge(Handle timer, any boss)
{
  int slot = boss % 10000;
  boss /= 1000;
  FF2_SetBossCharge(boss, slot, 0.0);
  return Plugin_Continue;
}

public void Rage_TFCond(int clientIdx, const char[] ability_name, AbilityData ability)
{
  char buffer[256];
  if (ability.GetString("selfconds", buffer, sizeof(buffer)))
  {
    RemoveCondition(clientIdx, buffer);
    AddCondition(clientIdx, buffer);
  }

  float pos[3], pos2[3];

  GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);

  for (int victim = 1; victim <= MaxClients; victim++)
  {
    if (IsValidClient(victim) && IsPlayerAlive(victim))
    {
      if (victim == clientIdx)
        continue;

      GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

      if (GetClientTeam(victim) == GetClientTeam(clientIdx))
      {
        if (ability.GetString("allyconds", buffer, sizeof(buffer)))
        {
          if (GetVectorDistance(pos, pos2) < ability.GetFloat("allyrange", 10000.0))
          {
            RemoveCondition(victim, buffer);
            AddCondition(victim, buffer);
          }
        }
      }
      else
      {
        if (ability.GetString("enemyconds", buffer, sizeof(buffer)))
        {
          if (GetVectorDistance(pos, pos2) < ability.GetFloat("enemyrange", 10000.0))
          {
            RemoveCondition(victim, buffer);
            AddCondition(victim, buffer);
          }
        }
      }
    }
  }
}

stock void AddCondition(int clientIdx, char[] conditions)
{
  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
  {
    for (int i = 0; i < count; i += 2)
    {
      if (!TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
      {
        TF2_AddCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i + 1]));
      }
    }
  }
}

stock void AddOnlyUnlimitedCondition(int clientIdx, char[] conditions)
{
  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
  {
    for (int i = 0; i < count; i += 2)
    {
      if (!TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))) && StringToFloat(conds[i + 1]) < 0.0)
      {
        TF2_AddCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])), TFCondDuration_Infinite);
      }
    }
  }
}

stock void SetPersistentCondition(int client, char[] cond)
{
  char conds[32][32];
  int  count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
  {
    for (int i = 0; i < count; i++)
    {
      if (view_as<TFCond>((StringToInt(conds[i]))) == TFCond_Charging)
      {
        SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
      }
      TF2_AddCondition(client, view_as<TFCond>(StringToInt(conds[i])), 0.2);
    }
  }
}

stock void RemoveCondition(int clientIdx, char[] conditions)
{
  char conds[32][32];
  int  count = ExplodeString(conditions, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
  {
    for (int i = 0; i < count; i += 2)
    {
      if (TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i]))))
      {
        TF2_RemoveCondition(clientIdx, view_as<TFCond>(StringToInt(conds[i])));
      }
    }
  }
}

stock bool IsPlayerInSpecificConditions(int client, char[] cond)
{
  char conds[32][32];
  int  count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
  if (count > 0)
  {
    for (int i = 0; i < count; i++)
    {
      return TF2_IsPlayerInCondition(client, view_as<TFCond>(StringToInt(conds[i])));
    }
  }
  return false;
}

stock float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  return cfg.GetFloat(buffer, defaul);
}

stock void SetBossCharge(ConfigData cfg, const char[] slot, float amount)
{
  int length    = strlen(slot) + 7;
  char[] buffer = new char[length];
  Format(buffer, length, "charge%s", slot);
  cfg.SetFloat(buffer, amount);
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