#include <sourcemod>
#include <sdktools_entoutput>

StringMap Entities;
int LastItem[MAXPLAYERS + 1] = {-1, ...}, Ignore[MAXPLAYERS + 1] = {-1, ...};
float LastTime[MAXPLAYERS + 1];
ArrayList IndexIgnoreList, HammerIgnoreList;

public Plugin myinfo = 
{
	name		= "Entity Outputs Info",
	version		= "1.0",
	description	= "",
	author		= "hEl",
	url			= ""
};

public void OnPluginStart()
{
	char szBuffer[256];
	BuildPath(Path_SM, szBuffer, 256, "configs/entity_outputs_info.cfg");
	KeyValues hKeyValues = new KeyValues("Entities");
	
	if(!hKeyValues.ImportFromFile(szBuffer) || !hKeyValues.GotoFirstSubKey())
	{
		SetFailState("Config file \"%s\" not founded", szBuffer);
	}
	
	Entities = new StringMap();
	
	ArrayList hArrayList;
	
	char szBuffer2[256];
	do
	{
		hKeyValues.GetSectionName(szBuffer, 256);
		
		if(!hKeyValues.GotoFirstSubKey(false))
			continue;
			
		hArrayList = new ArrayList(ByteCountToCells(64));
		
		do
		{
			hKeyValues.GetSectionName(szBuffer2, 256);
			hArrayList.PushString(szBuffer2);
			hArrayList.Push(0);
			HookEntityOutput(szBuffer, szBuffer2, OnEntityOutput);
		}
		while(hKeyValues.GotoNextKey(false));
		
		hKeyValues.GoBack();
		Entities.SetValue(szBuffer, view_as<int>(hArrayList));
	}
	while(hKeyValues.GotoNextKey());
	
	delete hKeyValues;
	
	IndexIgnoreList = new ArrayList(32);
	HammerIgnoreList = new ArrayList(32);
	
	RegAdminCmd("sm_otps", Command_EntsOutputs, ADMFLAG_RCON);

}

public Action Command_EntsOutputs(int iClient, int iArgs)
{
	OutputsMenu(iClient);
	return Plugin_Handled;
}



void OutputsMenu(int iClient, int iStartItem = 0)
{
	char szBuffer[256], szBuffer2[256];
	Menu hMenu = new Menu(MenuHandler, MenuAction_End | MenuAction_Select | MenuAction_Cancel);
	hMenu.SetTitle("Output menu");
	hMenu.AddItem("", "[Index ignore list]");
	hMenu.AddItem("", "[Hammer ignore list]");
	StringMapSnapshot hTrieSnapshot = Entities.Snapshot();
	int iLength = hTrieSnapshot.Length, iMode;
	for(int i; i < iLength; i++)
	{
		hTrieSnapshot.GetKey(i, szBuffer, 256);
		iMode = GetEntityMode(szBuffer);
		FormatEx(szBuffer2, 256, "%s [%s]", szBuffer, iMode == 1 ? "✔":iMode == -1 ? "×":"◼");
		hMenu.AddItem(szBuffer, szBuffer2);
	}
	
	delete hTrieSnapshot;
	
	hMenu.DisplayAt(iClient, iStartItem, 0);
}

public int MenuHandler(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Cancel:
		{
			LastItem[iClient] = -1;
			LastTime[iClient] = 0.0;
		}
		case MenuAction_Select:
		{
		
			if(iItem < 2)
			{
				IgnoreListMenu(iClient, iItem);
				Ignore[iClient] = iItem;
			}
			else
			{
				char szBuffer[256];
				hMenu.GetItem(iItem, szBuffer, 256);
				int iMode = GetEntityMode(szBuffer);
				
				float fTime = GetEngineTime();
				if(iMode == 0 || (LastItem[iClient] == iItem && fTime - LastTime[iClient] <= 0.5))
				{
					OutputsMenu2(iClient, iItem - 2, hMenu.Selection);
				}
				else
				{
					LastItem[iClient] = iItem;
					LastTime[iClient] = fTime;
					SetEntityMode(szBuffer, iMode == -1 ? 1:-1);
					OutputsMenu(iClient, hMenu.Selection);
				}
				
			}
		}
	}
}

