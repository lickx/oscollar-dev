
//  oc_rlvstuff.lsl
//
//  Copyright (c) 2008 - 2016 Satomi Ahn, Nandana Singh, Joy Stipe,
//  Wendy Starfall, Master Starship, littlemousy, Romka Swallowtail,
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

string g_sAppVersion = "1.1";

string g_sParentMenu = "RLV";

list g_lSettings;
list g_lChangedCategories;

integer g_lRLVcmds_stride=4;
list g_lRLVcmds=[
    "rlvtp_","tplm","Landmark","Teleport via Landmark",
    "rlvtp_","tploc","Slurl","Teleport via Slurl/Map",
    "rlvtp_","tplure","Lure","Teleport via offers",
    "rlvtp_","showworldmap","Map","View World-map",
    "rlvtp_","showminimap","Mini-map","View Mini-map",
    "rlvtp_","showloc","Location","See current location",
    "rlvtalk_","sendchat","Chat","Ability to Chat",
    "rlvtalk_","chatshout","Shout","Ability to Shout",
    "rlvtalk_","chatnormal","Whisper","Forced to Whisper",
    "rlvtalk_","startim","Start IMs","Initiate IM Sessions",
    "rlvtalk_","sendim","Send IMs","Respond to IMs",
    "rlvtalk_","recvim","Get IMs","Receive IMs",
    "rlvtalk_","recvchat","See Chat","Receive Chat",
    "rlvtalk_","recvemote","See Emote","Receive Emotes",
    "rlvtalk_","emote","Emote","Short Emotes if Chat blocked",
    "rlvtouch_","fartouch","Far","Touch objects >1.5m away",
    "rlvtouch_","touchworld","World","Touch in-world objects",
    "rlvtouch_","touchattach","Self","Touch your attachments",
    "rlvtouch_","touchattachother","Others","Touch others' attachments",
    "rlvmisc_","shownames","Names","See Avatar Names",
    "rlvmisc_","fly","Fly","Ability to Fly",
    "rlvmisc_","edit","Edit","Edit Objects",
    "rlvmisc_","rez","Rez","Rez Objects",
    "rlvmisc_","showinv","Inventory","View Inventory",
    "rlvmisc_","viewnote","Notecards","View Notecards",
    "rlvmisc_","viewscript","Scripts","View Scripts",
    "rlvmisc_","viewtexture","Textures","View Textures",
    "rlvmisc_","showhovertextworld","Hovertext","See hovertext like titles",
    "rlvview_","camdistmax:0","Mouselook","Leave Mouselook",
    "rlvview_","camunlock","Alt Zoom","Alt zoom/pan around",
    "rlvview_","camdrawalphamax:1","See","See anything at all"
];

list g_lMenuHelpMap = [
    "rlvstuff_","Stuff",
    "rlvtp_","Travel",
    "rlvtalk_","Talk",
    "rlvtouch_","Touch",
    "rlvmisc_","Misc",
    "rlvview_","View"
];

string TURNON = "✔";
string TURNOFF = "✘";

integer CMD_OWNER = 500;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;

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
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;

integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

key g_kWearer;

integer g_iRLVOn;

list g_lMenuIDs;
integer g_iMenuStride = 3;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    llMessageLinked(LINK_DIALOG,NOTIFY,(string)iAlsoNotifyWearer+sMsg,kID);
}

StuffMenu(key kID, integer iAuth) {
    Dialog(kID, "\nLegacy RLV Stuff\t"+g_sAppVersion+"\n", ["Misc","Touch","Talk","Travel","View"], [UPMENU], 0, iAuth, "rlvstuff");
}

Menu(key kID, integer iAuth, string sMenuName) {
    if (!g_iRLVOn) {
        Notify(kID, "RLV features are now disabled in this %DEVICETYPE%. You can enable those in RLV submenu. Opening it now.", FALSE);
        llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kID);
        return;
    }
    integer n;
    string sPrompt;
    list lButtons;
    n = llListFindList(g_lMenuHelpMap,[sMenuName]);
    if (~n) sPrompt="\nLegacy RLV "+llList2String(g_lMenuHelpMap,n+1)+"\n";
    integer iStop = llGetListLength(g_lRLVcmds);
    for (n = 0; n < iStop; n+=g_lRLVcmds_stride) {
        if (llList2String(g_lRLVcmds,n)==sMenuName){
            string sCmd = llList2String(g_lRLVcmds, n+1);
            string sPretty = llList2String(g_lRLVcmds, n+2);
            string desc = llList2String(g_lRLVcmds, n+3);
            integer iIndex = llListFindList(g_lSettings, [sCmd]);
            if (iIndex == -1) {
                lButtons += [TURNOFF + " " + sPretty];
                sPrompt += "\n" + sPretty + " = Enabled (" + desc + ")";
            } else {
                string sValue = llList2String(g_lSettings, iIndex + 1);
                if (sValue == "y") {
                    lButtons += [TURNOFF + " " + sPretty];
                    sPrompt += "\n" + sPretty + " = Enabled (" + desc + ")";
                } else if (sValue == "n") {
                    lButtons += [TURNON + " " + sPretty];
                    sPrompt += "\n" + sPretty + " = Disabled (" + desc + ")";
                }
            }
        }
    }
    lButtons += [TURNON + " All"];
    lButtons += [TURNOFF + " All"];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, sMenuName);
}

