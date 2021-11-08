#include <shop>

#pragma newdecls required
#pragma semicolon 1

#define FLOAT_PRECISION 10000
#define DEBUG

public Plugin myinfo = {
	name = "[SHOP] Abilities Core 2",
	author = "inklesspen",
	description = "Fully rewrited and new-styled code abilities core",
	version = "2.3.3"
}

GlobalForward fwOnAttributeChange;
GlobalForward fwOnAttributeBlock;

ArrayList gAttributeNames;
ArrayList gAttributeType;
StringMap gAttributeNameMap;

StringMap gCustomInfo;
/*
percent		- 0
float		- 1
int			- 2
*/

enum struct Player
{
	int index;
	ArrayList items;
	ArrayList values;
	ArrayList enable;

	void Alloc(int index)
	{
		this.index = index;
		this.items = new ArrayList(1);
		this.values = new ArrayList(1);
		this.enable = new ArrayList(1);
	}

	any Value(int attribute_id)
	{
		return this.values.Get(attribute_id);
	}

	any ValueAPI(int attribute_id)
	{
		if(this.enable.Get(attribute_id))
			return this.values.Get(attribute_id);
		return 0;
	}

	void ChangeNotice(int index, any oldValue, any value)
	{
		char sBuffer[32];
		gAttributeNames.GetString(index, sBuffer, sizeof sBuffer);
		AttrubiteChanged(sBuffer, this.index, oldValue, value, gAttributeType.Get(index));
	}

	void SetValue(int attribute_id, any value)
	{
		any oldvalue = this.ValueAPI(attribute_id);
		this.values.Set(attribute_id, value);
		value = this.ValueAPI(attribute_id);
		this.ChangeNotice(attribute_id, oldvalue, value);
	}

	void RegisterNewAttribute(int index, any value)
	{
		this.values.Push(value);
		Action res = Plugin_Continue;
		Call_StartForward(fwOnAttributeBlock);
		Call_PushCell(this.index);
		Call_PushCell(index);
		Call_Finish(res);
		bool enable = res < Plugin_Handled;
		this.enable.Push(enable);
		if(enable)
		{
			this.ChangeNotice(index, 0, value);
		}
	}

	void Connect()
	{
		this.values.Clear();
		this.items.Clear();
		this.enable.Clear();

		int size = gAttributeNames.Length;

		this.enable.Resize(size);
		this.values.Resize(size);

		for(int i = 0;i<size;++i)
		{
			this.values.Set(i, 0);
			this.enable.Set(i, 1);
		}
	}

	void Disconnect()
	{

	}

	void UpdateData()
	{
		char sBuffer[32];
		Action res;
		bool enable, oldenable;
		any value;
		for(int i = gAttributeNames.Length - 1; i != -1; --i)
		{
			res = Plugin_Continue;
			Call_StartForward(fwOnAttributeBlock);
			Call_PushCell(this.index);
			Call_PushCell(i);
			Call_Finish(res);
			oldenable = this.enable.Get(i);
			enable = res < Plugin_Handled;
			if(oldenable != enable)
			{
				//void AttrubiteChanged(const char[] name, int client, any oldValue, any newValue, int type)
				this.enable.Set(i, enable);
				value = this.Value(i);
				gAttributeNames.GetString(i, sBuffer, sizeof sBuffer);
				AttrubiteChanged(sBuffer, this.index, enable ? 0 : value, enable ? value : 0, gAttributeType.Get(i));
			}
		}
	}

	bool HasItem(ItemId id)
	{
		return this.items.FindValue(id) != -1;
	}

	bool SwitchItem(ItemId id, bool remove)
	{
		int pos = this.items.FindValue(id);
		if(remove)
		{
			if(pos != -1)
			{
				this.items.Erase(pos);
				return true;
			}
		}
		else
		{
			if(pos == -1)
			{
				this.items.Push(id);
				return true;
			}
		}
		return false;
	}
}

Player gPlayers[MAXPLAYERS + 1];

bool gLate;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int max)
{
	gLate = late;
	RegPluginLibrary("abilities2");
	
	CreateNative("Abilities2_FindAttributeByName", Native_ByName);
	CreateNative("Abilities2_GetAttributeName", Native_GetName);
	CreateNative("Abilities2_GetAttributeType", Native_GetType);
	CreateNative("Abilities2_AttributeCount", Native_Count);
	CreateNative("Abilities2_UpdatePlayer", Native_Refresh);
	CreateNative("Abilities2_RegisterAttribute", Native_Register);
	CreateNative("Abilities2_GetClientAttribute", Native_GetClientAttribute);
	CreateNative("Abilities2_GetClientAttributeEx", Native_GetClientAttributeEx);
}

public any Native_Count(Handle plugin, int num)
{
	return gAttributeNames.Length;
}

