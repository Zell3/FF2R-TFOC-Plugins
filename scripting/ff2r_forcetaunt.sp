/*
    "rage_forcetaunt" // Ability name can use suffixes
    {
      "slot" "0"

      "id" ""
      "repeat" "1"  // 0: No repeat, 1: Repeat once, 2: Repeat twice, etc.
      "target" "3" // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
      "range" "9999.0" // range

      "plugin_name" "ff2r_forcetaunt"
    }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>

#pragma semicolon 1
#pragma newdecls required

#define DEFINDEX_UNDEFINED 65535

int  g_iTauntRepeat[MAXPLAYERS + 1];
int  g_iTauntId[MAXPLAYERS + 1];
bool g_bDoSlot[MAXPLAYERS + 1];
int  g_iDoSlotNum[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name   = "Freak Fortress 2 Rewrite: Force Taunts",
  author = "x07x08, Zell",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  if (cfg.IsMyPlugin() && !StrContains(ability, "rage_forcetaunt", false))
  {
    // Get and validate parameters
    int   id     = cfg.GetInt("id", 0);
    int   target = cfg.GetInt("target", 0);
    int   repeat = cfg.GetInt("repeat", 0);
    float range  = cfg.GetFloat("range", 9999.0);

    // Store the ability handle for DoSlot after taunt
    int   doslot = cfg.GetInt("doslot", -2);

    float pos[3], pos2[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    for (int i = 1; i <= MaxClients; i++)
    {
      // clear data
      g_iTauntId[i]     = 0;
      g_iTauntRepeat[i] = 0;
      g_bDoSlot[i]      = false;
      g_iDoSlotNum[i]   = -2;

      if (!IsValidLivingClient(i))
        continue;

      if (i == client)
      {
        if (doslot != -2)
        {
          g_bDoSlot[client]      = true;
          g_iDoSlotNum[client]   = doslot;
          g_iTauntId[client]     = id;
          g_iTauntRepeat[client] = repeat;

          // force player to taunt no matter what it is if have doslot
          SDKHook(client, SDKHook_PreThink, OnPlayerPreThink);
          continue;
        }
      }

      if (!IsTarget(client, i, target))
        continue;

      GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
      if (GetVectorDistance(pos, pos2) > range)
        continue;

      // Setup initial taunt with waiting
      g_iTauntId[i]     = id;
      g_iTauntRepeat[i] = repeat;

      SDKHook(i, SDKHook_PreThink, OnPlayerPreThink);
    }
  }
}

public void OnPlayerPreThink(int client)
{
  if (!IsValidLivingClient(client))
  {
    SDKUnhook(client, SDKHook_PreThink, OnPlayerPreThink);
    g_iTauntId[client]     = 0;
    g_iTauntRepeat[client] = 0;
    return;
  }

  if (g_iTauntRepeat[client] < 0)
  {
    SDKUnhook(client, SDKHook_PreThink, OnPlayerPreThink);
    g_iTauntId[client]     = 0;
    g_iTauntRepeat[client] = 0;
    return;
  }

  if (!IsValidTauntTarget(client))
    return;

  PlayTaunt(client, g_iTauntId[client]);
}

public void PlayTaunt(int iClient, int iTauntIndex)
{
  int iEntity = MakeCEIVEnt(iClient, iTauntIndex);

  if (!IsValidEntity(iEntity))
    return;

  int iCEIVOffset = GetEntSendPropOffs(iEntity, "m_Item", true);

  if (iCEIVOffset <= 0)
  {
    RemoveEntity(iEntity);
    return;
  }

  Address pEconItemView = GetEntityAddress(iEntity);

  if (!IsValidAddress(pEconItemView))
  {
    RemoveEntity(iEntity);
    return;
  }

  pEconItemView += view_as<Address>(iCEIVOffset);

  static Handle hPlayTaunt = null;

  if (hPlayTaunt == null)
  {
    GameData hConf = new GameData("tf2.tauntem");

    if (hConf == null) SetFailState("Unable to load gamedata/tf2.tauntem.txt.");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    hPlayTaunt = EndPrepSDKCall();

    if (hPlayTaunt == null) SetFailState("Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem.");

    delete hConf;
  }

  if (!SDKCall(hPlayTaunt, iClient, pEconItemView))
  {
    RemoveEntity(iEntity);
    return;
  }

  // Remove the entity after playing the taunt
  RemoveEntity(iEntity);

  // Decrement repeat count
  g_iTauntRepeat[iClient]--;

  // If we have a doslot pending and this is the last/only taunt
  if (g_bDoSlot[iClient] && g_iTauntRepeat[iClient] < 0)
  {
    // Start checking for taunt end immediately
    CreateTimer(3.0, Timer_CheckTauntEnd, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_CheckTauntEnd(Handle timer, any userid)
{
  int client = GetClientOfUserId(userid);

  if (!IsValidLivingClient(client) || !g_bDoSlot[client])
  {
    g_bDoSlot[client]    = false;
    g_iDoSlotNum[client] = -2;
    return Plugin_Stop;
  }

  FF2R_DoBossSlot(client, g_iDoSlotNum[client]);

  return Plugin_Continue;
}

/*
  https://github.com/nosoop/stocksoup/blob/master/tf/econ.inc
  https://git.csrd.science/nosoop/CSRD-BotTauntRandomizer
*/

stock int MakeCEIVEnt(int iClient, int iItemDef)
{
  int iWearable = CreateEntityByName("tf_wearable");

  if (!IsValidEntity(iWearable)) return iWearable;

  SetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex", iItemDef);

  if (iItemDef != DEFINDEX_UNDEFINED)
  {
    // using defindex of a valid item
    SetEntProp(iWearable, Prop_Send, "m_bInitialized", 1);
    SetEntProp(iWearable, Prop_Send, "m_iEntityLevel", 1);
    // Something about m_iEntityQuality doesn't play nice with SetEntProp.
    SetEntData(iWearable, FindSendPropInfo("CTFWearable", "m_iEntityQuality"), 6);
  }

  // Spawn.
  DispatchSpawn(iWearable);

  return iWearable;
}

stock bool IsValidAddress(Address pAddress)
{
  return pAddress != Address_Null;
}

stock bool IsValidTauntTarget(int client)
{
  // Check if player is on ground
  if (!(GetEntityFlags(client) & FL_ONGROUND))
    return false;

  // Check if player is already taunting
  if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
    return false;

  return true;
}

stock bool IsValidLivingClient(int clientIdx, bool replaycheck = true)
{
  if (clientIdx <= 0 || clientIdx > MaxClients)
    return false;

  if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
    return false;

  if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
    return false;

  if (!IsPlayerAlive(clientIdx))
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