#include <shop>

public Plugin myinfo = {
	name = "[SHOP] Abilities Core 2",
	author = "inklesspen",
	description = "Fully rewrited and new-styled code abilities core",
	version = "2.2a"
}

GlobalForward fwOnAttributeChange

ArrayList gPlayerItems[MAXPLAYERS + 1]
ArrayList gAttributeValues[MAXPLAYERS + 1]
ArrayList gAttributeNames
ArrayList gAttributeType
StringMap gAttributeNameMap

StringMap gCustomInfo
/*
percent		- 0
float		- 1
int			- 2
*/

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int max)
{
	RegPluginLibrary("abilities2")
	
	CreateNative("Abilities2_RegisterAttribute", Native_Register)
	CreateNative("Abilities2_GetClientAttribute", Native_GetClientAttribute)
}

public any Native_GetClientAttribute(Handle plugin, int num)
{
	int client = GetNativeCell(1)
	if(!IsClientConnected(client))
	{
		ThrowNativeError(0, "Client#%i is not connected", client)
		return 0
	}
	
	if(IsFakeClient(client))
	{
		ThrowNativeError(0, "Client#%i is bot", client)
		return 0
	}
	
	char sBuffer[32]
	GetNativeString(2, sBuffer, sizeof sBuffer)
	int index
	if(!gAttributeNameMap.GetValue(sBuffer, index))
	{
		ThrowNativeError(0, "Attribute \"%s\" doesn't exists exists", sBuffer)
		return 0
	}
	
	return gAttributeValues[client].Get(index)
}

public any Native_Register(Handle plugin, int num)
{
	char sBuffer[32]
	int index
	GetNativeString(1, sBuffer, sizeof sBuffer)
	if(gAttributeNameMap.GetValue(sBuffer, index))
		return index
	
	int type = GetNativeCell(2)
	
	index = gAttributeNames.PushString(sBuffer)
	gAttributeType.Push(type)
	gAttributeNameMap.SetValue(sBuffer, index)
	
	ArrayList items = new ArrayList(1)
	int size = Shop_FillArrayByItems(items)
	ItemId item
	if(!size)
		return -1
	any value
	
	// Clear array from non-togglable and without attribute items
	for(int i = 0;i!=size;i++)
	{
		item = view_as<ItemId>(items.Get(i))
		if(Shop_GetItemType(item) != Item_Togglable || !GetItemAttribute(item, sBuffer, type))
		{
			items.Erase(i)
			i--
			size--
		}
	}
	
	// Calculate values for players
	for(int i = MaxClients;i;i--)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			
			value = 0
			if(Shop_IsAuthorized(i))
			{
				for(int g = items.Length-1;g!=-1;g--)
				{
					item = view_as<ItemId>(items.Get(g))
					if(Shop_IsClientHasItem(i, item) && Shop_IsClientItemToggled(i, item))
					{
						if(type != 2)
							view_as<float>(value) += view_as<float>(GetItemAttribute(item, sBuffer, type))
						else
							view_as<int>(value) += view_as<int>(GetItemAttribute(item, sBuffer, type))
					}
				}
			}
			gAttributeValues[i].Push(value)
			if(value)
				AttrubiteChanged(sBuffer, i, 0, value, type)
		}
	}
	items.Close()
	return index
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return
	if(gAttributeValues[client])
		gAttributeValues[client].Close()
	if(gPlayerItems[client])
		gPlayerItems[client].Close()
	gPlayerItems[client] = new ArrayList(1)
	gAttributeValues[client] = new ArrayList(1)
	for(int i = gAttributeNames.Length;i;i--)
		gAttributeValues[client].Push(0)
}

public void OnPluginStart()
{
	gAttributeNames = new ArrayList(ByteCountToCells(32))
	gAttributeType = new ArrayList(1)
	gAttributeNameMap = new StringMap()
	fwOnAttributeChange = new GlobalForward("Abilities2_AttributeChanged", ET_Ignore, Param_String, Param_Cell, Param_Float, Param_Float) // name client oldvalue newvalue
	gCustomInfo = new StringMap()
	
	OnMapStart()
	
	RegServerCmd("sm_abilities_core_dump_items", DumpItemsCMD)
	
	LoadTranslations("shop_abilities.phrases")
}

public Action DumpItemsCMD(int args)
{
	File output
	ItemId iid
	CategoryId cid
	char sBuffer[96]
	ArrayList list
	
	output = OpenFile("addons/sourcemod/data/shop_items_output.ini", "w")
	output.WriteLine("Category :: Item")
	list = new ArrayList(1)
	Shop_FillArrayByItems(list)
	for(int i = list.Length-1;i!=-1;i--)
	{
		iid = list.Get(i)
		cid = Shop_GetItemCategoryId(iid)
		if(cid == INVALID_CATEGORY)
			sBuffer[0] = 0
		else
			Shop_GetCategoryById(cid, sBuffer, sizeof sBuffer)
		output.WriteString(sBuffer, false)
		sBuffer = " :: "
		Shop_GetItemById(iid, sBuffer[4], sizeof sBuffer - 4)
		output.WriteLine(sBuffer)
	}
	
	PrintToServer("Items successfully dumped info \"addons/sourcemod/data/shop_items_output.ini\"")
	list.Close()
	output.Close()
}