SetSetting(string sCategory, string sOption, string sValue) {
    integer iIndex = llListFindList(g_lSettings,[sCategory,sOption]);
    if (~iIndex) g_lSettings = llListReplaceList(g_lSettings, [sCategory, sOption, sValue], iIndex, iIndex+2);
    else g_lSettings += [sCategory, sOption, sValue];
    if (! ~llListFindList(g_lChangedCategories,[sCategory])) g_lChangedCategories+=sCategory;
}

UpdateSettings() {
    integer iSettingsLength = llGetListLength(g_lSettings);
    if (iSettingsLength > 0) {
        list lTempSettings;
        string sTempRLVSetting;
        string sTempRLVValue;
        integer n;
        list lNewList;
        for (n = 0; n < iSettingsLength; n = n + 3) {
            sTempRLVSetting=llList2String(g_lSettings, n+1);
            sTempRLVValue=llList2String(g_lSettings, n + 2);
            lNewList += [ sTempRLVSetting+ "=" + sTempRLVValue];
            if (sTempRLVValue!="y")lTempSettings+=[sTempRLVSetting,sTempRLVValue];
        }
        llMessageLinked(LINK_RLV, RLV_CMD, llDumpList2String(lNewList, ","), NULL_KEY);
    }
}

SaveSettings() {
    list lCategorySettings;
    while (llGetListLength(g_lChangedCategories)) {
        lCategorySettings=[];
        integer numSettings=llGetListLength(g_lSettings);
        while (numSettings) {
            numSettings -= 3;
            string sCategory=llList2String(g_lSettings,numSettings);
            if (sCategory==llList2String(g_lChangedCategories,-1)) {
                lCategorySettings+=[llList2String(g_lSettings,numSettings+1),llList2String(g_lSettings,numSettings+2)];
            }
        }
        if (llGetListLength(lCategorySettings)>0) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, llList2String(g_lChangedCategories,-1) + "List=" + llDumpList2String(lCategorySettings, ","), "");
        else llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, llList2String(g_lChangedCategories,-1) + "List", "");
        g_lChangedCategories=llDeleteSubList(g_lChangedCategories,-1,-1);
    }
}

ClearSettings(string _category) {
    integer numSettings = llGetListLength(g_lSettings);
    while (numSettings) {
        numSettings -= 3;
        string sCategory = llList2String(g_lSettings,numSettings);
        if (sCategory == _category || _category == "") {
            g_lSettings = llDeleteSubList(g_lSettings,numSettings,numSettings+2);
            if (llListFindList(g_lChangedCategories,[sCategory])==-1) g_lChangedCategories+=sCategory;
        }
    }
    SaveSettings();
}

