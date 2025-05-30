#include <sdktools>
#include <morecolors>
#tryinclude <tf2items>

#define FF2FLAG_UBERREADY			(1<<1)		//Used when medic says "I'm charged!"
#define FF2FLAG_ISBUFFED			(1<<2)		//Used when soldier uses the Battalion's Backup
#define FF2FLAG_CLASSTIMERDISABLED 		(1<<3)		//Used to prevent clients' timer
#define FF2FLAG_HUDDISABLED			(1<<4)		//Used to prevent custom hud from clients' timer
#define FF2FLAG_BOTRAGE				(1<<5)		//Used by bots to use Boss's rage
#define FF2FLAG_TALKING				(1<<6)		//Used by Bosses with "sound_block_vo" to disable block for some lines
#define FF2FLAG_ALLOWSPAWNINBOSSTEAM		(1<<7)		//Used to allow spawn players in Boss's team
#define FF2FLAG_USEBOSSTIMER			(1<<8)		//Used to prevent Boss's timer
#define FF2FLAG_USINGABILITY			(1<<9)		//Used to prevent Boss's hints about abilities buttons
#define FF2FLAG_CLASSHELPED			(1<<10)
#define FF2FLAG_HASONGIVED			(1<<11)
#define FF2FLAG_CHANGECVAR			(1<<12)		//Used to prevent SMAC from kicking bosses who are using certain rages (NYI)
#define FF2FLAG_ALLOW_HEALTH_PICKUPS		(1<<13)		//Used to prevent bosses from picking up health
#define FF2FLAG_ALLOW_AMMO_PICKUPS		(1<<14)		//Used to prevent bosses from picking up ammo
#define FF2FLAG_ROCKET_JUMPING			(1<<15)		//Used when a soldier is rocket jumping
#define FF2FLAG_ALLOW_BOSS_WEARABLES		(1<<16)		//Used to allow boss having wearables (only for Official FF2)
#define FF2FLAGS_SPAWN				~FF2FLAG_UBERREADY & ~FF2FLAG_ISBUFFED & ~FF2FLAG_TALKING & ~FF2FLAG_ALLOWSPAWNINBOSSTEAM & ~FF2FLAG_CHANGECVAR & ~FF2FLAG_ROCKET_JUMPING & FF2FLAG_USEBOSSTIMER & FF2FLAG_USINGABILITY

#if defined _FF2_included
 #endinput
#endif
#define _FF2_included

#if defined _FFBAT_included
 #endinput
#endif
#define _FFBAT_included

/**
 * Is Freak Fortress enabled?
 *
 * @return		False if FF2 is disabled
 *			True if FF2 is enabled
 */
native bool FF2_IsFF2Enabled();

/**
 * Gets the version of FF2 running on the server
 *
 * @param version	An array of size 3 that will contain the major, minor, and stable version numbers respectively
 *
 * @return		True if the server is running a dev version of FF2, false otherwise
 */
native bool FF2_GetFF2Version(int[] version);

/**
 * Is Boss vs Boss mode enabled?
 *
 * @note		This is set before the next round setup period
 *
 * @return		False if Boss vs Boss is disabled
 *			True if Boss vs Boss is enabled
 */
native bool FF2_IsBossVsBoss();

/**
 * Gets the version of the FF2 fork running on the server
 *
 * @note		Official FF2 versions always return 0 for version numbers
 *
 * @param version	An array of size 3 that will contain the major, minor, and stable version numbers respectively
 *
 * @return		True if the server has a sub name defined, false otherwise
 */
native bool FF2_GetForkVersion(int[] fversion);

/**
 * Gets current round state
 *
 * @return		0 - in setup
 *			1 - round is in progress (due to a bug in arena mode, stalemate will also return 1)
 *			2 - someone wins
 */
native int FF2_GetRoundState();

/**
 * Gets UserID of current Boss
 *
 * @param boss		Boss's index
 *
 * @return		Userid of boss (-1 if Boss does not exist)
 */
native int FF2_GetBossUserId(int boss=0);

/**
 * Gets the boss index of a client
 *
 * @param client	The client used to search for the boss index
 *
 * @return		Boss index of that client.  If client is not boss, returns -1
 */
native int FF2_GetBossIndex(int client);

/**
 * Gets current team of Boss
 *
 * @return		Number of boss's team
 */
native int FF2_GetBossTeam();

/**
 * Gets the character name of the Boss
 *
 * @param boss	 		Boss's index
 * @param buffer		Buffer for boss' character name
 * @param bufferLength		Length of buffer string
 * @param bossMeaning			0 - "boss" parameter means index of current Boss
 *					1 - "boss" parameter means number of Boss in characters.cfg
 *
 * @error			Invalid boss index
 *
 * @return			True if boss exists, false if not
 */
native bool FF2_GetBossSpecial(int boss=0, char[] buffer, int bufferLength, int bossMeaning=0);