void OutputsMenu2(int iClient, int iItem, int iStartItem = 0, int iStartItem2 = 0)
{
	char szBuffer[256], szBuffer2[64];
	StringMapSnapshot hTrieSnapshot = Entities.Snapshot();
	hTrieSnapshot.GetKey(iItem, szBuffer, 256);
	delete hTrieSnapshot;
	int iArrayList;
	Entities.GetValue(szBuffer, iArrayList);
	ArrayList hArrayList = view_as<ArrayList>(iArrayList);
	Menu hMenu = new Menu(MenuHandler3, MenuAction_End | MenuAction_Select | MenuAction_Cancel);
	hMenu.SetTitle("Entity outputs menu: %s", szBuffer);
	FormatEx(szBuffer2, 64, "%i_%i", iStartItem, iItem);
	hMenu.AddItem(szBuffer2, "[Toggle All Outputs]");
	
	int iLength = hArrayList.Length;
	
	for(int i; i < iLength; i += 2)
	{
		
		hArrayList.GetString(i, szBuffer, 256);
		Format(szBuffer, 256, "%s [%s]", szBuffer, hArrayList.Get(i + 1) ? "+":"-");
		hMenu.AddItem("", szBuffer);
	}
	
	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iStartItem2, 0);
}

public int MenuHandler3(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		default:
		{
			char szBuffer[256];
			hMenu.GetItem(0, szBuffer, 256);
			int iSymbol = FindCharInString(szBuffer, '_'), iEntId = StringToInt(szBuffer[iSymbol + 1]), iStartItem;
			szBuffer[iSymbol] = 0;
			iStartItem = StringToInt(szBuffer);
			if(action == MenuAction_Cancel)
			{
				if(iItem == MenuCancel_ExitBack)
				{
					OutputsMenu(iClient, iStartItem);
				}
			}
			else
			{
				StringMapSnapshot hTrieSnapshot = Entities.Snapshot();
				hTrieSnapshot.GetKey(iEntId, szBuffer, 256);
				int iArrayList;
				Entities.GetValue(szBuffer, iArrayList);
				ArrayList hArrayList = view_as<ArrayList>(iArrayList);
				delete hTrieSnapshot;
				if(iItem == 0)
				{
					int iLength = hArrayList.Length;
					for(int i; i < iLength; i += 2)
					{
						hArrayList.Set(i + 1, hArrayList.Get(i + 1) ? 0:1);
					}
					
					OutputsMenu2(iClient, iEntId, iStartItem);
				}
				else
				{
					hArrayList.Set((iItem - 1) * 2 + 1, hArrayList.Get((iItem - 1) * 2 + 1) ? 0:1);
					OutputsMenu2(iClient, iEntId, iStartItem, hMenu.Selection);
					
				}
			}
		}
	}
}

void IgnoreListMenu(int iClient, int iIgnoreMode, int iStartItem = 0)
{
	char szBuffer[32], szId[8];
	IntToString(iIgnoreMode, szId, 8);
	Menu hMenu = new Menu(MenuHandler2, MenuAction_End | MenuAction_Select | MenuAction_Cancel);
	hMenu.SetTitle("%s ignore list", iIgnoreMode ? "Hammer":"Index");
	hMenu.AddItem("", "[Clear all]");
	ArrayList hArrayList = GetIgnoreList(iIgnoreMode);
	int iLength = hArrayList.Length;
	for(int i; i < iLength; i++)
	{
		IntToString(hArrayList.Get(i), szBuffer, 32);
		hMenu.AddItem(szId, szBuffer);
	}
	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iStartItem, 0);
}