UserCommand(integer iNum, string sStr, key kID, string fromMenu) {
    if (iNum > CMD_WEARER) return;
    sStr=llStringTrim(sStr,STRING_TRIM);
    string sStrLower=llToLower(sStr);
    if (sStrLower == "rm rlvstuff") {
        if (kID!=g_kWearer && iNum!=CMD_OWNER) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else Dialog(kID, "\nDo you really want to uninstall Legacy RLV Stuff?", ["Yes","No","Cancel"], [], 0, iNum,"rmrlvstuff");
    } else if (sStrLower == "rlvtp" || sStrLower == "menu travel") Menu(kID, iNum, "rlvtp_");
    else if (sStrLower == "rlvtalk" || sStrLower == "menu talk") Menu(kID, iNum, "rlvtalk_");
    else if (sStrLower == "rlvtouch" || sStrLower == "menu touch") Menu(kID, iNum, "rlvtouch_");
    else if (sStrLower == "rlvmisc" || sStrLower == "menu misc") Menu(kID, iNum, "rlvmisc_");
    else if (sStrLower == "rlvview" || sStrLower == "menu view") Menu(kID, iNum, "rlvview_");
    else if (sStrLower == "rlvstuff" || sStrLower == "menu stuff") StuffMenu(kID, iNum);
    else {
        list lItems = llParseString2List(sStr, [","], []);
        integer n;
        integer iStop = llGetListLength(lItems);
        for (n = 0; n < iStop; n++) {
            string sThisItem = llList2String(lItems, n);
            string sBehavior = llList2String(llParseString2List(sThisItem, ["="], []), 0);
            integer iBehaviourIndex=llListFindList(g_lRLVcmds, [sBehavior]);

            if (~iBehaviourIndex) {
                string sCategory=llList2String(g_lRLVcmds,iBehaviourIndex-1);
                if (llGetSubString(sCategory,-1,-1)=="_"){  //
                    if (iNum == CMD_WEARER) llOwnerSay("Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                    else {
                        string sOption = llList2String(llParseString2List(sThisItem, ["="], []), 0);
                        string sValue = llList2String(llParseString2List(sThisItem, ["="], []), 1);
                        SetSetting(sCategory, sOption, sValue);
                    }
                }
            } else if (sBehavior == "clear" && iNum == CMD_OWNER) ClearSettings("");
        }
        if (llGetListLength(g_lChangedCategories)) {
            UpdateSettings();
            SaveSettings();
        }
        if (fromMenu!="") Menu(kID, iNum, fromMenu);
    }
}

default {
    on_rez(integer iParam) {
        llSetTimerEvent(0.0);
    }

    state_entry() {
        g_kWearer = llGetOwner();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|Stuff", "");
        else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID, "");
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            string category = llList2String(llParseString2List(sToken,["_"],[]),0)+"_";
            if (~llListFindList(g_lMenuHelpMap,[category])){
                sToken = llList2String(llParseString2List(sToken,["_"],[]),1);
                if (sToken == "List") {
                    ClearSettings(category);
                    list lNewSettings = llParseString2List(sValue, [","], []);
                    while (llGetListLength(lNewSettings)) {
                        list lTempSettings = [category,llList2String(lNewSettings,-2),llList2String(lNewSettings,-1)];
                        g_lSettings += lTempSettings;
                        lNewSettings = llDeleteSubList(lNewSettings,-2,-1);
                    }
                    UpdateSettings();
                }
            }
        } else if (iNum == RLV_REFRESH) {
            g_iRLVOn = TRUE;
            UpdateSettings();
        } else if (iNum == RLV_CLEAR) ClearSettings("");
        else if (iNum == RLV_OFF) g_iRLVOn = FALSE;
        else if (iNum == RLV_ON) g_iRLVOn = TRUE;
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenu == "rmrlvstuff") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_RLV, MENUNAME_REMOVE, g_sParentMenu + "|Stuff", "");
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Legacy RLV Stuff has been removed.", kAv);
                        ClearSettings("");
                        if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT) llRemoveInventory(llGetScriptName());
                    } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Legacy RLV Stuff remains installed.", kAv);
                } else if (sMenu == "rlvstuff") {
                    if (sMessage == UPMENU) llMessageLinked(LINK_RLV, iAuth, "menu "+g_sParentMenu, kAv);
                    else UserCommand(iAuth, "menu "+sMessage, kAv, "");
                } else if (sMessage == UPMENU) StuffMenu(kAv,iAuth);
                else {
                    list lParams = llParseString2List(sMessage, [" "], []);
                    string sSwitch = llList2String(lParams, 0);
                    string sCmd = llDumpList2String(llDeleteSubList(lParams,0,0)," ");
                    integer iIndex = llListFindList(g_lRLVcmds, [sCmd]);
                    if (sCmd == "All") {
                        string ONOFF;
                        if (sSwitch == TURNOFF) ONOFF = "n";
                        else if (sSwitch == TURNON) ONOFF = "y";
                        string sOut;
                        integer n;
                        integer iStop = llGetListLength(g_lRLVcmds);
                        for (n = 0; n < iStop; n+=g_lRLVcmds_stride) {
                            if (llList2String(g_lRLVcmds,n)==sMenu){
                                if (sOut != "")  sOut += ",";
                                sOut += llList2String(g_lRLVcmds, n+1) + "=" + ONOFF;
                            }
                        }
                        UserCommand(iAuth, sOut, kAv, sMenu);
                    } else if ((~iIndex) && llList2String(g_lRLVcmds,iIndex-2)==sMenu) {
                        string sOut = llList2String(g_lRLVcmds, iIndex-1);
                        sOut += "=";
                        if (sSwitch == TURNON) sOut += "y";
                        else if (sSwitch == TURNOFF) sOut += "n";
                        UserCommand(iAuth, sOut, kAv, sMenu);
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }
}