public void Shop_OnAuthorized(int client)
{
	if(!IsFakeClient(client))	gPlayers[client].UpdateData();
}

public any Native_GetName(Handle plugin, int num)
{
	int index = GetNativeCell(1);
	if(index < 0 || index >= gAttributeNames.Length)
	{
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Invalid index");
		return;
	}

	char sBuffer[32];
	gAttributeNames.GetString(index, sBuffer, sizeof sBuffer);
	SetNativeString(2, sBuffer, GetNativeCell(3));
}

public any Native_ByName(Handle plugin, int num)
{
	char sBuffer[32];
	GetNativeString(1, sBuffer, sizeof sBuffer);
	StringToLower(sBuffer);
	return gAttributeNames.FindString(sBuffer);
}

public any Native_GetType(Handle plugin, int num)
{
	int index = GetNativeCell(1);
	if(index < 0 || index >= gAttributeNames.Length)
	{
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Invalid index");
		return -1;
	}
	return gAttributeType.Get(index);
}

public any Native_Refresh(Handle plugin, int num)
{
	int client = GetNativeCell(1);
	gPlayers[client].UpdateData();
}

public any Native_GetClientAttributeEx(Handle plugin, int num)
{
	int client = GetNativeCell(1);
	if(!IsClientConnected(client))
	{
		ThrowNativeError(0, "Client#%i is not connected", client);
		return 0;
	}
	
	if(IsFakeClient(client))
	{
		ThrowNativeError(0, "Client#%i is bot", client);
		return 0;
	}
	
	int index = GetNativeCell(2);
	if(index < 0 || index >= gAttributeNames.Length)
	{
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Invalid index");
		return 0;
	}

	return gPlayers[client].ValueAPI(index);
}

public any Native_GetClientAttribute(Handle plugin, int num)
{
	int client = GetNativeCell(1);
	if(!IsClientConnected(client))
	{
		ThrowNativeError(0, "Client#%i is not connected", client);
		return 0;
	}
	
	if(IsFakeClient(client))
	{
		ThrowNativeError(0, "Client#%i is bot", client);
		return 0;
	}
	
	char sBuffer[32];
	GetNativeString(2, sBuffer, sizeof sBuffer);
	StringToLower(sBuffer);
	int index;
	if(!gAttributeNameMap.GetValue(sBuffer, index))
	{
		ThrowNativeError(0, "Attribute \"%s\" doesn't exists exists", sBuffer);
		return 0;
	}
	
	return gPlayers[client].ValueAPI(index);
}

public any Native_Register(Handle plugin, int num)
{
	char sBuffer[32];
	int index;
	GetNativeString(1, sBuffer, sizeof sBuffer);
	StringToLower(sBuffer);
	if(gAttributeNameMap.GetValue(sBuffer, index))
		return index;
	
	int type = GetNativeCell(2);
	
	index = gAttributeNames.PushString(sBuffer);
	gAttributeType.Push(type);
	gAttributeNameMap.SetValue(sBuffer, index);
	
	ArrayList items = new ArrayList(1);
	int size = Shop_FillArrayByItems(items);
	ItemId item;
	if(!size)
		return -1;
	any value;
	
	// Clear array from non-togglable and without attribute items
	for(int i = 0;i!=size;i++)
	{
		item = view_as<ItemId>(items.Get(i));
		if(Shop_GetItemType(item) != Item_Togglable || !GetItemAttribute(item, sBuffer, type))
		{
			items.Erase(i);
			i--;
			size--;
		}
	}
	
	// Calculate values for players
	for(int i = MaxClients;i;i--)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			value = 0;
			if(Shop_IsAuthorized(i))
			{
				for(int g = items.Length-1;g!=-1;g--)
				{
					item = view_as<ItemId>(items.Get(g));
					if(Shop_IsClientHasItem(i, item) && Shop_IsClientItemToggled(i, item))
					{
						if(type != 2)
							view_as<float>(value) = SumFloat(view_as<float>(value), view_as<float>(GetItemAttribute(item, sBuffer, type)));
						else
							view_as<int>(value) += view_as<int>(GetItemAttribute(item, sBuffer, type));
					}
				}
			}
			gPlayers[i].RegisterNewAttribute(index, value);
		}
	}
	items.Close();
	return index;
}

public void OnClientConnected(int client)
{
	gPlayers[client].Connect();
}