any GetItemAttribute(ItemId item, const char[] attribute, int type)
{
	static char sBuffer[64]
	static StringMap map
	static CategoryId cid
	static float value
	static int k;
	
	cid = Shop_GetItemCategoryId(item)
	if(cid != INVALID_CATEGORY)
	{
		Shop_GetCategoryById(cid, sBuffer, sizeof sBuffer)
		k = strlen(sBuffer);
		sBuffer[k++] = '\n';
		Shop_GetItemById(item, sBuffer[k], sizeof sBuffer - k);
		if(gCustomInfo.GetValue(sBuffer, map))
		{
			if(map.GetValue(attribute, value))
			{
				if(type != 2)
					return value
				return RoundToZero(value)
			}
		}
	}
	
	if(type != 2)
		return Shop_GetItemCustomInfoFloat(item, attribute)
	return Shop_GetItemCustomInfo(item, attribute)
}

void AttrubiteChanged(const char[] name, int client, any oldValue, any newValue, int type)
{
	Call_StartForward(fwOnAttributeChange)
	Call_PushString(name)
	Call_PushCell(client)
	Call_PushFloat(type != 2 ? oldValue : float(view_as<int>(oldValue)))
	Call_PushFloat(type != 2 ? newValue : float(view_as<int>(newValue)))
	Call_Finish()
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
	int pos = gPlayerItems[client].FindValue(item_id)
	bool add = toggle == Toggle_On
	if(pos != -1 == add)
		return
	if(add)
		gPlayerItems[client].Push(item_id)
	else
		gPlayerItems[client].Erase(pos)
	
	char sBuffer[32]
	any value
	any oldvalue
	int type
	for(int i = gAttributeNames.Length-1;i!=-1;i--)
	{
		gAttributeNames.GetString(i, sBuffer, sizeof sBuffer)
		type = gAttributeType.Get(i)
		value = GetItemAttribute(item_id, sBuffer, type)
		if(!value)
			continue
		
		if(toggle == Toggle_Off)
		{
			if(type != 2 )
				view_as<float>(value) *= -1.0
			else
				view_as<int>(value) *= -1
				
		}
		
		oldvalue = gAttributeValues[client].Get(i)
		if(type != 2)
			view_as<float>(value) += view_as<float>(oldvalue)
		else
			view_as<int>(value) += view_as<int>(oldvalue)
			
		gAttributeValues[client].Set(i, value)
		AttrubiteChanged(sBuffer, client, oldvalue, value, type)
	}
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
	if(Shop_GetItemType(item_id) != Item_Togglable)
		return false
	
	char sBuffer[32]
	char sBuffer2[48]
	any value
	bool changed = false
	int len = strlen(buffer)
	int type
	
	SetGlobalTransTarget(client)
	for(int i = gAttributeNames.Length-1;i!=-1;i--)
	{
		gAttributeNames.GetString(i, sBuffer, sizeof sBuffer)
		type = gAttributeType.Get(i)
		value = GetItemAttribute(item_id, sBuffer, type)
		if(!value)
			continue
		
		if(!changed)
		{
			changed = true
			len += strcopy(buffer[len], maxlength - len, "\n ")
		}
		
		if(TranslationPhraseExists(sBuffer))
			FormatEx(sBuffer2, sizeof sBuffer2, "%t", sBuffer)
		else
			strcopy(sBuffer2, sizeof sBuffer2, sBuffer)
		
		switch(type)
		{
			case 2: FormatEx(buffer[len], maxlength - len, "\n+%i %s", value, sBuffer2)
			case 1: FormatEx(buffer[len], maxlength - len, "\n+%0.1f %s", value, sBuffer2)
			case 0: FormatEx(buffer[len], maxlength - len, "\n+%0.1f%% %s", view_as<float>(value)*100.0, sBuffer2)
		}
		len += strlen(buffer[len])
	}
	return changed
}

public void OnMapStart()
{
	StringMap item
	StringMapSnapshot snap
	char sBuffer[512]
	char sBuffer2[512]
	KeyValues kv
	float value
	
	//Clear old data
	snap = gCustomInfo.Snapshot()
	for(int i = snap.Length-1;i!=-1;i--)
	{
		snap.GetKey(i, sBuffer, sizeof sBuffer);
		gCustomInfo.GetValue(sBuffer, item);
		item.Close();
	}
	gCustomInfo.Clear()
	snap.Close()
	
	//Russian Matryoshka
	kv = new KeyValues("items")
	kv.ImportFromFile("addons/sourcemod/configs/shop/custom_info.ini")
	kv.Rewind()
	if(kv.GotoFirstSubKey(true))
	{
		int k;
		do	{
			kv.GetSectionName(sBuffer, sizeof sBuffer);
			k = strlen(sBuffer);
			sBuffer[k++] = '\n';
			if(kv.GotoFirstSubKey(true))
			{
				do	{
					kv.GetSectionName(sBuffer[k], sizeof sBuffer - k);
					item = new StringMap();
					gCustomInfo.SetValue(sBuffer, item);
					if(kv.GotoFirstSubKey(false))
					{
						do	{
							kv.GetSectionName(sBuffer2, sizeof sBuffer2);
							value = kv.GetFloat(NULL_STRING);
							if(value)	item.SetValue(sBuffer2, value);
						}
						while(kv.GotoNextKey(false))
						kv.GoBack();
					}
				}
				while(kv.GotoNextKey(true))
				kv.GoBack();
			}
		}
		while(kv.GotoNextKey(true))
	}
	kv.Close()
}