/**
 * Gets the character name of the Boss with language of client
 *
 * @param boss	 		Boss's index
 * @param buffer		Buffer for boss' character name
 * @param bufferLength		Length of buffer string
 * @param bossMeaning			0 - "boss" parameter means index of current Boss
 *					1 - "boss" parameter means number of Boss in characters.cfg
 * @param client		Client to get language from (0 means server language)
 *
 * @error			Invalid boss index, client index, or client not connected
 *
 * @return			True if boss exists, false if not
 */
native bool FF2_GetBossName(int boss=0, char[] buffer, int bufferLength, int bossMeaning=0, int client=0);

/**
 * Gets the current health value of the Boss
 *
 * @param boss		Boss's index
 *
 * @error		Invalid boss index
 *
 * @return		Current health of the Boss
 */
native int FF2_GetBossHealth(int boss=0);

/**
 * Sets the health of the Boss
 *
 * @param boss		Boss's index
 * @param health	New health value
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossHealth(int boss, int health);

/**
 * Gets the max health of the Boss
 *
 * @param boss		Boss's index
 *
 * @error		Invalid boss index
 *
 * @return		Max health of the Boss
 */
native int FF2_GetBossMaxHealth(int boss=0);

/**
 * Sets the max health of the Boss
 *
 * @param boss		Boss's index
 * @param health	New max health value
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossMaxHealth(int boss, int health);

/**
 * Gets the current number of lives of the Boss
 *
 * @param boss		Boss's index
 *
 * @error		Invalid boss index
 *
 * @return 		Number of lives the boss has remaining
 */
native int FF2_GetBossLives(int boss);

/**
 * Sets the current number of lives of the Boss
 *
 * @param boss		Boss's index
 * @param lives		New number of lives
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossLives(int boss, int lives);

/**
 * Gets the max number of lives of the Boss
 *
 * @param boss		Boss's index
 *
 * @error		Invalid boss index
 *
 * @return		Max number of lives of the Boss
 */
native int FF2_GetBossMaxLives(int boss);

/**
 * Sets the max number of lives of the Boss
 *
 * @param boss		Boss's index
 * @param lives		New max number of lives
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossMaxLives(int boss, int lives);

/**
 * Gets the charge meter value of the Boss
 *
 * @param boss		Boss's index
 * @param slot		Slot of charge meter
 *				0 - rage
 *				1 - as usual, used for brave jump or teleport
 *				2 - other charged abilities
 *
 * @error		Invalid boss index
 *
 * @return		Charge value of the Boss
 */
native float FF2_GetBossCharge(int boss, int slot);

/**
 * Sets the charge meter value of the Boss
 *
 * @param boss		Boss's index
 * @param slot		Slot of charge meter
 *				0 - rage
 *				1 - as usual, used for brave jump or teleport
 *				2 - other charged abilities
 * @param value		New value of charge
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossCharge(int boss, int slot, float value);

/**
 * Gets how much damage is needed in order to activate the rage of the current boss
 *
 * @param boss		Boss index
 *
 * @error		Invalid boss index
 *
 * @return		Total damage needed
 */
native int FF2_GetBossRageDamage(int boss);

/**
 * Sets how much damage is needed in order to activate the rage of the current boss
 *
 * @param boss		Boss index
 * @param damage	New damage value
 *
 * @error		Invalid boss index
 */
native void FF2_SetBossRageDamage(int boss, int damage);

/**
 * Gets damage dealt by this client
 *
 * @param client 	Client's index
 *
 * @return		Damage dealt
 */
native int FF2_GetClientDamage(int client);

/**
 * Gets an ability's rage distance
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName	Name of ability (use null string if you want get boss's global "ragedist" value)
 *
 * @error		Invalid boss index
 *
 * @return		Ability's rage distance
 */
native float FF2_GetRageDist(int boss=0, const char[] pluginName="", const char[] abilityName="");

/**
 * Finds if a Boss has a certain ability
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 *
 * @error		Invalid boss index
 *
 * @return		True if the boss has this ability, false if it doesn't
 */
native bool FF2_HasAbility(int boss, const char[] pluginName, const char[] abilityName);

/**
 * Determines how the Boss should use a certain ability
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param slot		Slot of charge meter
 *				0 - rage
 *				1 - as usual, used for brave jump or teleport
 *				2 - other charged abilities
 * @param buttonMode	How to activate the ability
 *				0 - by call for medic
 *				1 - by right mouse button or duck
 *				2 - by reload button
 *
 * @error		Invalid boss index
 */
native void FF2_DoAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int buttonMode=0);

/**
 * Gets the integer value of an ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Number of argument
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return		Value of argument
 */
native int FF2_GetAbilityArgument(int boss, const char[] pluginName, const char[] abilityName, int argument, int defValue=0);

/**
 * Gets the float value of an ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Number of argument
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return		Value of argument
 */
native float FF2_GetAbilityArgumentFloat(int boss, const char[] plugin_name, const char[] ability_name, int argument, float defValue=0.0);

/**
 * Gets the string value of an ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Number of argument
 * @param buffer 	Buffer for value of argument
 * @param bufferLength	Length of buffer string
 *
 * @error		Invalid boss index
 */
