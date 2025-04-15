/*
    "rage_forcetaunt" // Ability name can use suffixes
    {
      "slot" "0"

      "id" ""
      "repeat" "1"  // 0: No repeat, 1: Repeat once, 2: Repeat twice, etc.
      "interval" "0.0" // interval between taunts that repeat
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

int repeat[MAXPLAYERS + 1];  // maxdances for taunts per player

public Plugin myinfo =
{
  name   = "Freak Fortress 2 Rewrite: Force Taunts",
  author = "x07x08, Zell",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
  // Just your classic stuff, when boss raged:
  if (!cfg.IsMyPlugin())  // Incase of duplicated ability names with different plugins in boss config
    return;

  if (!StrContains(ability, "rage_forcetaunt", false) && cfg.IsMyPlugin())
  {
    int   id       = cfg.GetInt("id", 0);
    int   target   = cfg.GetInt("target", 0);        // 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
    int   repeater = cfg.GetInt("repeat", 1);        // 0: No repeat, 1: Repeat once, 2: Repeat twice, etc.
    float range    = cfg.GetFloat("range", 9999.0);  // 9999 is the default value for range (and it's roundstart soooo it doesn't matter)
    float interval = cfg.GetFloat("interval", 0.0);  // interval between taunts that repeat

    float pos[3], pos2[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

    for (int i = 1; i <= MaxClients; i++)
    {
      if (IsValidLivingClient(i) && IsTarget(client, i, target))
      {
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);

        if (GetVectorDistance(pos, pos2) <= range)
        {
          PlayTaunt(i, id);
          if (repeater > 0)
          {
            repeat[i] = repeater;
            DataPack pack;
            CreateDataTimer(interval, LoopTaunt, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            pack.WriteCell(i);  // clientIdx
            pack.WriteCell(id);
          }
        }
      }
    }
  }
}

public Action LoopTaunt(Handle hTimer, DataPack pack)
{
  pack.Reset();
  int clientIdx = pack.ReadCell();
  int id        = pack.ReadCell();

  if (repeat[clientIdx] <= 0 || !IsValidLivingClient(clientIdx))
  {
    return Plugin_Stop;
  }

  PlayTaunt(clientIdx, id);

  return Plugin_Continue;
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

  // decrese repeat count
  if (repeat[iClient] > 0)
  {
    repeat[iClient]--;
    if (repeat[iClient] <= 0)
    {
      repeat[iClient] = 0;
    }
  }
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

stock bool IsValidLivingClient(int clientIdx, bool replaycheck = true)
{
  if (clientIdx <= 0 || clientIdx > MaxClients)
    return false;

  if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
    return false;

  if (!IsPlayerAlive(clientIdx))
    return false;

  if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
    return false;

  if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
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