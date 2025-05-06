void SpawnWeapon(int client, char[] classname, int index, int level, int quality, char[] attributes)
{
  int slot = TF2_GetClassnameSlot(classname);
  TF2_RemoveWeaponSlot(client, slot);
  int    entity = -1;

  Handle item   = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
  TF2Items_SetClassname(item, classname);
  TF2Items_SetItemIndex(item, index);
  TF2Items_SetLevel(item, level);
  TF2Items_SetQuality(item, quality);

  static char buffers[40][256];
  int         count = ExplodeString(attributes, " ; ", buffers, sizeof(buffers), sizeof(buffers));
  if (count > 0)
  {
    TF2Items_SetNumAttributes(item, count / 2);
    int i2 = 0;
    for (int i = 0; i < count; i += 2)
    {
      TF2Items_SetAttribute(item, i2, StringToInt(buffers[i]), StringToFloat(buffers[i + 1]));
      i2++;
    }
  }
  entity = TF2Items_GiveNamedItem(client, item);
  delete item;

  EquipPlayerWeapon(client, entity);
  SetEntityRenderMode(entity, RENDER_ENVIRONMENTAL);
  SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
  FakeClientCommand(client, "use %s", classname);
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