native void FF2_GetAbilityArgumentString(int boss, const char[] pluginName, const char[] abilityName, int argument, char[] buffer, int bufferLength);


/**
 * Gets the integer value of a named ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Argument name
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return		Value of argument
 */
native int FF2_GetArgNamedI(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, int defValue=0);

/**
 * Gets the float value of a named ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Argument name
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return		Value of argument
 */
native float FF2_GetArgNamedF(int boss, const char[] plugin_name, const char[] ability_name, const char[] argument, float defValue=0.0);

/**
 * Gets the string value of a named ability argument
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param argument 	Argument name
 * @param buffer 	Buffer for value of argument
 * @param bufferLength	Length of buffer string
 *
 * @error		Invalid boss index
 */
native void FF2_GetArgNamedS(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, char[] buffer, int bufferLength);

/**
 * Are named arguments used for this ability in the boss config?
 * 
 * @note		When compability with FF2 version older than 1.11.0 is wanted,
 * @note		add this code in AskPluginLoad2 in your subplugin:
 * @note		MarkNativeAsOptional("FF2_GetArgNamedI");
 * @note		MarkNativeAsOptional("FF2_GetArgNamedF");
 * @note		MarkNativeAsOptional("FF2_GetArgNamedS");
 *
 * @param boss		Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 *
 * @error		Invalid boss index
 *
 * @return              True if named arguments are used. False if indexed arguments are used.
 */
stock bool FF2_NamedArgumentsUsed(int boss, const char[] pluginName, const char[] abilityName)
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI") != FeatureStatus_Available)
		return false;

	return (FF2_GetArgNamedI(boss, pluginName, abilityName, "slot", -2)!=-2) ? true : false;
}

/**
 * Plays a sound to everyone except players who disabled boss voices
 *
 * @param sample	Sound file name relative to the "sounds" folder.
 * @param entity	Entity to emit from.
 * @param channel	Channel to emit with.
 * @param level		Sound level.
 * @param flags		Sound flags.
 * @param volume	Sound volume.
 * @param pitch		Sound pitch.
 * @param speakerentity	Unknown.
 * @param origin	Sound origin.
 * @param dir		Sound direction.
 * @param updatePos	Unknown (updates positions?)
 * @param soundtime	Alternate time to play sound for.
 */
native void FF2_EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER, int channel=SNDCHAN_AUTO, int level=SNDLEVEL_NORMAL, int flags=SND_NOFLAGS, float volume=SNDVOL_NORMAL, int pitch=SNDPITCH_NORMAL, int speakerentity=-1, const float origin[3]=NULL_VECTOR, const float dir[3]=NULL_VECTOR, bool updatePos=false, float soundtime=0.0);

/**
 * Starts a random Boss sound from its config file
 *
 * @param keyvalue	Name of sound container
 * @param buffer	Buffer for result sound path
 * @param bufferLength	Length of buffer
 * @param boss		Boss's index
 * @param slot		Only for "sound_ability" - slot of ability
 *
 * @error		Invalid boss index
 *
 * @return		True if sound has been found, false otherwise
 */
native bool FF2_RandomSound(const char[] keyvalue, char[] buffer, int bufferLength, int boss=0, int slot=0);

/**
 * Starts the Boss's music for the specified clients
 *
 * @param client	Client's index (0 for all clients)
 *
 * @error		Invalid client index
 */
native void FF2_StartMusic(int client=0);

/**
 * Stops the Boss's music for the specified clients
 *
 * @param client	Client's index (0 for all clients)
 *
 * @error		Invalid client index
 */
native void FF2_StopMusic(int client=0);

/**
 * Gets a Boss's KV handle
 *
 * @note		Don't not close or delete the handle.
 * @note		Rewind before trying to check keyvalues.
 *
 * @param boss		Boss's index
 * @param specialIndex		0 - 'boss' parameter refers to the index of the boss
 *				1 - 'boss' parameter refers to the index of the boss in characters.cfg
 *
 * @error		Invalid boss index
 *
 * @return		Handle of Boss's keyvalues
 */
native Handle FF2_GetSpecialKV(int boss, int specialIndex=0);

/**
 * Gets a client's flags for FF2
 *
 * @param client	Client's index
 *
 * @error		Invalid client index
 *
 * @return		Client's FF2 flags
 */
native int FF2_GetFF2flags(int client);

/**
 * Sets a client's flags for FF2
 *
 * @param client	Client's index
 * @param flags		New flag values
 *
 * @error		Invalid client index
 */
native void FF2_SetFF2flags(int client, int flags);

/**
 * Gets a client's queue points
 *
 * @param client	Client's index
 *
 * @error		Invalid client index
 *
 * @return		Client's queue points
 */
native int FF2_GetQueuePoints(int client);

/**
 * Sets a client's queue points
 *
 * @param client	Client's index
 * @param value		New value of client's queue points
 *
 * @error		Invalid client index
 */
native void FF2_SetQueuePoints(int client, int value);

/**
 * Gets a client's glow timer
 *
 * @param client	Client's index
 *
 * @return		Number of seconds left until client glow disappears (-1 if invalid client)
 */
