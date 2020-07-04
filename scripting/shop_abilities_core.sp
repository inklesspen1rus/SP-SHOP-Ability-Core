#include <shop>

enum
{
    Enabled,
    Speed,
    Gravity,
    HP,
    Armor,
    RegenHP,
    RegenArmor,  
    Multiplier,
    ABILITIES
};

#pragma semicolon 1
#pragma newdecls required

#define MAX MAXPLAYERS+1

public Plugin myinfo =
{
    name = "[Abliities] Core",
    author = "asdf",
    version = "1.0",
}

/////////////////////CLIENTVARS///////////////////////
bool    g_bRegen[MAX],g_bSpawned[MAX];
float   g_fSpeed[MAX],g_fGravity[MAX],g_fMultipller[MAX];
int     g_iHP[MAX],g_iMaxHP[MAX],
        g_iArmor[MAX],g_iMaxArmor[MAX],
        g_iRegenHP[MAX],g_iRegenArmor[MAX];
///////////////////////////////////////////////////////

//////////////////////PLUGIN///////////////////////////
bool   g_Enabled[ABILITIES];
Handle g_hTimer;
ConVar g_Cvar[ABILITIES+1];
float  g_fBTime;
KeyValues kv[3];
///////////////////////////////////////////////////////

//////////////////////OFFSETS//////////////////////////
int m_flLaggedMovementValue,                          
    m_iArmorValue,
    m_iHealth;
///////////////////////////////////////////////////////

