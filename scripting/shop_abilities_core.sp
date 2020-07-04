#include <shop>

public Plugin myinfo = {
	name = "[SHOP] Abilities Core 2",
	author = "inklesspen",
	description = "Fully rewrited and new-styled code abilities core",
	version = "0.1"
}

GlobalForward fwOnAttributeChange

ArrayList gAttributeValues[MAXPLAYERS + 1]
ArrayList gAttributeNames
ArrayList gAttributeType
StringMap gAttributeNameMap
/*
percent		- 0
float		- 1
int			- 2
*/

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int max)
{
	RegPluginLibrary("abilities2")
	
	CreateNative("Abilities2_RegisterAttribute", Native_Register)
	CreateNative("Abilities2_RemoveAttribute", Native_Remove)
	CreateNative("Abilities2_GetClientAttribute", Native_GetClientAttribute)
}

public any Native_GetClientAttribute(Handle plugin, int num)
{
	int client = GetNativeCell(1)
	if(IsClientConnected(client))
	{
		ThrowNativeError(0, "Client#%i is not connected", client)
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
	{
		ThrowNativeError(0, "Attribute \"%s\" already exists", sBuffer)
		return -1
	}
	
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
		if(IsClientConnected(i))
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
				AttrubiteChanged(sBuffer, i, 0, value)
		}
	}
	items.Close()
	return index
}

public void OnClientConnected(int client)
{
	if(gAttributeValues[client])
		gAttributeValues[client].Close()
	gAttributeValues[client] = new ArrayList(1)
	for(int i = gAttributeNames.Length;i;i--)
		gAttributeValues[client].Push(0)
}

public any Native_Remove(Handle plugin, int num)
{
	char sBuffer[32]
	GetNativeString(1, sBuffer, sizeof sBuffer)
	int index
	if(!gAttributeNameMap.GetValue(sBuffer, index))
	{
		ThrowNativeError(0, "Attribute \"%s\" doesn't exists exists", sBuffer)
		return
	}
	
	gAttributeNames.Erase(index)
	gAttributeType.Erase(index)
	for(int i = MaxClients;i;i--)
		if(IsClientConnected(i))
			gAttributeValues[i].Erase(index)
}

public void OnPluginStart()
{
	gAttributeNames = new ArrayList(ByteCountToCells(32))
	gAttributeType = new ArrayList(1)
	gAttributeNameMap = new StringMap()
	fwOnAttributeChange = new GlobalForward("Abilities2_AttributeChanged", ET_Ignore, Param_String, Param_Cell, Param_Cell, Param_Cell) // name client oldvalue newvalue
	
	LoadTranslations("shop_abilities.phrases")
}

any GetItemAttribute(ItemId item, const char[] attribute, int type)
{
	if(type != 2)
		return Shop_GetItemCustomInfoFloat(item, attribute)
	return Shop_GetItemCustomInfo(item, attribute)
}

void AttrubiteChanged(const char[] name, int client, any oldValue, any newValue)
{
	Call_StartForward(fwOnAttributeChange)
	Call_PushString(name)
	Call_PushCell(client)
	Call_PushCell(oldValue)
	Call_PushCell(newValue)
	Call_Finish()
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
	if((toggle == Toggle_On) != Shop_IsClientItemToggled(client, item_id)) // WTF???
		return
	
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
		AttrubiteChanged(sBuffer, client, oldvalue, value)
	}
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
	if(Shop_GetItemType(item_id) != Item_Togglable)
		return false
	
	char sBuffer[32]
	char sBuffer2[48]
	float value
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
			case 0: FormatEx(buffer[len], maxlength - len, "\n+%0.1f%% %s", value*100.0, sBuffer2)
		}
		len += strlen(buffer[len])
	}
	return changed
}

// public void Shop_OnAuthorized(int client)
// {
	// ArrayList items = new ArrayList(1)
	// int size = Shop_FillArrayByItems(items)
	// if(!size)
		// return
	// ItemId item
	
	// for(int g = items.Length-1;g!=-1;g--)
	// {
		// item = view_as<ItemId>(items.Get(g))
		// if(Shop_IsClientHasItem(client, item) && Shop_IsClientItemToggled(client, item))
		// {
			// Shop_OnItemToggled(client, INVALID_CATEGORY, "", item, "", Toggle_On)
		// }
	// }
// }