public void OnPluginStart()
{
	for(int i = 0;i<sizeof(gPlayers);++i)
	{
		gPlayers[i].Alloc(i);
	}

	gAttributeNames = new ArrayList(ByteCountToCells(32));
	gAttributeType = new ArrayList(1);
	gAttributeNameMap = new StringMap();
	fwOnAttributeChange = new GlobalForward("Abilities2_AttributeChanged", ET_Ignore, Param_String, Param_Cell, Param_Float, Param_Float); // name client oldvalue newvalue
	fwOnAttributeBlock = new GlobalForward("Abilities2_OnCheckEnable", ET_Hook, Param_Cell, Param_Cell); // name client oldvalue newvalue
	gCustomInfo = new StringMap();
	
	OnMapStart();
	
	RegServerCmd("sm_abilities_core_dump_items", DumpItemsCMD);
	
	LoadTranslations("shop_abilities.phrases");
	if(gLate)
	{
		ArrayList list = new ArrayList(1);
		Shop_FillArrayByItems(list);
		int size = list.Length;

		ItemId id;

		for(int d = 0; d < size; ++d)
		{
			id = list.Get(d);

			for(int i = MaxClients; i; --i)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && Shop_IsAuthorized(i) && Shop_IsClientItemToggled(i, id))
				{
					gPlayers[i].SwitchItem(id, false);
				}
			}
		}

		list.Close();
	}
}

public Action DumpItemsCMD(int args)
{
	File output;
	ItemId iid;
	CategoryId cid;
	char sBuffer[96];
	ArrayList list;
	
	output = OpenFile("addons/sourcemod/data/shop_items_output.ini", "w");
	output.WriteLine("Category :: Item");
	list = new ArrayList(1);
	Shop_FillArrayByItems(list);
	for(int i = list.Length-1;i!=-1;i--)
	{
		iid = list.Get(i);
		cid = Shop_GetItemCategoryId(iid);
		if(cid == INVALID_CATEGORY)
			sBuffer[0] = 0;
		else
			Shop_GetCategoryById(cid, sBuffer, sizeof sBuffer);
		output.WriteString(sBuffer, false);
		sBuffer = " :: ";
		Shop_GetItemById(iid, sBuffer[4], sizeof sBuffer - 4);
		output.WriteLine(sBuffer);
	}
	
	PrintToServer("Items successfully dumped info \"addons/sourcemod/data/shop_items_output.ini\"");
	list.Close();
	output.Close();
}

any GetItemAttribute(ItemId item, const char[] attribute, int type)
{
	static char sBuffer[64];
	StringMap map;
	CategoryId cid;
	float value;
	int k;
	
	cid = Shop_GetItemCategoryId(item);
	if(cid != INVALID_CATEGORY)
	{
		Shop_GetCategoryById(cid, sBuffer, sizeof sBuffer);
		k = strlen(sBuffer);
		StringToLower(sBuffer);
		sBuffer[k++] = '\n';
		Shop_GetItemById(item, sBuffer[k], sizeof sBuffer - k);
		if(gCustomInfo.GetValue(sBuffer, map))
		{
			if(map.GetValue(attribute, value))
			{
				if(type != 2)
					return value;
				return RoundToZero(value);
			}
		}
	}
	
	if(type != 2)
		return Shop_GetItemCustomInfoFloat(item, attribute);
	return Shop_GetItemCustomInfo(item, attribute);
}

StringMap GetItemMapOverride(ItemId item)
{
	char sBuffer[96];
	StringMap map = null;
	CategoryId cid;
	int k;
	
	cid = Shop_GetItemCategoryId(item);
	if(cid != INVALID_CATEGORY)
	{
		Shop_GetCategoryById(cid, sBuffer, sizeof sBuffer);
		k = strlen(sBuffer);
		StringToLower(sBuffer);
		sBuffer[k++] = '\n';
		Shop_GetItemById(item, sBuffer[k], sizeof sBuffer - k);
		gCustomInfo.GetValue(sBuffer, map);
	}
	return map;
}

any GetItemAttribute2(ItemId item, const char[] attribute, int type, StringMap themap)
{
	if(themap)
	{
		float value;
		if(themap.GetValue(attribute, value))
		{
			if(type != 2)
				return value;
			return RoundToZero(value);
		}
	}

	if(type != 2)
		return Shop_GetItemCustomInfoFloat(item, attribute);
	return Shop_GetItemCustomInfo(item, attribute);
}

void AttrubiteChanged(const char[] name, int client, any oldValue, any newValue, int type)
{
	Call_StartForward(fwOnAttributeChange);
	Call_PushString(name);
	Call_PushCell(client);
	Call_PushFloat(type != 2 ? oldValue : float(view_as<int>(oldValue)));
	Call_PushFloat(type != 2 ? newValue : float(view_as<int>(newValue)));
	Call_Finish();
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
	if(!gPlayers[client].SwitchItem(item_id, toggle == Toggle_Off))
		return;
	
	char sBuffer[32];
	any value;
	int type;
	StringMap themap = GetItemMapOverride(item_id);
	for(int i = gAttributeNames.Length-1;i!=-1;i--)
	{
		gAttributeNames.GetString(i, sBuffer, sizeof sBuffer);
		type = gAttributeType.Get(i);

		value = GetItemAttribute2(item_id, sBuffer, type, themap);
		if(!value)
			continue;
				
		if(toggle == Toggle_Off)
		{
			if(type != 2 )
				view_as<float>(value) *= -1.0;
			else
				view_as<int>(value) *= -1;
		}
		
		if(type != 2)
			view_as<float>(value) = SumFloat(view_as<float>(gPlayers[client].Value(i)), view_as<float>(value));
		else
			view_as<int>(value) += view_as<int>(gPlayers[client].Value(i));
			
		gPlayers[client].SetValue(i, value);
	}
}

