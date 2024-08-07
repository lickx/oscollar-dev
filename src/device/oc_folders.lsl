
//  oc_folders.lsl
//
//  Copyright (c) 2008 - 2017 Satomi Ahn, Nandana Singh, Wendy Starfall,
//  Medea Destiny, Romka Swallowtail, littlemousy, Sumi Perl,
//  Garvin Twine et al.
//
//  This script is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published
//  by the Free Software Foundation, version 2.
//
//  This script is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this script; if not, see www.gnu.org/licenses/gpl-2.0
//

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

string g_sParentMenu = "RLV";

string g_sSubMenu = "# Folders";

integer CMD_OWNER = 500;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;

integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer RLV_CMD = 6000;
integer RLV_CLEAR = 6002;
integer RLVA_VERSION = 6004;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string PARENT = "⏎";
string ACTIONS_CURRENT = "Actions";
string ROOT_ACTIONS = "Global Actions";

string UPMENU = "BACK";

string ADD_ALL = "Add all";
string DETACH_ALL = "Detach all";
string ADD = "Add this";
string DETACH = "Detach this";
string LOCK_ATTACH_ALL = "Lock att. all";
string LOCK_DETACH_ALL = "Lock det. all";
string LOCK_ATTACH = "Lock att. this";
string LOCK_DETACH = "Lock det. this";

integer g_iUnsharedLocks; // 2 bits bitfield: first (strong) one for unsharedwear, second (weak) one for unsharedunwear
list g_lFolderLocks; // strided list: folder path, lock type (4 bits field)

integer g_iTimeOut = 60;

integer g_iFolderRLV = 78467;
integer g_iRLVaOn;

integer g_iPage = 0;

list    g_lMenuIDs;
integer g_iMenuStride = 3;

integer g_iListener;

key g_kAsyncMenuUser = NULL_KEY;
integer g_iAsyncMenuAuth;
integer g_iAsyncMenuRequested;

string g_sFolderType;
string g_sCurrentFolder;
string g_sOutfitsFolder = "Outfits";

list g_lSearchList;

integer g_iLastFolderState;

key g_kWearer = NULL_KEY;
string g_sSettingToken = "rlvfolders_";

list g_lHistory;

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenuID)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

addToHistory(string folder)
{
    if (llListFindList(g_lHistory, [folder]) == -1) g_lHistory+=[folder];
    g_lHistory = llList2List(g_lHistory, -10, -1);
}

ParentFolder()
{
    list lFolders = llParseString2List(g_sCurrentFolder, ["/"], []);
    g_iPage = 0;
    if (llGetListLength(lFolders) > 1) {
        g_sCurrentFolder = llList2String(lFolders, 0);
        integer i;
        for (i = 1; i < llGetListLength(lFolders)-1; i++) g_sCurrentFolder+="/"+llList2String(lFolders, i);
    }
    else g_sCurrentFolder = "";
}

QueryFolders(string sType)
{
    g_sFolderType = sType;
    g_iFolderRLV = 9999 + llRound(llFrand(9999999.0));
    g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
    llSetTimerEvent(g_iTimeOut);
    llMessageLinked(LINK_RLV,RLV_CMD, "getinvworn:"+g_sCurrentFolder+"=" + (string)g_iFolderRLV, NULL_KEY);
}

string lockFolderButton(integer iLockState, integer iLockNum, integer iAuth)
{
    string sOut;
    if ((iLockState >> (4 + iLockNum)) & 0x1) sOut = "☔";
    else if ((iLockState >> iLockNum) & 0x1) sOut = "✔";
    else sOut = "✘";
    if (iLockNum == 0) sOut += LOCK_ATTACH;
    else if (iLockNum == 1) sOut += LOCK_DETACH;
    else if (iLockNum == 2) sOut += LOCK_ATTACH_ALL;
    else if (iLockNum == 3) sOut += LOCK_DETACH_ALL;
    if (iAuth > CMD_GROUP) sOut = "("+sOut+")";
    return sOut;
}

