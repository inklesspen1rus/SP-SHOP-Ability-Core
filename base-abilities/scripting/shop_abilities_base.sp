#include <sdkhooks>
#include <sdktools>
#include <shop>
#include <shop_abilities>
#undef REQUIRE_PLUGIN
#include <effectcalc>

bool gECalc
int offs_Alpha
Handle gPlayerSpawnTimer[MAXPLAYERS + 1]

Handle fGetMaxHealth

bool ecalc_mult_another

public void OnPluginStart()
{
	GameData game = new GameData("sdkhooks.games")
	int offset = game.GetOffset("GetMaxHealth")
	game.Close()
	if(offset != -1)
	{
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetVirtual(offset)
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain)
		fGetMaxHealth = EndPrepSDKCall()
	}
	
	ConVar cvar = FindConVar("sv_disable_immunity_alpha")
	cvar.BoolValue = true
	cvar.AddChangeHook(LockImmunityAlpha)
	
	offs_Alpha		= FindSendPropInfo("CBaseEntity", "m_clrRender") + 3
	OnLibraryRemoved("effectcalc")
	CreateTimer(1.0, RegenerationTimer, _, TIMER_REPEAT)
	
	HookEvent("player_spawn", PlayerSpawn)
	
	CreateConVar("cvar_ecalc_mult", "0", "Use another multiplier for Effect Calculator (it will multiple effects, not sum)", _, true, 0.0, true, 1.0).AddChangeHook(UpdateECalcMult)
	AutoExecConfig(true, "abilities_base", "shop")
}

public void UpdateECalcMult(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	ECalc_UnhookAll()
	ecalc_mult_another = cvar.BoolValue
	ECalc_HookAll()
}

public void LockImmunityAlpha(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	if(strcmp(newvalue, "1"))
		cvar.BoolValue = true
}

// Reset gravity for all players
public void RoundPrestart(Event event, const char[] name, bool dbc)
{
	for(int i = MaxClients;i;i--)
		if(IsClientInGame(i))
			SetEntityGravity(i, 1.0)
}

public void PlayerSpawn(Event event, const char[] name, bool dbc)
{
	int userid = event.GetInt("userid")
	int client = GetClientOfUserId(userid)
	if(!client)
		return
	
	if(gPlayerSpawnTimer[client])
		KillTimer(gPlayerSpawnTimer[client])
	gPlayerSpawnTimer[client] = CreateTimer(0.25, ApplyPlayerEffects, userid)
}

public Action ApplyPlayerEffects(Handle timer, int client)
{
	client = GetClientOfUserId(client)
	if(!client)
		return
	gPlayerSpawnTimer[client] = INVALID_HANDLE
	if(!IsFakeClient(client) && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", GetClientArmor(client) + Abilities2_GetClientAttributeInt(client, "armor"))
		if(gECalc)
			return
		SetEntityHealth(client, GetMaxHealth(client))
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") + Abilities2_GetClientAttributeFloat(client, "speed"))
		SetEntityGravity(client, 1.0 / (Abilities2_GetClientAttributeFloat(client, "gravity") + 1.0))
		CalculateInvis(client)
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "abilities2"))
	{
		Abilities2_RegisterAttribute("damage", 0)
		Abilities2_RegisterAttribute("dmgresist", 0)
		Abilities2_RegisterAttribute("invis", 0)
		Abilities2_RegisterAttribute("speed", 0)
		Abilities2_RegisterAttribute("gravity", 0)
		Abilities2_RegisterAttribute("health", 0)
		Abilities2_RegisterAttribute("reload", 0)
		Abilities2_RegisterAttribute("armor", 2)
		Abilities2_RegisterAttribute("regen_hp", 2)
		Abilities2_RegisterAttribute("regen_armor", 2)
		Abilities2_RegisterAttribute("credits", 0)
	}
	else if(!strcmp(name, "effectcalc"))
	{
		gECalc = true
		
		UnhookEvent("round_prestart", RoundPrestart)
		
		for(int i = MaxClients;i;i--)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage)
				if(!IsFakeClient(i))
				{
					SDKUnhook(i, SDKHook_GroundEntChangedPost, GroundEntChangedPost)
					SDKUnhook(i, SDKHook_GetMaxHealth, OnGetMaxHealth)
				}
			}
		}
		
		char sBuffer[8]
		for(int i = MaxClients+1;i!=2049;i++)
		{
			if(IsValidEntity(i))
			{
				GetEntityClassname(i, sBuffer, sizeof sBuffer)
				if(!strcmp(sBuffer, "weapon_"))
				{
					SDKUnhook(i, SDKHook_ReloadPost, WeaponReloadPost)
				}
			}
		}
		
		ECalc_HookAll()
	}
}

