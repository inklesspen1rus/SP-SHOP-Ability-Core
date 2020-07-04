#include <shop_abilities>
#undef PLUGIN_REQUIRE
#include <effectcalc>

bool gECalc

enum MyConVars
{
	CVAR_ENABLE_SPEED,
	CVAR_ENABLE_GRAVITY,
	CVAR_ENABLE_DAMAGE,
	CVAR_ENABLE_DMGRESIST,
	CVAR_ENABLE_CREDITS,
	CVAR_ENABLE_GRAVITY,
}

ConVar gConVar[sizeof MyConVars]

public void OnPluginStart()
{
	
}

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "abilities2"))
	{
		Abilities2_RegisterAttribute("speed", 0)
	}
	else if(!strcmp(name, "effectcalc"))
	{
		gECalc = true
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(!strcmp(name, "effectcalc"))
	{
		gECalc = false
	}
}

public OnPluginEnd()
{
	if(LibraryExists("abilities2"))
		Abilities2_RemoveAttribute("speed")
}

public void Abilities2_AttributeChanged(const char[] attribute, int client, any oldvalue, any newvalue)
{
	
}