string lockUnsharedButton(integer iLockNum, integer iAuth)
{
    string sOut;
    if ((g_iUnsharedLocks >> iLockNum) & 0x1) sOut = "✔";
    else sOut = "✘";
    if (iLockNum == 1) sOut += "Lk Unsh Wear";
    else if  (iLockNum == 0) sOut += "Lk Unsh Remove";
    if (iAuth > CMD_GROUP) sOut = "("+sOut+")";
    return sOut;
}

HistoryMenu(key kAv, integer iAuth)
{
    Dialog(kAv, "\nRecently worn #RLV folders:", g_lHistory, [UPMENU], 0, iAuth, "History");
}

RootActionsMenu(key kAv, integer iAuth)
{
    list lActions = [lockUnsharedButton(0, iAuth), lockUnsharedButton(1, iAuth), "Save", "Restore"];
    string sPrompt = "\nRLV Folders\n\nYou are at the #RLV shared root.\n\nFrom here, you can restrict wearing or removing not shared items, you can also save the list of worn shared folders or make the currently saved list be worn again.\n\nWhat do you want to do?";
    Dialog(kAv, sPrompt, lActions, [UPMENU], 0, iAuth, "RootActions");
}

FolderActionsMenu(integer iState, key kAv, integer iAuth)
{
    integer iStateThis = iState / 10;
    integer iStateSub = iState % 10;
    list lActions;
    if (g_sFolderType == "history") lActions += "Browse";
    g_sFolderType += "_actions";
    if (iStateSub == 0) g_sFolderType += "_sub";
    if (g_sCurrentFolder != "") {
        integer iIndex = llListFindList(g_lFolderLocks, [g_sCurrentFolder]);
        integer iLock;
        if (iIndex != -1) iLock = llList2Integer(g_lFolderLocks, iIndex+1);
        if (iStateThis == 1 || iStateThis == 2)
            lActions += [ADD, lockFolderButton(iLock, 0, iAuth)];
        if (iStateThis == 2 || iStateThis == 3)
            lActions += [DETACH,  lockFolderButton(iLock, 1, iAuth)];
        if (iStateSub == 1 || iStateSub == 2)
            lActions += [ADD_ALL,  lockFolderButton(iLock, 2, iAuth)];
        if (iStateSub == 2 || iStateSub == 3)
            lActions += [DETACH_ALL,  lockFolderButton(iLock, 3, iAuth)];
    }
    string sPrompt = "\nRLV Folders\n\nCurrent folder is ";
    if (g_sCurrentFolder == "") sPrompt += "root";
    else sPrompt += g_sCurrentFolder;
    sPrompt += ".\n";
    sPrompt += "\nWhat do you want to do?";

    Dialog(kAv, sPrompt, lActions, [UPMENU], 0, iAuth, "FolderActions");
}

string folderIcon(integer iState)
{
    string sOut = "";
    integer iStateThis = iState / 10;
    integer iStateSub = iState % 10;
    if (iStateThis==0) sOut += "⬚";
    else if (iStateThis==1) sOut += "◻";
    else if (iStateThis==2) sOut += "◩";
    else if (iStateThis==3) sOut += "◼";
    else sOut += " ";
    if (iStateSub==0) sOut += "⬚";
    else if (iStateSub==1) sOut += "◻";
    else if (iStateSub==2) sOut += "◩";
    else if (iStateSub==3) sOut += "◼";
    else sOut += " ";
    return sOut;
}