void ECalc_UnhookAll()
{
	char sBuffer[8]
	sBuffer = ecalc_mult_another ? "shop" : "base"
	ECalc_Hook("damage", sBuffer, ModifyDamage, true)
	ECalc_Hook("dmgresist", sBuffer, ModifyDMGResist, true)
	ECalc_Hook("invis", sBuffer, ModifyInvis, true)
	ECalc_Hook("speed", sBuffer, ModifySpeed, true)
	ECalc_Hook("gravity", sBuffer, ModifyGravity, true)
	ECalc_Hook("health", sBuffer, ModifyHealth, true)
	ECalc_Hook("reload", sBuffer, ModifyReload, true)
}

void ECalc_HookAll()
{
	char sBuffer[8]
	sBuffer = ecalc_mult_another ? "shop" : "base"
	ECalc_Hook("damage", sBuffer, ModifyDamage)
	ECalc_Hook("dmgresist", sBuffer, ModifyDMGResist)
	ECalc_Hook("invis", sBuffer, ModifyInvis)
	ECalc_Hook("speed", sBuffer, ModifySpeed)
	ECalc_Hook("gravity", sBuffer, ModifyGravity)
	ECalc_Hook("health", sBuffer, ModifyHealth)
	ECalc_Hook("reload", sBuffer, ModifyReload)
}

public void OnClientPutInServer(int client)
{
	gPlayerSpawnTimer[client] = INVALID_HANDLE
	if(!gECalc)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage)
		if(!IsFakeClient(client))
		{
			SDKHook(client, SDKHook_GroundEntChangedPost, GroundEntChangedPost)
			SDKHook(client, SDKHook_GetMaxHealth, OnGetMaxHealth)
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(0 < entity < 2049 && !strncmp(classname, "weapon_", 7))
	{
		SDKHook(entity, SDKHook_ReloadPost, WeaponReloadPost)
	}
}

public void GroundEntChangedPost(int client)
{
	if(IsFakeClient(client))
	SetEntityGravity(client, 1.0 / (Abilities2_GetClientAttributeFloat(client, "gravity") + 1.0))
}

public void OnLibraryRemoved(const char[] name)
{
	if(!strcmp(name, "effectcalc"))
	{
		gECalc = false
		
		HookEvent("round_prestart", RoundPrestart)
		
		for(int i = MaxClients;i;i--)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage)
				if(!IsFakeClient(i))
				{
					SDKHook(i, SDKHook_GroundEntChangedPost, GroundEntChangedPost)
					SDKHook(i, SDKHook_GetMaxHealth, OnGetMaxHealth)
				}
			}
		}
		
		char sBuffer[8]
		for(int i = MaxClients+1;i!=2049;i++)
		{
			if(IsValidEntity(i))
			{
				GetEntityClassname(i, sBuffer, sizeof sBuffer)
				if(!strcmp(sBuffer, "weapon_"))
				{
					SDKHook(i, SDKHook_ReloadPost, WeaponReloadPost)
				}
			}
		}
	}
}

public Action OnGetMaxHealth(int entity, int& maxhealth)
{
	maxhealth = RoundToCeil(float(maxhealth) * (Abilities2_GetClientAttributeFloat(entity, "health") + 1.0))
	return Plugin_Changed
}