native int FF2_GetClientGlow(int client);

/**
 * Sets a client's glow timer
 *
 * @param client	Client's index
 * @param time1		Number of seconds to add to the glow timer (can be negative)
 * @param time2		New value of glow timer
 */
native void FF2_SetClientGlow(int client, float time1, float time2=-1.0);

/**
 * Gets a client's shield status
 *
 * @param client	Client's index
 *
 * @return		Shield's health out of 100 (0 if shield is broken, -1 if not equipped)
 */
native float FF2_GetClientShield(int client);

/**
 * Sets a client's shield status
 *
 * @param client	Client's index
 * @param entity	Shield entity
 * @param health	Shield's health out of 100
 * @param reduction	Shield's damage reduction
 */
native void FF2_SetClientShield(int client, int entity=0, float health=-1.0, float reduction=-1.0);

/**
 * Removes a client's shield
 *
 * @param client	Client's index
 */
native void FF2_RemoveClientShield(int client);

/**
 * Reports an error to FF2's error log
 *
 * @param message	Message to error log
 */
native void FF2_LogError(const char[] message, any ...);

/**
 * Reports an error to FF2's error log with boss name
 *
 * @param boss		Boss index
 * @param message	Message to error log
 *
 * @return			error on failure
 */
native void FF2_ReportError(int boss, const char[] message, any ...);

/**
 * Returns whether or not debug is enabled
 */
native bool FF2_Debug();

/**
 * Sets the cheat status to turn off logging and statistics
 *
 * @param status	Disable statistics if true
 */
native void FF2_SetCheats(bool status=true);

/**
 * Returns whether or not FF2 cheat commands was in the round
 *
 * @return		True if used, false otherwise
 */
native bool FF2_GetCheats();

/**
 * Creates a boss of a given client
 *
 * @param client	Client's index
 * @param boss		Boss index (-1 to make someone not a boss)
 * @param special	Boss selection override
 * @param rival		Have boss on non-boss team
 *
 * @error		Invalid boss index
 */
native void FF2_MakeBoss(int client, int boss, int special=-1, bool rival=false);

/**
 * Sets the boss selection of a client
 *
 * @param client	Client's index
 * @param boss		Boss's name ("name" key)
 * @param access	Allow the client to play that boss regardless of permission
 *
 * @return		True if the client normally has access to this boss, false otherwise
 */
native bool FF2_SelectBoss(int client, const char[] boss, bool access=true);

/**
 * FF2_ONABILITY IS KNOWN TO BE BUGGED AND WILL NOT BE FIXED TO PRESERVE BACKWARDS COMPATABILITY.  DO NOT USE IT.
 * Called when a Boss uses an ability (Rage, jump, teleport, etc)
 * Called every 0.2 seconds for charge abilities
 *
 * @note		Use FF2_PreAbility with enabled=false ONLY to prevent FF2_OnAbility!
 *
 * @param boss	 	Boss's index
 * @param pluginName	Name of plugin with this ability
 * @param abilityName 	Name of ability
 * @param slot		Slot of ability (THIS DOES NOT RETURN WHAT YOU THINK IT RETURNS FOR FF2_ONABILITY-if you insist on using this, refer to freak_fortress_2.sp to see what it actually does)
 * 				0 - Rage or life-loss
 * 				1 - Jump or teleport
 * 				2 - Other
 * @param status	Status of ability (DO NOT ACCESS THIS.  IT DOES NOT EXIST AND MIGHT CRASH YOUR SERVER)
 *
 * @return		Plugin_Stop can not prevent the ability. Use FF2_PreAbility with enabled=false
 */
forward void FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, bool &enabled);
forward Action FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status);

/**
 * Called when a Boss gets hurt by environmental damage
 *
 * @param boss	 	Boss's index
 * @param triggerHurt	Entity index of "trigger_hurt"
 * @param damage 	Damage by "trigger_hurt".  Cutomizable.
 *
 * @return		Plugin_Stop will prevent forward, Plugin_Changed will change damage.
 */
forward Action FF2_OnTriggerHurt(int boss, int triggerHurt, float &damage);

/**
 * Called when a Boss's music begins
 *
 * @param path 		Path to music sound file
 * @param time		Length of music
 *
 * @return		Plugin_Stop will prevent music, Plugin_Changed will change it.
 */
forward Action FF2_OnMusic(char[] path, float &time);

/**
 * Called when a Boss's music begins with name and artist
 *
 * @param path 		Path to music sound file
 * @param time		Length of music
 * @param name 		The music name
 * @param artist 	The music artist
 *
 * @return		Plugin_Stop will prevent music, Plugin_Changed will change it.
 */
forward Action FF2_OnMusic2(char[] path, float &time, char[] name, char[] artist);

/**
 * Called when FF2 picks a character for a Boss
 *
 * @param boss		Boss index
 * @param character   	Character index
 * @param characterName	Character name
 * @param preset	True if the boss was set using a command such as ff2_special
 *
 * @return		You can NOT use Plugin_Stop to prevent this, but you can change characterName and use Plugin_Changed to change the boss.  If you want to change 'character', then make 'characterName' null.
 */