updateFolderLocks(string sFolder, integer iAdd, integer iRem)
{
    integer iLock;
    integer iIndex = llListFindList(g_lFolderLocks, [sFolder]);
    if (iIndex != -1) {
        iLock = ((llList2Integer(g_lFolderLocks, iIndex+1) | iAdd) & ~iRem);
        if (iLock) {
            g_lFolderLocks = llListReplaceList(g_lFolderLocks, [iLock], iIndex+1, iIndex+1);
            doLockFolder(iIndex);
        } else {
            g_lFolderLocks = llDeleteSubList(g_lFolderLocks, iIndex, iIndex+1);
            llMessageLinked(LINK_RLV, RLV_CMD, "attachthis_except:"+sFolder+"=y,detachthis_except:"+sFolder+"=y,attachallthis_except:"+sFolder+"=y,detachallthis_except:"+sFolder+"=y,"+ "attachthis:"+sFolder+"=y,detachthis:"+sFolder+"=y,attachallthis:"+sFolder+"=y,detachallthis:"+sFolder+"=y", NULL_KEY);
        }
    } else {
        iLock = iAdd & ~iRem;
        g_lFolderLocks += [sFolder, iLock];
        iIndex = llGetListLength(g_lFolderLocks)-2;
        doLockFolder(iIndex);
    }
    if (llGetListLength(g_lFolderLocks) > 0) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE,  g_sSettingToken + "Locks=" + llDumpList2String(g_lFolderLocks, ","), "");
    else llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "Locks", "");
}