public int MenuHandler2(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Cancel:
		{
			Ignore[iClient] = -1;
			
			if(iItem == MenuCancel_ExitBack)
			{
				OutputsMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			ArrayList hArrayList = GetIgnoreList(Ignore[iClient]);
			if(!iItem)
			{
				hArrayList.Clear();
				OutputsMenu(iClient);
			}
			else
			{
				hArrayList.Erase(iItem - 1);
				DisplayIgnoreListMenu(iClient);
			}
		}
	}
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidEntity(caller))
		return;
	
	static int Hammer;
	static int iFlags;
	static float fTime;
	static char szBuffer[2][256];
	GetEntityClassname(caller, szBuffer[0], 256);
	
	StringMapSnapshot hTrieSnapshot = Entities.Snapshot();
	int iLength = hTrieSnapshot.Length;
	
	
	for(int i; i < iLength; i++)
	{
		hTrieSnapshot.GetKey(i, szBuffer[1], 256);
		
		if(strcmp(szBuffer[0], szBuffer[1], false))
			continue;
		
		int iArrayList, iIndex;
		Entities.GetValue(szBuffer[1], iArrayList);
		ArrayList hArrayList = view_as<ArrayList>(iArrayList);
		Hammer = GetEntProp(caller, Prop_Data, "m_iHammerID");
		
		if(IndexIgnoreList.FindValue(caller) != -1 || HammerIgnoreList.FindValue((Hammer = GetEntProp(caller, Prop_Data, "m_iHammerID"))) != -1)
		{
			return;
		}
		
		iIndex = hArrayList.FindString(output);
		if(iIndex != -1 && hArrayList.Get(iIndex + 1))
		{
			GetEntPropString(caller, Prop_Data, "m_iName", szBuffer[0], 256);
			fTime = GetEngineTime();
			for(int j = 1; j <= MaxClients; j++)
			{
				if(IsClientInGame(j) && ((iFlags = GetUserFlagBits(j)) & ADMFLAG_RCON || iFlags & ADMFLAG_ROOT))
				{
					PrintToChat(j, "#%i. %s (%i %s) – %s [%.2f]", caller, szBuffer[1], Hammer, szBuffer[0], output, fTime);
				}
			}
			break;
		}
		break;
				
	}
	
	delete hTrieSnapshot;
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] sArgs)
{
	if(Ignore[iClient] != -1)
	{
		
		ArrayList hArrayList = GetIgnoreList(Ignore[iClient]);
		hArrayList.Push(StringToInt(sArgs));
		DisplayIgnoreListMenu(iClient);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void DisplayIgnoreListMenu(int iClient)
{
	int iIgnoreMode = Ignore[iClient];
	IgnoreListMenu(iClient, iIgnoreMode);
	Ignore[iClient] = iIgnoreMode;
}

ArrayList GetIgnoreList(int iIgnoreMode)
{
	return iIgnoreMode ? HammerIgnoreList:IndexIgnoreList;
}

void SetEntityMode(const char[] entity, int iMode)
{
	int iArrayList;
	Entities.GetValue(entity, iArrayList);
	ArrayList hArrayList = view_as<ArrayList>(iArrayList);
	int iLength = hArrayList.Length;
	for(int i; i < iLength; i += 2)
	{
		hArrayList.Set(i + 1, iMode == 1 ? 1:0);
	}
}

int GetEntityMode(const char[] entity)
{
	int iArrayList;
	Entities.GetValue(entity, iArrayList);
	ArrayList hArrayList = view_as<ArrayList>(iArrayList);
	int iLength = hArrayList.Length, iCount;
	for(int i; i < iLength; i += 2)
	{
		if(hArrayList.Get(i + 1))
		{
			iCount++;
		}
	}
	
	return iCount == 0 ? -1:(iCount == iLength / 2) ? 1:0;
}