forward Action FF2_OnSpecialSelected(int boss, int &character, char[] characterName, bool preset);

/**
 * Called when FF2 adds queue points
 *
 * @param add_points	Array that contains each player's queue points
 *
 * @return		Plugin_Stop will prevent this, Plugin_Changed will change it.
 */
forward Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS+1]);

/**
 * Called when FF2 picks a character set for the map
 *
 * @param charSetNum	Number of character set
 * @param charSetName	Name of character set
 *
 * @return		You can NOT use Plugin_Stop to prevent this, but you can change charSetName and use Plugin_Changed to change the character set.  If you want to change charSetNum, then make charSetName null.
 */
forward Action FF2_OnLoadCharacterSet(int &charSetNum, char[] charSetName);

/**
 * Called when a Boss loses a life
 *
 * @param boss		Boss's index
 * @param lives		Number of lives left
 * @param maxLives	Max number of lives
 *
 * @return		Plugin_Stop or Plugin_Handled to prevent damage that would remove a life, Plugin_Changed if you want to change the number of lives left.
 */
forward Action FF2_OnLoseLife(int boss, int &lives, int maxLives);

/**
 * Called when the number of alive players changes.  Note that this will never be 0 as FF2 does not re-calculate the number of players once the round ends.
 *
 * @param players	Number of alive players left on the non-boss team
 * @param bosses	Number of alive players left on the boss team (this includes minions as well)
 */
forward void FF2_OnAlivePlayersChanged(int players, int bosses);

/**
 * Called when a boss is backstabbed
 *
 * @param boss		Boss's index
 * @param client	Boss's client index
 * @param attacker	Attacker's client index
 * @param damage	Damage dealt (includes crit bonus)
 *
 * @return		Plugin_Changed to adjust the damage dealt, Plugin_Handled to prevent damage being dealt but continue sounds, stuns, etc, Plugin_Stop to prevent the backstab all together
 */
forward Action FF2_OnBackStabbed(int boss, int client, int attacker);

/**
 * Called when the boss has a difficulty/special set for this plugin
 *
 * @note		This is called per-plugin, no need to check which plugin it belongs to
 * @note		Don't change the position or close the handle, instead just use KvGetNum, KvGetString, etc.
 *
 * @param boss		Boss index
 * @param difficulty	Name of the difficulty/special
 * @param kv		KeyValues handle of difficulty config
 */
forward void FF2_OnDifficulty(int boss, const char[] difficulty, Handle kv);

/**
 * Gives ammo to a weapon
 *
 * @param client	Client's index
 * @param weapon	Weapon
 * @param ammo		Ammo (set to -1 for clipless weapons, then set the actual ammo using clip)
 * @param clip		Clip
 *
 * @error		Invalid client index or client not in game
 */
stock void FF2_SetAmmo(int client, int weapon, int ammo=-1, int clip=-1)
{
	if(IsValidEntity(weapon))
	{
		if(clip > -1)
			SetEntProp(weapon, Prop_Data, "m_iClip1", clip);

		int ammoType = (ammo>-1 ? GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") : -1);
		if(ammoType != -1)
			SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammoType);
	}
}

/**
 * Sends a synced HUD message according to FF2's rules
 * Will only send if the client hasn't disabled their HUD and isn't checking the scoreboard
 *
 * Uses the same params and return values as ShowSyncHudText
 */
stock void FF2_ShowSyncHudText(int client, Handle sync, const char[] buffer, any ...)
{
	if(!(FF2_GetFF2flags(client) & FF2FLAG_HUDDISABLED) && !(GetClientButtons(client) & IN_SCORE))
	{
		char message[256];
		VFormat(message, sizeof(message), buffer, 4);
		SetGlobalTransTarget(client);
		ShowSyncHudText(client, sync, message);
	}
}

/**
 * Sends a HUD message according to FF2's rules
 * Will only send if the client hasn't disabled their HUD and isn't checking the scoreboard
 *
 * Uses the same params and return values as ShowHudText
 */
stock void FF2_ShowHudText(int client, int channel, const char[] buffer, any ...)
{
	if(!(FF2_GetFF2flags(client) & FF2FLAG_HUDDISABLED) && !(GetClientButtons(client) & IN_SCORE))
	{
		char message[256];
		VFormat(message, sizeof(message), buffer, 4);
		SetGlobalTransTarget(client);
		ShowHudText(client, channel, message);
	}
}

#pragma deprecated Use FF2Dbg instead
stock void Debug(const char[] buffer, any ...)
{
	if(FF2_Debug())
	{
		char message[192];
		VFormat(message, sizeof(message), buffer, 2);
		CPrintToChatAll("{olive}[FF2 {darkorange}DEBUG{olive}]{default} %s", message);
		PrintToServer("[FF2 DEBUG] %s", message);
	}
}

/**
 * Used to consolidate debug messages
 *
 * @param buffer	Debug string to display
 * @param ...		Formatting rules
 */