doLockFolder(integer iIndex)
{
    string sFolder = llList2String(g_lFolderLocks, iIndex);
    integer iLock = llList2Integer(g_lFolderLocks, iIndex+1);
    string sRlvCom = "attachthis:"+sFolder+"=";
    if ((iLock >> 0) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachthis:"+sFolder+"=";
    if ((iLock >> 1) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachallthis:"+sFolder+"=";
    if ((iLock >> 2) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachallthis:"+sFolder+"=";
    if ((iLock >> 3) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachthis_except:"+sFolder+"=";
    if ((iLock >> 4) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachthis_except:"+sFolder+"=";
    if ((iLock >> 5) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachallthis_except:"+sFolder+"=";
    if ((iLock >> 6) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachallthis_except:"+sFolder+"=";
    if ((iLock >> 7) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    llMessageLinked(LINK_RLV, RLV_CMD, sRlvCom, NULL_KEY);
}


updateUnsharedLocks(integer iAdd, integer iRem)
{
    g_iUnsharedLocks = ((g_iUnsharedLocks | iAdd) & ~iRem);
    doLockUnshared();
    if (g_iUnsharedLocks) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "Unshared=" + (string) g_iUnsharedLocks, "");
    else llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "Unshared", "");
}

doLockUnshared()
{
    string sRlvCom = "unsharedunwear=";
    if ((g_iUnsharedLocks >> 0) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",unsharedwear=";
    if ((g_iUnsharedLocks >> 1) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    llMessageLinked(LINK_RLV,RLV_CMD,  sRlvCom, NULL_KEY);
}

FolderBrowseMenu(string sStr)
{
    g_iAsyncMenuRequested = FALSE;
    list lUtilityButtons = [UPMENU];
    string sPrompt = "\nRLV Folders\n\nCurrent folder is ";
    if (g_sCurrentFolder == "") sPrompt += "root";
    else sPrompt += g_sCurrentFolder;
    sPrompt += ".\n";
    list sData = llParseStringKeepNulls(sStr, [","], []);
    string sFirst = llList2String(sData, 0);
    sData = llListSort(llList2List(sData, 1, -1), 1, 1);
    integer i;
    list lItem;
    integer iWorn;
    list lFolders = [];
    if (g_sCurrentFolder != "") {
        lItem=llParseString2List(sFirst, ["|"], []);
        iWorn=llList2Integer(lItem, 0);
        g_iLastFolderState = iWorn;
        if (iWorn / 10 == 1 ) sPrompt += "It has wearable items";
        else if (iWorn / 10 == 2 ) sPrompt += "It has wearable and removable items";
        else if (iWorn / 10 == 3 ) sPrompt += "It has removable items";
        else if (iWorn / 10 == 0 ) sPrompt += "It does not directly have any wearable or removable item";
        sPrompt += ".\n";
        lUtilityButtons += [ACTIONS_CURRENT];
    }
    for (i = 0; i < llGetListLength(sData); i++) {
        lItem = llParseString2List(llList2String(sData, i), ["|"], []);
        string sFolder = llList2String(lItem, 0);
        iWorn = llList2Integer(lItem, 1);
        if (iWorn != 0 && !(g_sCurrentFolder == "" && llToLower(sFolder)==llToLower(g_sOutfitsFolder)))
            lFolders += [folderIcon(iWorn) + sFolder];
    }
    sPrompt += "\n- Click "+ACTIONS_CURRENT+" to manage this folder content.\n- Click one of the subfolders to browse it.\n";
    if (g_sCurrentFolder != "") {sPrompt += "- Click "+PARENT+" to browse parent folder.\n"; lUtilityButtons += [PARENT];}
    sPrompt += "- Click "+UPMENU+" to go back to "+g_sParentMenu+".\n";
    Dialog(g_kAsyncMenuUser, sPrompt, lFolders, lUtilityButtons, g_iPage, g_iAsyncMenuAuth, "FolderBrowse");
}

handleMultiSearch()
{
    string sItem = llList2String(g_lSearchList,0);
    string pref1 = llGetSubString(sItem, 0, 0);
    string pref2 = llGetSubString(sItem, 0, 1);
    g_lSearchList = llDeleteSubList(g_lSearchList,0,0);
    if (pref1 == "+" || pref1 == "&") g_sFolderType = "searchattach";
    else if (pref1 == "-") g_sFolderType = "searchdetach";
    else jump next;
    if (pref2 == "++" || pref2 == "--" || pref2 == "&&") {
        g_sFolderType += "all";
        sItem = llToLower(llGetSubString(sItem, 2, -1));
    } else sItem = llToLower(llGetSubString(sItem, 1, -1));
    if (pref1 == "&") g_sFolderType += "over";
    @next;
    searchSingle(sItem);
}

string g_sFirstsearch;
string g_sNextsearch;
string g_sBuildpath;

searchSingle(string sItem)
{
    g_iFolderRLV = 9999 + llRound(llFrand(9999999.0));
    g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
    g_sFirstsearch = "";
    g_sNextsearch = "";
    g_sBuildpath = "";
    if(llSubStringIndex(sItem,"/") != -1) {
        list tlist=llParseString2List(sItem,["/"],[]);
        g_sFirstsearch=llList2String(tlist,0);
        g_sNextsearch=llList2String(tlist,1);
        sItem=g_sFirstsearch;
    }
    llSetTimerEvent(g_iTimeOut);
    if ((g_iRLVaOn) && (g_sNextsearch == "")) {
        llOwnerSay("@findfolders:"+sItem+"="+(string)g_iFolderRLV);
    } else llOwnerSay("@findfolder:"+sItem+"="+(string)g_iFolderRLV);
}

SetAsyncMenu(key kAv, integer iAuth)
{
    g_iAsyncMenuRequested = TRUE;
    g_kAsyncMenuUser = kAv;
    g_iAsyncMenuAuth = iAuth;
}

UserCommand(integer iNum, string sStr, key kID)
{
    if (llToLower(sStr) == "folders" || llToLower(sStr) == "#rlv" || sStr == "menu # Folders") {
        g_sCurrentFolder = "";
        QueryFolders("browse");
        SetAsyncMenu(kID, iNum);
    } else if (llToLower(sStr) == "history" || sStr == "menu ﹟RLV History")
        HistoryMenu(kID, iNum);
    else if (llToLower(llGetSubString(sStr, 0, 4)) == "#rlv ") {
        SetAsyncMenu(kID, iNum);
        g_sFolderType = "searchbrowse";
        string sPattern = llDeleteSubString(sStr, 0, 4);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Searching folder containing string \"" + sPattern + "\" for browsing.", g_kWearer);
        searchSingle(sPattern);
    } else if (llGetSubString(sStr, 0, 0) == "+" || llGetSubString(sStr, 0, 0) == "-" || llGetSubString(sStr, 0, 0) == "&") {
        g_kAsyncMenuUser = kID;
        g_lSearchList=llParseString2List(sStr, [","], []);
        handleMultiSearch();
    } else if (iNum <= CMD_GROUP) {
        list lArgs = llParseStringKeepNulls(sStr, ["="], []);
        integer val;
        if (llList2String(lArgs, 0) == "unsharedwear") val = 0x2;
        else if (llList2String(lArgs, 0) == "unsharedunwear") val = 0x1;
        else if (llList2String(lArgs, 1) == "y") updateUnsharedLocks(0, val);
        else if (llList2String(lArgs, 1) == "n") updateUnsharedLocks(val, 0);
    }
}

default
{
    on_rez(integer iParam)
    {
        llResetScript();
    }

    state_entry()
    {
        g_kWearer = llGetOwner();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == RLV_CLEAR) {
            g_lFolderLocks = [];
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,  g_sSettingToken + "Locks", NULL_KEY);
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == RLVA_VERSION) g_iRLVaOn = TRUE;
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                g_iPage = llList2Integer(lMenuParams, 2);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);
                if (sMenu == "History") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_RLV, iAuth, "menu "+g_sParentMenu, kAv);
                        return;
                    } else {
                        g_sCurrentFolder = sMessage;
                        g_iPage = 0;
                        SetAsyncMenu(kAv, iAuth);
                        QueryFolders("history");
                    }
                } else if (sMenu == "MultipleFoldersOnSearch") {
                    if (sMessage == UPMENU) {
                            g_sCurrentFolder = "";
                            QueryFolders("browse");
                            return;
                    }
                    llMessageLinked(LINK_RLV, RLV_CMD, llGetSubString(g_sFolderType,6,-1)+":"+sMessage+"=force", NULL_KEY);
                    addToHistory(sMessage);
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now "+llGetSubString(g_sFolderType,6,11)+"ing "+sMessage, kAv);
                } else if (sMenu == "RootActions") {
                    if (sMessage == UPMENU) {
                        SetAsyncMenu(kAv, iAuth); QueryFolders("browse");
                        return;
                    } else if (sMessage == lockUnsharedButton(0, 0)) {
                        if (g_iUnsharedLocks & 0x1) {
                            updateUnsharedLocks(0x0, 0x1);
                            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing unshared items is no longer forbidden.", kAv);
                        } else {
                            updateUnsharedLocks(0x1, 0x0);
                            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing unshared items is forbidden.", kAv);
                        }
                    } else if (sMessage == lockUnsharedButton(1, 0)) {
                        if (g_iUnsharedLocks & 0x2) {
                            updateUnsharedLocks(0x0, 0x2);
                            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing unshared items is no longer forbidden.", kAv);
                        } else {
                            updateUnsharedLocks(0x2, 0x0);
                            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing unshared items is forbidden.", kAv);
                        }
                    }
                    RootActionsMenu(kAv, iAuth);
                } else if (sMenu == "FolderBrowse") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_RLV, iAuth, "menu " + g_sParentMenu, kAv);
                        return;
                    } else if (sMessage == ROOT_ACTIONS) {
                        RootActionsMenu(kAv, iAuth);
                        return;
                    } else if (sMessage == ACTIONS_CURRENT) {
                        FolderActionsMenu(g_iLastFolderState, kAv, iAuth);
                        return;
                    } else if (sMessage == PARENT)
                        ParentFolder();
                    else {
                        string sIconThis = llGetSubString(sMessage, 0, 0);
                        string sIconSub = llGetSubString(sMessage, 1, 1);
                        integer iState;
                        if (sIconThis == "◻") iState = 1;
                        else if (sIconThis == "◩") iState = 2;
                        else if (sIconThis == "◼") iState = 3;
                        iState *= 10;
                        if (sIconSub == "◻") iState +=1;
                        else if (sIconSub == "◩") iState +=2;
                        else if (sIconSub == "◼") iState += 3;
                        string folder = llToLower(llGetSubString(sMessage, 2, -1));
                        if (g_sCurrentFolder == "") g_sCurrentFolder = folder;
                        else g_sCurrentFolder  += "/" + folder;
                        if ((iState % 10) == 0) {
                            FolderActionsMenu(iState, kAv, iAuth);
                            return;
                        }
                    }
                    g_iPage = 0;
                    SetAsyncMenu(kAv, iAuth);
                    QueryFolders("browse");
                } else if (sMenu == "FolderActions") {
                    if (sMessage == ADD) {
                        llMessageLinked(LINK_RLV, RLV_CMD, "attachover:" + g_sCurrentFolder + "=force", NULL_KEY);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now adding "+g_sCurrentFolder, kAv);
                    } else if (sMessage == DETACH) {
                        llMessageLinked(LINK_RLV, RLV_CMD, "detach:" + g_sCurrentFolder + "=force", NULL_KEY);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now detaching "+g_sCurrentFolder, kAv);
                    } else if (sMessage == ADD_ALL) {
                        llMessageLinked(LINK_RLV, RLV_CMD, "attachallover:" + g_sCurrentFolder + "=force", NULL_KEY);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now adding everything in "+g_sCurrentFolder, kAv);
                    } else if (sMessage == DETACH_ALL) {
                        llMessageLinked(LINK_RLV, RLV_CMD, "detachall:" + g_sCurrentFolder  + "=force", NULL_KEY);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now detaching everything in "+g_sCurrentFolder, kAv);
                    } else if (sMessage == lockFolderButton(0x00, 0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x01, 0x10);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing "+g_sCurrentFolder+ " is forbidden (this overrides parent exceptions).", kAv);
                    } else if (sMessage == lockFolderButton(0x00,1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x02, 0x20);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing "+g_sCurrentFolder+ " is forbidden (this overrides parent exceptions).", kAv);
                    } else if (sMessage == lockFolderButton(0x00, 2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x04, 0x40);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing "+g_sCurrentFolder+ " or its subfolders is forbidden (this overrides parent exceptions).", kAv);
                    } else if (sMessage == lockFolderButton(0x00, 3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x08, 0x80);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing "+g_sCurrentFolder+ " or its subfolders is forbidden (this overrides parent exceptions).", kAv);
                    } else if (sMessage == lockFolderButton(0x0F, 0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x10, 0x01);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing "+g_sCurrentFolder+ " is exceptionally allowed (this overrides parent locks).", kAv);
                    } else if (sMessage == lockFolderButton(0x0F, 1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x20, 0x02);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing "+g_sCurrentFolder+ " is exceptionally allowed (this overrides parent locks).", kAv);
                    } else if (sMessage == lockFolderButton(0x0F,2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x40, 0x04);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now wearing "+g_sCurrentFolder+ " or its subfolders is exceptionally allowed (this overrides parent locks).", kAv);
                    } else if (sMessage == lockFolderButton(0x0F,3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x80, 0x08);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now removing "+g_sCurrentFolder+ " or its subfolders is exceptionally allowed (this overrides parent locks).", kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x11);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now there is no restriction or exception on wearing "+g_sCurrentFolder+ ".", kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x22);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now there is no restriction or exception on removing "+g_sCurrentFolder+ ".", kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x44);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now there is no restriction or exception on wearing "+g_sCurrentFolder+ " and its subfolders.", kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x88);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now there is no restriction or exception on removing "+g_sCurrentFolder+ " and its subfolders.", kAv);
                    } else if (llGetSubString(sMessage, 0, 0) == "(")
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"%NOACCESS%", kAv);
                    if (sMessage != UPMENU) {
                        addToHistory(g_sCurrentFolder);
                        llSleep(1.0);
                    }
                    if (llGetSubString(g_sFolderType, 0, 14) == "history_actions" && sMessage != "Browse") {
                        HistoryMenu(kAv, iAuth);
                        return;
                    }
                    if (llGetSubString(g_sFolderType, -4, -1) == "_sub") ParentFolder();
                    SetAsyncMenu(kAv, iAuth);
                    QueryFolders("browse");
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer index = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, index) == g_sSettingToken) {
                sToken = llGetSubString(sToken, index+1, -1);
                if (sToken == "Locks") {
                    g_lFolderLocks = llParseString2List(sValue, [","], []);
                    integer iN = llGetListLength(g_lFolderLocks);
                    integer i;
                    for (i = 0; i < iN; i += 2) doLockFolder(i);
                } else if (sToken == "Unshared") {
                    g_iUnsharedLocks = (integer)sValue;
                    doLockUnshared();
                }
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    listen(integer iChan, string sName, key kID, string sMsg)
    {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        if (iChan == g_iFolderRLV) {
            if (g_sFolderType=="browse") {
                if (sMsg == "") {
                    g_sCurrentFolder = "";
                    g_iPage = 0;
                    QueryFolders("browse");
                } else {
                    if (llStringLength(sMsg) == 1023) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"\n\nATTENTION: Either some of the names of your folders are too long, or there are too many folders in your current #RLV directory. This could lead to gaps in your #RLV folder index. For best operability, please consider reducing the overall amount of subfolders within the #RLV directory and use shorter names.\n", g_kWearer);
                    FolderBrowseMenu(sMsg);
                }
            } else if (g_sFolderType == "history") {
                list sData = llParseStringKeepNulls(sMsg, [",", "|"], []);
                integer iState = llList2Integer(sData, 1);
                FolderActionsMenu(iState, g_kAsyncMenuUser, g_iAsyncMenuAuth);
            }
            else if (llGetSubString(g_sFolderType, 0, 5) == "search") {
                if (sMsg == "") llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sMsg+"No folder found.", g_kAsyncMenuUser);
                else if (llGetSubString(g_sFolderType, 6, -1) == "browse") {
                    g_sCurrentFolder = sMsg;
                    QueryFolders("browse");
                } else {
                    if(g_sFirstsearch != "") {
                        integer idx = llSubStringIndex(llToLower(sMsg), llToLower(g_sFirstsearch));
                        g_sBuildpath = llGetSubString(sMsg, 0, idx);
                        sMsg = llDeleteSubString(sMsg, 0, idx);
                        idx = llSubStringIndex(sMsg, "/");
                        g_sBuildpath += llGetSubString(sMsg, 0, idx);
                        g_sFirstsearch = "";
                        g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
                        llSetTimerEvent(g_iTimeOut);
                        llOwnerSay("@getinv:"+g_sBuildpath+"="+(string)g_iFolderRLV);
                    } else {
                        if(g_sNextsearch != "") {
                            list tlist = llParseString2List(sMsg, [","], []);
                            integer i = llGetListLength(tlist);
                            string found;
                            string test;
                            while(i > 0) {
                                test = llList2String(tlist, --i);
                                if(llSubStringIndex(llToLower(test), llToLower(g_sNextsearch)) != -1) {
                                    i = 0;
                                    found = test;
                                }
                            }
                            if(found == "") {
                                 llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sNextsearch+" subfolder not found", g_kAsyncMenuUser);
                                 return;
                            } else sMsg = g_sBuildpath+"/"+found;
                            g_sNextsearch = "";
                            g_sBuildpath = "";
                        }
                        if ((llSubStringIndex(sMsg,",") >= 0) && g_iRLVaOn) {
                            list lMultiFolders = llParseString2List(sMsg, [","], []);
                            string sPrompt = "Multiple results found.  Please select an item\n";
                            sPrompt += "Current action is "+g_sFolderType+"\n";
                            Dialog(g_kAsyncMenuUser, sPrompt, lMultiFolders, [UPMENU], 0, iChan, "MultipleFoldersOnSearch");
                            return;
                        }
                        llMessageLinked(LINK_RLV, RLV_CMD, llGetSubString(g_sFolderType,6,-1)+":"+sMsg+"=force", NULL_KEY);
                        addToHistory(sMsg);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now "+llGetSubString(g_sFolderType,6,11)+"ing "+sMsg, g_kAsyncMenuUser);
                    }
                }
                if (llGetListLength(g_lSearchList) > 0) handleMultiSearch();
            }
        }
    }

    timer()
    {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
    }
}
