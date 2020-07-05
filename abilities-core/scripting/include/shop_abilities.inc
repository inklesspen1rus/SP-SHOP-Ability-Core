/***
 * Abilities2_AttributeChanged
 * Runs when any attribute of player was changed 
 * If type of attribute == 2 then use RoundToZero(oldvalue) and RoundToZero(newvalue)
***/
forward void Abilities2_AttributeChanged(const char[] attribute, int client, float oldvalue, float newvalue)

/***
 *	Types:
 *	0 - PERCENT, displays as +100*F%
 *	1 - FLOAT, displays as +F
 *	2 - INT, displays as +N
***/
native int Abilities2_RegisterAttribute(const char[] attribute, int type)

/***
 *	Error: if client isnt connected or client is bot or invalid attribute
***/
native any Abilities2_GetClientAttribute(int client, const char[] attribute)

// Use this bcs of calculating issues with "any" type
stock float Abilities2_GetClientAttributeFloat(int client, const char[] attribute)
{
	return Abilities2_GetClientAttribute(client, attribute)
}

stock int Abilities2_GetClientAttributeInt(int client, const char[] attribute)
{
	return Abilities2_GetClientAttribute(client, attribute)
}

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
	MarkNativeAsOptional("Abilities2_RegisterAttribute");
	MarkNativeAsOptional("Abilities2_RemoveAttribute");
	MarkNativeAsOptional("Abilities2_GetClientAttribute");
}
#endif