stock void FF2Dbg(const char[] buffer, any ...)
{
	if(FF2_Debug())
	{
		char message[192];
		VFormat(message, sizeof(message), buffer, 2);
		CPrintToChatAll("{olive}[FF2 {darkorange}DEBUG{olive}]{default} %s", message);
		PrintToServer("[FF2 DEBUG] %s", message);
	}
}

/**
 * Prints a color message with FF2's prefix
 *
 * Uses the same params and return values as CPrintToChat, CPrintToChatAll, and CReplyToCommand
 */
stock void FPrintToChat(int client, const char[] message, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 3);
	CPrintToChat(client, "%t%s", "Prefix", buffer);
}
stock void FPrintToChatAll(const char[] message, any ...)
{
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 2);
	CPrintToChatAll("%t%s", "Prefix", buffer);
}
stock void FReplyToCommand(int client, const char[] message, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 3);
	if(!client)
	{
		CRemoveTags(buffer, sizeof(buffer));
		PrintToServer("[FF2] %s", buffer);
	}
	else if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		CRemoveTags(buffer, sizeof(buffer));
		PrintToConsole(client, "[FF2] %s", buffer);
	}
	else
	{
		CPrintToChat(client, "%t%s", "Prefix", buffer);
	}
}

/**
 * Used to spawn a weapon
 *
 * @param client	Client index
 * @param name		Classname of the weapon
 * @param index		Definition index of the weapon
 * @param level		Level of the weapon
 * @param qual		Quality of the weapon
 * @param att		String, containing the attributes in the following format: attr ; val ; attr ; val ; ...
 * @param visible	Weapon will be visible?
 *
 * @error		Invalid item index, level, quality, client index, or client not in game
 *
 * @return		Entity index of the weapon, -1 on failure
 */
stock int FF2_SpawnWeapon(int client, char[] name, int index, int level, int qual, const char[] att, bool visible=true)
{
	#if defined _tf2items_included
	if(StrEqual(name, "saxxy", false))	// if "saxxy" is specified as the name, replace with appropiate name
	{ 
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:	ReplaceString(name, 64, "saxxy", "tf_weapon_bat", false);
			case TFClass_Pyro:	ReplaceString(name, 64, "saxxy", "tf_weapon_fireaxe", false);
			case TFClass_DemoMan:	ReplaceString(name, 64, "saxxy", "tf_weapon_bottle", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "saxxy", "tf_weapon_fists", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "saxxy", "tf_weapon_wrench", false);
			case TFClass_Medic:	ReplaceString(name, 64, "saxxy", "tf_weapon_bonesaw", false);
			case TFClass_Sniper:	ReplaceString(name, 64, "saxxy", "tf_weapon_club", false);
			case TFClass_Spy:	ReplaceString(name, 64, "saxxy", "tf_weapon_knife", false);
			default:		ReplaceString(name, 64, "saxxy", "tf_weapon_shovel", false);
		}
	}
	else if(StrEqual(name, "tf_weapon_shotgun", false))	// If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Pyro:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_pyro", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_hwg", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_primary", false);
			default:		ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_soldier", false);
		}
	}

	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(hWeapon == INVALID_HANDLE)
		return -1;

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
		--count;

	if(count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attrib = StringToInt(atts[i]);
			if(!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", atts[i], atts[i+1]);
				delete hWeapon;
				return -1;
			}

			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	if(entity == -1)
		return -1;

	EquipPlayerWeapon(client, entity);

	if(visible)
	{
		SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
	}
	else
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	return entity;
	#else
	return -1;
	#endif
}

/**
 * Get int argument of ability in compatible way
 *
 * @param boss		Boss's index
 * @param plugin_name	Name of plugin with this ability
 * @param ability_name 	Name of ability
 * @param argument 	Argument name
 * @param index         Argument number, used as fallback when the numbered arguments are used
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return         	The value of the argument or default value
 */
stock int FF2_GetArgI(int boss, const char[] plugin_name, const char[] ability_name, const char[] argument, int index, int defValue=0)
{
	return GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI")==FeatureStatus_Available ?
	       FF2_GetArgNamedI(boss, plugin_name, ability_name, argument, FF2_GetAbilityArgument(boss, plugin_name, ability_name, index, defValue)) :
	       FF2_GetAbilityArgument(boss, plugin_name, ability_name, index, defValue);
}

/**
 * Get float argument of ability in compatible way
 *
 * @param boss		Boss's index
 * @param plugin_name	Name of plugin with this ability
 * @param ability_name 	Name of ability
 * @param argument 	Argument name
 * @param index         Argument number, used as fallback when the numbered arguments are used
 * @param defValue 	Returns if argument is not defined
 *
 * @error		Invalid boss index
 *
 * @return         	The value of the argument or default value
 */
stock float FF2_GetArgF(int boss, const char[] plugin_name, const char[] ability_name, const char[] argument, int index, float defValue=0.0)
{
	return GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI")==FeatureStatus_Available ?
	       FF2_GetArgNamedF(boss, plugin_name, ability_name, argument, FF2_GetAbilityArgumentFloat(boss, plugin_name, ability_name, index, defValue)) :
	       FF2_GetAbilityArgumentFloat(boss, plugin_name, ability_name, index, defValue);
}