public void OnPluginStart()
{
    LoadTranslations("shop_abilities.phrases");
    (g_Cvar[Enabled]    = CreateConVar("sm_shop_abilities_enabled",     "1",   "Выдача всех способностей", _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[Speed]      = CreateConVar("sm_shop_abilities_speed",       "1",   "Скорость",                 _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[Gravity]    = CreateConVar("sm_shop_abilities_gravity",     "1",   "Гравитация",               _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[HP]         = CreateConVar("sm_shop_abilities_hp",          "1",   "Хп",                       _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[Armor]      = CreateConVar("sm_shop_abilities_arm",         "1",   "Броня",                    _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[RegenHP]    = CreateConVar("sm_shop_abilities_regen_hp",    "1",   "Реген Хп",                 _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[RegenArmor] = CreateConVar("sm_shop_abilities_regen_armor", "1",   "Реген Брони",              _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[Multiplier] = CreateConVar("sm_shop_abilities_multiplier",  "1",   "Умножение кредитов",       _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
    (g_Cvar[8]          = CreateConVar("sm_shop_abilities_time",        "1.0", "Задержка перед выдачей",   _, true, 0.0, true, 60.0)).AddChangeHook(OnConVarChanged);

    m_iHealth	            = FindSendPropInfo("CCSPlayer", "m_iHealth");
    m_iArmorValue           = FindSendPropInfo("CCSPlayer", "m_ArmorValue");
    m_flLaggedMovementValue = FindSendPropInfo("CCSPlayer", "m_flLaggedMovementValue");

    HookEvent("round_end", End, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Spawn);
    HookEvent("player_death", Death);
    g_hTimer = CreateTimer(1.0,view_as<Timer>(GiveAbilities),_, TIMER_REPEAT);
    if (Shop_IsStarted()) 
        Shop_Started();
    AutoExecConfig(true, "shop_abilities","shop");  
}

public void OnConfigsExecuted()
{
    g_Enabled[Enabled]         = g_Cvar[Enabled].      BoolValue;
    g_Enabled[Speed]           = g_Cvar[Speed].        BoolValue;
    g_Enabled[Gravity]         = g_Cvar[Gravity].      BoolValue;
    g_Enabled[HP]              = g_Cvar[HP].           BoolValue;
    g_Enabled[Armor]           = g_Cvar[Armor].        BoolValue;
    g_Enabled[RegenHP]         = g_Cvar[RegenHP].      BoolValue;
    g_Enabled[RegenArmor]      = g_Cvar[RegenArmor].   BoolValue;
    g_Enabled[Multiplier]      = g_Cvar[Multiplier].   BoolValue;
    g_fBTime                   = g_Cvar[8].         FloatValue;
}

public void OnClientPutInServer(int client)
{
    g_bSpawned[client] = 
    g_bRegen[client] = false;
    g_fSpeed[client] = 
    g_fGravity[client] = 0.0;
    g_fMultipller[client] = 1.0;
    g_iHP[client] = 
    g_iMaxHP[client] = 
    g_iArmor[client] = 
    g_iMaxArmor[client] = 
    g_iRegenHP[client] = 
    g_iRegenArmor[client] = 0;
    SetEntityGravity(client,1.0);
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
    bool t = (toggle == Toggle_On); 
    if((g_fSpeed[client] == 0.0 || g_fGravity[client] == 0.0 || g_iHP[client] == 0 || g_iArmor[client] == 0 || g_fMultipller[client] == 0.0 || g_iRegenHP[client] == 0 || g_iRegenArmor[client] == 0) && !t)
        return;

    int i,a = -1;
    while(i < 3)
    {
        kv[i].Rewind(); 
        i++;
    }

    if(kv[0].JumpToKey(category) && kv[0].JumpToKey(item)) a = 0;

    for(i = 1; i < 3;i++)
        if(kv[i].JumpToKey(item)) a = i;
    if(a == -1) 
    {
        //LogAction(-1, -1, "[Abilities Core] ItemToggled : category %s | item %s | item_id %d",category,item,item_id);
        return;
    }

    g_fSpeed[client]        += kv[a].GetFloat("speed") * (t ? 1.0 : -1.0);
    g_fGravity[client]      += kv[a].GetFloat("gravity") * (t ? -1.0 : 1.0);
    g_iHP[client]           += kv[a].GetNum("hp") * (t ? 1 : -1);
    g_iArmor[client]        += kv[a].GetNum("armor") * (t ? 1 : -1);
    g_fMultipller[client]   += kv[a].GetFloat("multiplier") * (t ? 1.0 : -1.0);
    g_iRegenHP[client]      += kv[a].GetNum("regenhp") * (t ? 1 : -1);
    g_iRegenArmor[client]   += kv[a].GetNum("regenarmor") * (t ? 1 : -1);
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
    char sBuffer[64],sBuffer_[16],category[64],item[64];
    int i,a = -1;
    while(i < 3)
    {
        kv[i].Rewind(); 
        i++;
    }

    Shop_GetCategoryById(category_id, category, 64);
    Shop_GetItemById(item_id, item, 64);

    if(kv[0].JumpToKey(category) && kv[0].JumpToKey(item)) a = 0;

    for(i = 1; i < 3;i++)
        if(kv[i].JumpToKey(item)) a = i;

    if(a == -1) 
    {
        //LogAction(-1, -1, "[Abilities Core] ItemDescription : category %s | item %s | item_id %d",category,item,item_id);
        return false;
    }
    FormatEx(sBuffer,64,"%t","speed");
    Format(buffer,256,"%s: +%.2f%\n",sBuffer,kv[a].GetFloat("speed"));
    FormatEx(sBuffer,64,"%t","gravity");
    Format(buffer,256,"%s%s: -%.2f\n",buffer,sBuffer,kv[a].GetFloat("gravity"));
    FormatEx(sBuffer,64,"%t","hp");
    FormatEx(sBuffer_,64,"%t","regen");
    Format(buffer,256,"%s%s: +%d %s %d\n",buffer,sBuffer,kv[a].GetNum("hp"),sBuffer_,kv[a].GetNum("regenhp")); 
    FormatEx(sBuffer,64,"%t","armor");
    Format(buffer,256,"%s%s: +%d %s %d\n",buffer,sBuffer,kv[a].GetNum("armor"),sBuffer_,kv[a].GetNum("regenarmor"));
    FormatEx(sBuffer,64,"%t","multiplier");
    Format(buffer,256,"%s%s: %.2fx",buffer,sBuffer,kv[a].GetFloat("multiplier"));
    return true;
}

void GiveAbilities() 
{ 
    static int i,o;
    for (i = 1; i <= MaxClients; ++i) if (IsClientInGame(i) && g_bRegen[i] && !IsFakeClient(i) && IsPlayerAlive(i)) 
    {
        if(g_Enabled[RegenHP] && g_iRegenHP[i] > 0) 
        {
            o = GetEntData(i, m_iHealth)+g_iRegenHP[i];
            SetEntData(i, m_iHealth, o >= g_iMaxHP[i] ? g_iMaxHP[i]:o);
        }
        else if(g_Enabled[RegenArmor] && g_iRegenArmor[i] > 0) 
        {
            o = GetEntData(i, m_iArmorValue)+g_iRegenArmor[i];
            SetEntData(i, m_iArmorValue, o >= g_iMaxArmor[i] ? g_iMaxArmor[i]:o);
        }
    }
}

public void Spawn(Event event, char[] name, bool dontBroadcast)
{	
    CreateTimer(g_fBTime,view_as<Timer>(giveab),event.GetInt("userid"));
}

public Action giveab(Handle timer,int client)
{
    client = GetClientOfUserId(client);
    if(client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) <= 1 || g_bSpawned[client]) return;
    g_iMaxHP[client] = GetEntData(client, m_iHealth);
    g_iMaxArmor[client] = GetEntData(client, m_iArmorValue);

    if(g_Enabled[Speed] && g_fSpeed[client] != 0.0)
    {
        SetEntDataFloat(client, m_flLaggedMovementValue, GetEntDataFloat(client,m_flLaggedMovementValue)+g_fSpeed[client], true);
    }
    if(g_Enabled[Gravity] && g_fGravity[client] != 0.0)
    {
        SetEntityGravity(client, GetEntityGravity(client)+g_fGravity[client]);
    }
    if(g_Enabled[HP] && g_iHP[client] != 0)
    {
        g_iMaxHP[client] = g_iMaxHP[client]+g_iHP[client];
        SetEntData(client, m_iHealth, g_iMaxHP[client]);
    }
    if(g_Enabled[Armor] && g_iArmor[client] != 0)
    {
        g_iMaxArmor[client] = g_iMaxArmor[client]+g_iArmor[client];
        SetEntData(client, m_iArmorValue, g_iMaxArmor[client], 4, true);
    }
    g_bSpawned[client] = true;
    CreateTimer(3.0,Fix,client);
}

public Action Fix(Handle timer,int client)
{
    g_bRegen[client] = true;
}

public void End(Event event, char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; ++i) if (IsClientInGame(i)) 
        SetEntityGravity(i,1.0);
}

public void Death(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_bSpawned[client] =
    g_bRegen[client] = false;
    if(client > 0 && IsClientInGame(client))
        SetEntityGravity(client,1.0);  
}

public Action Shop_OnCreditsGiven(int client,int &credits,int by_who)
{
    if(by_who == CREDITS_BY_NATIVE && g_fMultipller[client] > 1.0)
    {
        credits = RoundToCeil(float(credits)*g_fMultipller[client]);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

public void Shop_Started()
{
    char buffer[256];

    kv[0] = CreateKeyValues("Equipments");
    Shop_GetCfgFile(buffer, 256, "equipments.txt");
    if (!FileToKeyValues(kv[0],buffer))
        LogAction(-1, -1, "Couldn't parse file %s", buffer);
    kv[0].Rewind(); 

    kv[1] = CreateKeyValues("Trails");
    Shop_GetCfgFile(buffer, 256, "trails.txt");
    if (!FileToKeyValues(kv[1],buffer))
        LogAction(-1, -1, "Couldn't parse file %s", buffer);
    kv[1].Rewind(); 

    kv[2] = CreateKeyValues("Skins");
    Shop_GetCfgFile(buffer, 256, "skins.txt");
    if (!FileToKeyValues(kv[2],buffer))
        LogAction(-1, -1, "Couldn't parse file %s", buffer);
    kv[2].Rewind(); 
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{ 
    if(convar == g_Cvar[Enabled])
    {
        int i;
        g_Enabled[Enabled] = convar.BoolValue; 
        if(!g_Enabled[Enabled])
        {
            if (g_hTimer != null) 
            { 
                KillTimer(g_hTimer); 
                g_hTimer = null; 
            } 
            for(i = 0; i < ABILITIES;i++)
                g_Enabled[i] = false;
            UnhookEvent("player_spawn", Spawn,EventHookMode_Post);
            UnhookEvent("player_death", Death);
            return;
        }
        if (g_hTimer == null) 
            g_hTimer = CreateTimer(1.0,view_as<Timer>(GiveAbilities),_, TIMER_REPEAT);
        for(i = 0; i < ABILITIES;i++)
            g_Enabled[i] = true;
        HookEvent("player_spawn", Spawn,EventHookMode_Post);
        HookEvent("player_death", Death);
        return;
    }
    if(convar == g_Cvar[Speed])
    {
        g_Enabled[Speed] = convar.BoolValue; 
        return;
    }
    if(convar == g_Cvar[Gravity])
    {
        g_Enabled[Gravity] = convar.BoolValue; 
        return;
    }
    if(convar == g_Cvar[HP])
    {
        g_Enabled[HP] = convar.BoolValue; 
        return;
    }
    if(convar == g_Cvar[Armor])
    {
        g_Enabled[Armor] = convar.BoolValue; 
        return;
    }
    if(convar == g_Cvar[RegenHP])
    {
        g_Enabled[RegenHP] = convar.BoolValue; 
        return;
    }  
    if(convar == g_Cvar[RegenArmor])
    {
        g_Enabled[RegenArmor] = convar.BoolValue; 
        return;
    }  
    if(convar == g_Cvar[Multiplier])
    {
        g_Enabled[Multiplier] = convar.BoolValue; 
        return;
    }  
    if(convar == g_Cvar[8])
    {
        g_fBTime = convar.FloatValue; 
        return;
    }  
}
