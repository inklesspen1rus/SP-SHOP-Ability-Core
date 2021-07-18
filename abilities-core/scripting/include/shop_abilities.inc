/***
 * Abilities2_AttributeChanged
 * Runs when any attribute of player was changed 
 * If type of attribute == 2 then use RoundToZero(oldvalue) and RoundToZero(newvalue)
***/
forward void Abilities2_AttributeChanged(const char[] attribute, int client, float oldvalue, float newvalue);

/***
 * Abilities2_AttributeRegistered
 * Called when attribute has been registered
***/
forward void Abilities2_AttributeRegistered(const char[] attribute, int index, int type);

/***
 * Abilities2_AttributeRegistered
 * Called when attribute has been registered
 * Return Plugin_Stop to prevert 
***/
forward Action Abilities2_OnCheckEnable(int client, int index);

/***
 *	Types:
 *	0 - PERCENT, displays as +100*F%
 *	1 - FLOAT, displays as +F
 *	2 - INT, displays as +N
***/
native int Abilities2_RegisterAttribute(const char[] attribute, int type);

/***
 *	Error: if client isnt connected or client is bot or invalid attribute
***/
native any Abilities2_GetClientAttribute(int client, const char[] attribute);

// Returns attribute's index or -1 if not found
native int Abilities2_FindAttributeByName(const char[] attribute);

// Stores attribute's name to buffer
// Throws error if attribute's index is invalid
native void Abilities2_GetAttributeName(int id, char[] buffer, int max);

// Throws error if client isnt connected or client is bot
// Throws error if attribute's index is invalid
native any Abilities2_GetClientAttributeEx(int client, int id);

/***
 *	Types:
 *	0 - PERCENT, displays as +100*F%
 *	1 - FLOAT, displays as +F
 *	2 - INT, displays as +N
***/
// Throws error if attribute's index is invalid
native int Abilities2_GetAttributeType(int id);

// Returns attributes count
native int Abilities2_AttributeCount();

// Recalculate or refresh attributes blocks
native void Abilities2_UpdatePlayer(int client, bool recalculate = false);

// Use this bcs of calculating issues with "any" type
// float Abilities2_GetClientAttributeFloat(int client, const char[] attribute);
#define Abilities2_GetClientAttributeFloat(%1,%2) view_as<float>(Abilities2_GetClientAttribute(%1,%2))

// Use this bcs of calculating issues with "any" type
// float Abilities2_GetClientAttributeInt(int client, const char[] attribute);
#define Abilities2_GetClientAttributeInt(%1,%2) view_as<int>(Abilities2_GetClientAttribute(%1,%2))

// Use this bcs of calculating issues with "any" type
// float Abilities2_GetClientAttributeExFloat(int client, int index);
#define Abilities2_GetClientAttributeExFloat(%1,%2); view_as<float>(Abilities2_GetClientAttributeEx(%1,%2))

// Use this bcs of calculating issues with "any" type
// float Abilities2_GetClientAttributeExInt(int client, int index);
#define Abilities2_GetClientAttributeExInt(%1,%2) view_as<int>(Abilities2_GetClientAttributeEx(%1,%2))

public SharedPlugin __pl_abilities2 = 
{
	name = "abilities2",
	file = "shop_abilities_core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}

#if !defined REQUIRE_PLUGIN
public void __pl_abilities2_SetNTVOptional()
{
	MarkNativeAsOptional("Abilities2_FindAttributeByName");
	MarkNativeAsOptional("Abilities2_GetAttributeName");
	MarkNativeAsOptional("Abilities2_GetAttributeType");
	MarkNativeAsOptional("Abilities2_AttributeCount");
	MarkNativeAsOptional("Abilities2_UpdatePlayer");
	MarkNativeAsOptional("Abilities2_HookAttributeBlock");
	MarkNativeAsOptional("Abilities2_UnhookAttributeBlock");
	MarkNativeAsOptional("Abilities2_RegisterAttribute");
	MarkNativeAsOptional("Abilities2_GetClientAttribute");
}
#endif