/**
 * Get string argument of ability in compatible way
 *
 * @param boss		Boss's index
 * @param plugin_name	Name of plugin with this ability
 * @param ability_name 	Name of ability
 * @param argument 	Argument name
 * @param index         Argument number, used as fallback when the numbered arguments are used
 * @param buffer 	Buffer for value of the argument
 * @param bufferLength 	Size of the buffer
 *
 * @error		Invalid boss index
 *
 * @return         	Number of characters stored in the provided buffer
 */
stock int FF2_GetArgS(int boss, const char[] plugin_name, const char[] ability_name, const char[] argument, int index, char[] buffer, int bufferLength)
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI") == FeatureStatus_Available)
	{
		FF2_GetArgNamedS(boss, plugin_name, ability_name, argument, buffer, bufferLength);
		if(!strlen(buffer))
			FF2_GetAbilityArgumentString(boss, plugin_name, ability_name, index, buffer, bufferLength);
	}
	else
	{
		FF2_GetAbilityArgumentString(boss, plugin_name, ability_name, index, buffer, bufferLength);
	}
	return strlen(buffer);
}

methodmap FF2Data
{
	/**
	 * Get boss data given client index
	 *
	 * @param client
	 * @return 			FF2Data, Invalid or error on failure
	 */
	public static native FF2Data Unknown(int client);
	
	/**
	 * Get boss data given boss index
	 *
	 * @param boss
	 * @param plugin	optional
	 * @param ability	optional
	 * @return 			FF2Data, Invalid or error on failure
	 */
	public native FF2Data(int boss, const char[] plugin = "", const char[] ability = "");
	
	/**
	 *	Invalid index
	 */
	property bool Invalid
	{
		public get() { return view_as<int>(this) == -1; }
	}
	
	/**
	 *	boss index
	 */
	property int boss
	{
		public native get();
	}
	
	/**
	 *	client index
	 */
	property int client
	{
		public native get();
	}
	
	/**
	 * boss config file
	 * @return config, or error
	 */
	property KeyValues Config {
		public native get();
	}
	
	/**
	 * similar to FF2_GetBossHealth() / FF2_SetBossHealth
	 * @return 			boss health
	 */
	property int Health
	{
		public native get();
		public native set(const int h);
	}
	
	/**
	 * similar to FF2_GetBossMaxHealth() / FF2_SetBossMaxHealth
	 * @return 			boss max health
	 */
	property int MaxHealth
	{
		public native get();
		public native set(const int h);
	}
	
	/**
	 * similar to FF2_GetBossLives() / FF2_SetBossLives()
	 * @return 			boss lives
	 */
	property int Lives
	{
		public native get();
		public native set(const int l);
	}
	
	/**
	 * similar to FF2_GetBossMaxLives() / FF2_SetBossMaxLives()
	 * @return 			boss max lives
	 */
	property int MaxLives
	{
		public native get();
		public native set(const int l);
	}

	/**
	 * wrapper to FF2_GetBossCharge() / FF2_SetBossCharge()
	 * @return 			boss rage
	 */
	property float Rage
	{
		public get() { return FF2_GetBossCharge(this.boss, 0); }
		public set(const float c) { FF2_SetBossCharge(this.boss, 0, c); }
	}
	
	/**
	 * similar to FF2_GetBossRageDamage() / FF2_SetBossRageDamage()
	 * @return 			boss rage damage
	 */
	property int RageDmg
	{
		public native get();
		public native set(const int r);
	}
	
	
	/**
	 * similar to FF2_GetBossTeam()
	 * @return 			boss team
	 */
	public static native int BossTeam();
	
	/**
	 * Change ability iterator 
	 *
	 * @param plugin
	 * @param ability
	 * @return error on failure
	 */
	public native void Change(const char[] plugin, const char[] ability);
	
	/**
	 * similar FF2_GetArgNamedI 
	 *
	 * @param key		ability key
	 * @param def		default value if lookup failed
	 * @param base		retrieve the value as
	 */
	public native int GetArgI(const char[] key, int def = 0, int base = 10);
	
	/**
	 * similar FF2_GetArgNamedF
	 *
	 * @param key		ability key
	 * @param def		default value if lookup failed
	 */
	public native float GetArgF(const char[] key, float def = 0.0);
	
	/**
	 * retrieve argument value as bool
	 *
	 * @param key		ability key
	 * @param def		default value if lookup failed
	 */
	public native bool GetArgB(const char[] key, bool def = false);
	
	/**
	 * similar to FF2_GetArgNamedS
	 *
	 * @param key		ability key
	 * @param def		default value if lookup failed
	 * @return 			number of bytes written
	 */
	public native int GetArgS(const char[] key, char[] res, int maxlen);
	
	/**
	 * similar to FF2_HasAbility
	 * @return 			error on failure
	 */
	public native bool HasAbility();
}