public void WeaponReloadPost(int weapon, bool success)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwner")
	if(owner == -1)
		return
	
	float value = Abilities2_GetClientAttributeFloat(owner, "reload")
	if(!value)
		return
	
	value += 1.0
	float curgametime = GetGameTime()
	SetEntPropFloat(owner, Prop_Send, "m_flNextAttack", curgametime+(GetEntPropFloat(owner, Prop_Send, "m_flNextAttack")-curgametime)/value)
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", curgametime+(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack")-curgametime)/value)
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", curgametime+(GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack")-curgametime)/value)
	
	int viewmodel = GetEntPropEnt(owner, Prop_Send, "m_hViewModel")
	if(viewmodel != -1)
		SetEntPropFloat(viewmodel, Prop_Send, "m_flPlaybackRate", value)
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(0 < attacker <= MaxClients && !IsFakeClient(attacker))
		damage *= (Abilities2_GetClientAttributeFloat(attacker, "damage") + 1.0)
	if(!IsFakeClient(victim))
		damage /= (Abilities2_GetClientAttributeFloat(victim, "dmgresist") + 1.0)
	return Plugin_Changed
}

void CalculateInvis(int client)
{
	SetEntityRenderMode(client, RENDER_TRANSALPHA)
	if(gECalc)
	{
		int data[1]
		data[0] = client
		SetEntData(client, offs_Alpha, RoundToCeil(255.0/ECalc_Run2("invis", data, 1)), 1, true)
	}
	else
		SetEntData(client, offs_Alpha, RoundToCeil(255.0/(Abilities2_GetClientAttributeFloat(client, "invis") + 1.0)), 1, true)
}

public void Abilities2_AttributeChanged(const char[] attribute, int client, float oldvalue, float newvalue)
{
	if(!IsPlayerAlive(client))
		return
	if(!strcmp(attribute, "invis"))
		CalculateInvis(client)
	else if(!strcmp(attribute, "speed"))
	{
		if(!gECalc)
		{
			if(!gPlayerSpawnTimer[client])
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") + (newvalue - oldvalue))
		}
		else
		{
			int data[1]
			data[0] = client
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", ECalc_Run2("speed", data, 1))
		}
	}
	else if(!strcmp(attribute, "gravity"))
	{
		if(!gECalc)
		{
			if(!gPlayerSpawnTimer[client])
				SetEntityGravity(client, 1.0 / (newvalue + 1.0))
		}
		else
		{
			int data[1]
			data[0] = client
			SetEntityGravity(client, 1.0/ECalc_Run2("gravity", data, 1))
		}
	}
}

public Action RegenerationTimer(Handle timer)
{
	int cur
	int max
	int regen
	for(int i = MaxClients;i;i--)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && !gPlayerSpawnTimer[i])
		{
			regen = Abilities2_GetClientAttributeInt(i, "regen_hp")
			if(regen)
			{
				cur = GetClientHealth(i)
				max = GetMaxHealth(i)
				if(cur < max)
				{
					cur += regen
					SetEntityHealth(i, (cur > max) ? max : cur)
				}
			}
			
			regen = Abilities2_GetClientAttributeInt(i, "regen_armor")
			if(regen)
			{
				cur = GetClientArmor(i)
				max = 100 + Abilities2_GetClientAttributeInt(i, "armor")
				if(cur < max)
				{
					cur += regen
					SetEntProp(i, Prop_Send, "m_ArmorValue", (cur > max) ? max : cur)
				}
			}
		}
	}
}

int GetMaxHealth(int client)
{
	if(fGetMaxHealth != INVALID_HANDLE)
		return SDKCall(fGetMaxHealth, client)
	return 100 + RoundToCeil(Abilities2_GetClientAttributeFloat(client, "health")*100.0)
}

public Action Shop_OnCreditsGiven(int client, int &credits, int by_who)
{
	if(by_who == CREDITS_BY_NATIVE)
	{
		credits *= (Abilities2_GetClientAttributeFloat(client, "credits") + 1.0)
		return Plugin_Changed
	}
	return Plugin_Continue
}

public void ModifyDamage(any[] data, int size, float &value)
{
	if(0 < data[1] <= MaxClients && !IsFakeClient(data[1]))
		value += Abilities2_GetClientAttributeFloat(data[1], "damage")
}
public void ModifyDMGResist(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "dmgresist")
}
public void ModifyInvis(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "invis")
}
public void ModifySpeed(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "speed")
}
public void ModifyGravity(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "gravity")
}
public void ModifyHealth(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "health")
}
public void ModifyReload(any[] data, int size, float &value)
{
	if(0 < data[0] <= MaxClients && !IsFakeClient(data[0]))
		value += Abilities2_GetClientAttributeFloat(data[0], "reload")
}