float SumFloat(float a, float b, int presicion = FLOAT_PRECISION)
{
	return float((RoundToZero(a * presicion) + RoundToZero(b * presicion))) / presicion;
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
	if(Shop_GetItemType(item_id) != Item_Togglable)
		return false;
	
	char sBuffer[32];
	char sBuffer2[48];
	any value;
	bool changed = false;
	int len = strlen(buffer);
	int type;
	
	SetGlobalTransTarget(client);
	StringMap themap = GetItemMapOverride(item_id);
	for(int i = gAttributeNames.Length-1;i!=-1;i--)
	{
		gAttributeNames.GetString(i, sBuffer, sizeof sBuffer);
		type = gAttributeType.Get(i);
		value = GetItemAttribute2(item_id, sBuffer, type, themap);
		if(!value)
			continue;
		
		if(!changed)
		{
			changed = true;
			len += strcopy(buffer[len], maxlength - len, "\n ");
		}
		
		if(TranslationPhraseExists(sBuffer))
			FormatEx(sBuffer2, sizeof sBuffer2, "%t", sBuffer);
		else
			strcopy(sBuffer2, sizeof sBuffer2, sBuffer);
		
		switch(type)
		{
			case 2: FormatEx(buffer[len], maxlength - len, "\n+%i %s", value, sBuffer2);
			case 1: FormatEx(buffer[len], maxlength - len, "\n+%0.1f %s", value, sBuffer2);
			case 0: FormatEx(buffer[len], maxlength - len, "\n+%0.1f%% %s", view_as<float>(value)*100.0, sBuffer2);
		}
		len += strlen(buffer[len]);
	}
	return changed;
}

static void _ProcessItem(KeyValues kv, char[] buffer, int max, int cur)
{
	if(!kv.GetSectionName(buffer[cur], max - cur))
		return;
	if(kv.GotoFirstSubKey(false))
	{
		StringToLower(buffer[cur]);
		StringMap themap;
		if(!gCustomInfo.GetValue(buffer, themap))
		{
			themap = new StringMap();
			gCustomInfo.SetValue(buffer, themap);
		}

		do
		{
			char sBuffer[32];
			if(kv.GetSectionName(sBuffer, sizeof sBuffer))
			{
				StringToLower(sBuffer);
				themap.SetValue(sBuffer, kv.GetFloat(NULL_STRING, 0.0));
			}
		}
		while(kv.GotoNextKey(false));
		kv.GoBack();
	}
}

static void _ProcessCategory(KeyValues kv)
{
	char sBuffer[128];
	if(!kv.GetSectionName(sBuffer, sizeof sBuffer))
		return;
	int l = strlen(sBuffer);
	StringToLower(sBuffer);
	sBuffer[l++] = '\n';
	if(kv.GotoFirstSubKey(true))
	{
		do
		{
			_ProcessItem(kv, sBuffer, sizeof sBuffer, l);
		}
		while(kv.GotoNextKey(true));
		kv.GoBack();
	}
}

public void OnMapStart()
{
	StringMap item;
	StringMapSnapshot snap;
	char sBuffer[512];
	KeyValues kv;
	
	//Clear old data
	snap = gCustomInfo.Snapshot();
	for(int i = snap.Length-1;i!=-1;i--)
	{
		snap.GetKey(i, sBuffer, sizeof sBuffer);
		gCustomInfo.GetValue(sBuffer, item);
		item.Close();
	}
	gCustomInfo.Clear();
	snap.Close();
	
	//not the Russian Matryoshka anymore
	kv = new KeyValues("items");
	kv.ImportFromFile("addons/sourcemod/configs/shop/custom_info.ini");
	kv.Rewind();
	if(kv.GotoFirstSubKey(true))
	{
		do	{
			_ProcessCategory(kv);
		}
		while(kv.GotoNextKey(true));
	}
	kv.Close();
}

stock void StringToLower(char[] buffer)
{
	for(int i = 0; buffer[i]; ++i)
	{
		if(IsCharUpper(buffer[i]))
		buffer[i] = CharToLower(buffer[i]);
	}
}