public SharedPlugin __pl_FF2 =
{
	name = "freak_fortress_2",
	file = "freak_fortress_2.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_FF2_SetNTVOptional()
{
	MarkNativeAsOptional("FF2_IsFF2Enabled");
	MarkNativeAsOptional("FF2_IsBossVsBoss");
	MarkNativeAsOptional("FF2_GetFF2Version");
	MarkNativeAsOptional("FF2_GetForkVersion");
	MarkNativeAsOptional("FF2_GetRoundState");
	MarkNativeAsOptional("FF2_GetBossUserId");
	MarkNativeAsOptional("FF2_GetBossIndex");
	MarkNativeAsOptional("FF2_GetBossTeam");
	MarkNativeAsOptional("FF2_GetBossSpecial");
	MarkNativeAsOptional("FF2_GetBossName");
	MarkNativeAsOptional("FF2_GetBossHealth");
	MarkNativeAsOptional("FF2_SetBossHealth");
	MarkNativeAsOptional("FF2_GetBossMaxHealth");
	MarkNativeAsOptional("FF2_SetBossMaxHealth");
	MarkNativeAsOptional("FF2_GetBossLives");
	MarkNativeAsOptional("FF2_SetBossLives");
	MarkNativeAsOptional("FF2_GetBossMaxLives");
	MarkNativeAsOptional("FF2_SetBossMaxLives");
	MarkNativeAsOptional("FF2_GetBossCharge");
	MarkNativeAsOptional("FF2_SetBossCharge");
	MarkNativeAsOptional("FF2_GetBossRageDamage");
	MarkNativeAsOptional("FF2_SetBossRageDamage");
	MarkNativeAsOptional("FF2_GetClientDamage");
	MarkNativeAsOptional("FF2_GetRageDist");
	MarkNativeAsOptional("FF2_HasAbility");
	MarkNativeAsOptional("FF2_DoAbility");
	MarkNativeAsOptional("FF2_GetAbilityArgument");
	MarkNativeAsOptional("FF2_GetAbilityArgumentFloat");
	MarkNativeAsOptional("FF2_GetAbilityArgumentString");
	MarkNativeAsOptional("FF2_GetArgNamedI");
	MarkNativeAsOptional("FF2_GetArgNamedF");
	MarkNativeAsOptional("FF2_GetArgNamedS");
	MarkNativeAsOptional("FF2_EmitVoiceToAll");
	MarkNativeAsOptional("FF2_RandomSound");
	MarkNativeAsOptional("FF2_StartMusic");
	MarkNativeAsOptional("FF2_StopMusic");
	MarkNativeAsOptional("FF2_GetSpecialKV");
	MarkNativeAsOptional("FF2_GetFF2flags");
	MarkNativeAsOptional("FF2_SetFF2flags");
	MarkNativeAsOptional("FF2_GetQueuePoints");
	MarkNativeAsOptional("FF2_SetQueuePoints");
	MarkNativeAsOptional("FF2_GetClientGlow");
	MarkNativeAsOptional("FF2_SetClientGlow");
	MarkNativeAsOptional("FF2_GetClientShield");
	MarkNativeAsOptional("FF2_RemoveClientShield");
	MarkNativeAsOptional("FF2_LogError");
	MarkNativeAsOptional("FF2_Debug");
	MarkNativeAsOptional("FF2_SetCheats");
	MarkNativeAsOptional("FF2_GetCheats");
	MarkNativeAsOptional("FF2_MakeBoss");
	MarkNativeAsOptional("FF2_ReportError");
	
	MarkNativeAsOptional("FF2Data.Unknown");
	MarkNativeAsOptional("FF2Data.FF2Data");
	MarkNativeAsOptional("FF2Data.Invalid");
	MarkNativeAsOptional("FF2Data.boss.get");
	MarkNativeAsOptional("FF2Data.client.get");
	MarkNativeAsOptional("FF2Data.Config.get");
	MarkNativeAsOptional("FF2Data.Health.get");
	MarkNativeAsOptional("FF2Data.Health.set");
	MarkNativeAsOptional("FF2Data.MaxHealth.get");
	MarkNativeAsOptional("FF2Data.MaxHealth.set");
	MarkNativeAsOptional("FF2Data.Lives.get");
	MarkNativeAsOptional("FF2Data.Lives.set");
	MarkNativeAsOptional("FF2Data.MaxLives.get");
	MarkNativeAsOptional("FF2Data.MaxLives.set");
	MarkNativeAsOptional("FF2Data.RageDmg.get");
	MarkNativeAsOptional("FF2Data.RageDmg.set");
	MarkNativeAsOptional("FF2Data.Change");
	MarkNativeAsOptional("FF2Data.GetArgI");
	MarkNativeAsOptional("FF2Data.GetArgF");
	MarkNativeAsOptional("FF2Data.GetArgB");
	MarkNativeAsOptional("FF2Data.GetArgS");
	MarkNativeAsOptional("FF2Data.HasAbility");
	MarkNativeAsOptional("FF2Data.BossTeam");
}
#endif
