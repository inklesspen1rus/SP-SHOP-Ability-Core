/***
 * Abilities2_AttributeChanged
 * Runs when any attribute of player was changed
***/
forward void Abilities2_AttributeChanged(const char[] attribute, int client, any oldvalue, any newvalue)

/***
 *	Types:
 *	0 - PERCENT, displays as +100*F%
 *	1 - FLOAT, displays as +F
 *	2 - INT, displays as +N
 *
 *	Error: if attribute already registered
***/
native int Abilities2_RegisterAttribute(const char[] attribute, int type)

/***
 *	Error: if attribute doesnt exists
***/
native void Abilities2_RemoveAttribute(const char[] attribute)

/***
 *	Error: if client isnt connected or invalid attribute
***/
native any Abilities2_GetClientAttribute(int client, const char[] attribute)

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