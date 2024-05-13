
yoptions;

//  oc_settings.lsl
//
//  Copyright (c) 2008 - 2017 Nandana Singh, Cleo Collins, Master Starship,
//  Satomi Ahn, Garvin Twine, Joy Stipe, Alex Carpenter, Xenhat Liamano,
//  Wendy Starfall, Medea Destiny, Rebbie, Romka Swallowtail,
//  littlemousy et al.
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

string g_sCard = ".settings";
string g_sSplitLine;
integer g_iLineNr;
key g_kLineID = NULL_KEY;
key g_kCardID = NULL_KEY;
list g_lExceptionTokens = ["texture","glow","shininess","color","intern"];
key g_kWearer = NULL_KEY;

integer CMD_OWNER = 500;

integer NOTIFY=1002;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
integer LM_SETTING_EMPTY = 2004;

integer LM_CUFF_SET = -551010;
integer SETTING_CUFFS_SAVE = 2000;
integer SETTING_CUFFS_DELETE = 2003;
list CUFFS_GROUPS = ["auth","color","texture","shininess"];

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;

integer REGION_CROSSED = 10050;
integer REGION_TELEPORT = 10051;

integer LINK_DIALOG = 3;
integer LINK_UPDATE = -10;
integer LINK_CUFFS = -1;

integer REBOOT = -1000;
integer LOADPIN = -1904;

integer g_iRebootConfirmed;
key g_kConfirmDialogID = NULL_KEY;

list g_lSettings;
key g_kTempOwner = NULL_KEY;

integer g_iSayLimit = 1024;
integer g_iCardLimit = 255;
string g_sDelimiter = "\\";

string SplitToken(string sIn, integer iSlot)
{
    integer i = llSubStringIndex(sIn, "_");
    if (iSlot == 0) return llGetSubString(sIn, 0, i-1);
    return llGetSubString(sIn, i+1, -1);
}

integer GroupIndex(list lCache, string sToken)
{
    string sGroup = SplitToken(sToken, 0);
    integer i = llGetListLength(lCache) - 1;
    for (; i >= 0; i -= 2) {
        if (SplitToken(llList2String(lCache, i-1), 0) == sGroup) return i+1;
    }
    return -1;
}
integer SettingExists(string sToken)
{
    if (llListFindList(g_lSettings, [sToken]) != -1) return TRUE;
    return FALSE;
}

list SetSetting(list lCache, string sToken, string sValue)
{
    llLinksetDataWrite(llToUpper(SplitToken(sToken,0)), SplitToken(sToken,1)+"~"+sValue);
    integer idx = llListFindList(lCache, [sToken]);
    if (idx != -1) return llListReplaceList(lCache, [sValue], idx+1, idx+1);
    idx = GroupIndex(lCache, sToken);
    if (idx != -1) return llListInsertList(lCache, [sToken, sValue], idx);
    return lCache + [sToken, sValue];
}

string GetSetting(string sToken)
{
    integer i = llListFindList(g_lSettings, [sToken]);
    return llList2String(g_lSettings, i+1);
}

DelSetting(string sToken)
{
    integer i = llGetListLength(g_lSettings) - 1;
    if (SplitToken(sToken, 1) == "all") {
        sToken = SplitToken(sToken, 0);
        for (; i >= 0; i -= 2) {
            if (SplitToken(llList2String(g_lSettings, i-1), 0) == sToken)
                g_lSettings = llDeleteSubList(g_lSettings, i-1, i);
        }
        return;
    }
    i = llListFindList(g_lSettings, [sToken]);
    if (i != -1) {
        if (sToken == "auth_tempowner") g_kTempOwner = NULL_KEY;
        g_lSettings = llDeleteSubList(g_lSettings, i, i+1);
    }
}

list Add2OutList(list lIn, string sDebug)
{
    if (llGetListLength(lIn) == 0) return [];
    list lOut;
    string sBuffer;
    string sTemp;
    string sID;
    string sPre;
    string sGroup;
    string sToken;
    string sValue;
    integer i;
    for (i = 0; i < llGetListLength(lIn); i += 2) {
        sToken = llList2String(lIn, i);
        sValue = llList2String(lIn, i + 1);
        sGroup = llToUpper(SplitToken(sToken, 0));
        if (sDebug == "print" && llListFindList(g_lExceptionTokens, [llToLower(sGroup)]) != -1) jump next;
        if (sDebug == "save" && llToLower(sGroup)=="auth") jump next;
        sToken = SplitToken(sToken, 1);
        integer bIsSplit = FALSE ;
        integer iAddedLength = llStringLength(sBuffer) + llStringLength(sValue)
            + llStringLength(sID) +2;
        if (sGroup != sID || llStringLength(sBuffer) == 0 || iAddedLength >= g_iCardLimit ) {
            if ( llStringLength(sBuffer) ) lOut += [sBuffer] ;
            sID = sGroup;
            sPre = "\n" + sID + "=";
        }
        else sPre = sBuffer + "~";
        sTemp = sPre + sToken + "~" + sValue;
        while (llStringLength(sTemp) > 0) {
            sBuffer = sTemp;
            if (llStringLength(sTemp) > g_iCardLimit) {
                bIsSplit = TRUE ;
                sBuffer = llGetSubString(sTemp, 0, g_iCardLimit-2) + g_sDelimiter;
                sTemp = "\n" + llDeleteSubString(sTemp, 0, g_iCardLimit-2);
            } else sTemp = "";
            if ( bIsSplit ) {
                lOut += [sBuffer];
                sBuffer = "" ;
            }
        }
        @next;
    }
    if (llStringLength(sBuffer) > 0) lOut += [sBuffer] ;
    return lOut;
}

PrintSettings(key kID, string sDebug)
{
    list lOut;
    string sLinkNr = (string)llGetLinkNumber();
    string sLinkName = llGetLinkName(LINK_THIS);
    list lSay = ["/me \nTo copy/paste the settings below in the .settings notecard (in the '"+sLinkName+"' prim, link nr. "+sLinkNr+"), make sure the device is unlocked!\n----- 8< ----- 8< ----- 8< -----\n"];
    if (sDebug == "debug")
        lSay = ["/me Settings Debug:\n"];
    lSay += Add2OutList(g_lSettings, sDebug);
    string sOld;
    string sNew;
    integer i;
    while (llGetListLength(lSay) > 0) {
        sNew = llList2String(lSay, 0);
        i = llStringLength(sOld + sNew) + 2;
        if (i > g_iSayLimit) {
            lOut += [sOld];
            sOld = "";
        }
        sOld += sNew;
        lSay = llDeleteSubList(lSay, 0, 0);
    }
    lOut += [sOld];
    while (llGetListLength(lOut) > 0) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+llList2String(lOut, 0), kID);
        lOut = llDeleteSubList(lOut, 0, 0);
    }
}

SaveCard(key kID)
{
    list lOut = Add2OutList(g_lSettings, "save");
    try
    {
        osMakeNotecard(g_sCard, lOut);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Settings saved.", kID);
    }
    catch (scriptexception ex)
    {
        string msg = yExceptionMessage(ex);
        if (osStringStartsWith(msg, "ossl permission error", TRUE))
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Saving is not enabled on this region. Use 'Print' instead, then copy & paste to replace the contents of the settings notecard.", kID);
        else
            throw;
    }
}

ParseCardLine(string sData, integer iLine)
{
    string sID;
    string sToken;
    string sValue;
    integer i;
    if (iLine == 0 && g_sSplitLine != "" ) {
        sData = g_sSplitLine ;
        g_sSplitLine = "" ;
    }
    if (iLine > 0) {
        sData = llStringTrim(sData, STRING_TRIM_HEAD);
        if (sData == "" || llGetSubString(sData, 0, 0) == "#") return;
        if (llStringLength(g_sSplitLine)) {
            sData = g_sSplitLine + sData ;
            g_sSplitLine = "" ;
        }
        if (llGetSubString(sData, -1, -1) == g_sDelimiter) {
            g_sSplitLine = llDeleteSubString(sData, -1, -1) ;
            return;
        }
        i = llSubStringIndex(sData, "=");
        sID = llGetSubString(sData, 0, i-1);
        sData = llGetSubString(sData, i+1, -1);
        if (llSubStringIndex(llToLower(sID), "_") != -1) return;
        else if (llListFindList(g_lExceptionTokens, [sID]) != -1) return;
        sID = llToLower(sID) + "_";
        list lData = llParseString2List(sData, ["~"], []);
        for (i = 0; i < llGetListLength(lData); i += 2) {
            sToken = llList2String(lData, i);
            sValue = llList2String(lData, i+1);
            if (sValue != "") {
                if (sID == "auth_") {
                    sToken = llToLower(sToken);
                    if (llListFindList(["block","trust","owner"], [sToken]) != -1) {
                        list lTest = llParseString2List(sValue, [","], []);
                        list lOut;
                        integer n;
                        do {
                            if (llList2Key(lTest, n))
                                lOut += llList2String(lTest, n);
                        } while (++n < llGetListLength(lTest));
                        sValue = llDumpList2String(lOut, ",");
                        lTest = [];
                        lOut = [];
                    }
                }
                if (sValue != "") g_lSettings = SetSetting(g_lSettings, sID + sToken, sValue);
            }
        }
    }
}

LoadLinksetData()
{
    g_lSettings = []; // just to be sure
    integer iNumTokens = llLinksetDataCountKeys();
    list lKeys = llLinksetDataListKeys(0, iNumTokens);
    integer i;
    for (i = 0; i < llGetListLength(lKeys); i++)
    {
        string sKey = llList2String(lKeys,i);
        string sValue = llLinksetDataRead(sKey);

        if (llListFindList(g_lExceptionTokens, [SplitToken(sKey,0)]) == -1)
        {
            integer idx = llSubStringIndex(sValue, "~");
            if (idx) {
                string sToken = llGetSubString(sValue, 0, idx-1); // extract token from sValue
                sValue = llGetSubString(sValue, idx+1, -1); // strip token from sValue
                if (sValue != "") g_lSettings = SetSetting(g_lSettings, sKey+"_"+sToken, sValue);
            }
        }
    }
    lKeys = []; // force gc
}

PrintLinksetData()
{
    llOwnerSay("--- dump of linksetdata ---\n");
    integer iNumTokens = llLinksetDataCountKeys();
    list lKeys = llLinksetDataListKeys(0, iNumTokens);
    integer i;
    for (i = 0; i < llGetListLength(lKeys); i++)
    {
        string sKey = llList2String(lKeys,i);
        string sValue = llLinksetDataRead(sKey);

        if (llListFindList(g_lExceptionTokens, [SplitToken(sKey,0)]) == -1)
        {
            if (sValue != "")
                llOwnerSay(sKey+"="+sValue+"\n");
        }
    }
    lKeys = [];
}

SendValues()
{
    integer n;
    string sToken;
    list lOut;
    for (n = 0; n < llGetListLength(g_lSettings); n += 2) {
        sToken = llList2String(g_lSettings, n) + "=";
        sToken += llList2String(g_lSettings, n+1);
        if (llListFindList(lOut, [sToken]) == -1) lOut += [sToken];
    }
    n = 0;
    for (n = 0; n < llGetListLength(lOut); n++)
        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_RESPONSE, llList2String(lOut, n), "");
    llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_RESPONSE, "settings=sent", "");
    lOut = [];
}

UserCommand(integer iAuth, string sStr, key kID)
{
    string sStrLower = llToLower(sStr);
    if (sStrLower == "print settings" || sStrLower == "debug settings") PrintSettings(kID, llGetSubString(sStrLower, 0, 4));
    else if (llSubStringIndex(sStrLower,"load card") == 0) {
        if (iAuth == CMD_OWNER && kID != g_kTempOwner) {
            if (llGetInventoryKey(g_sCard) != NULL_KEY) {
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+ "\n\nLoading backup from "+g_sCard+" card. If you want to load settings from the web, please type: /%CHANNEL% %PREFIX% load url <url>\n\n", kID);
                llLinksetDataReset();
                g_lSettings = [];
                g_kLineID = llGetNotecardLine(g_sCard, g_iLineNr);
            } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"No "+g_sCard+" to load found.", kID);
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    } else if (llSubStringIndex(sStrLower,"save card") == 0) {
        if (iAuth == CMD_OWNER) SaveCard(kID);
    } else if (llSubStringIndex(sStrLower,"dump lsd") == 0) { // debug
        if (iAuth == CMD_OWNER) PrintLinksetData();
    } else if (sStrLower == "reboot" || sStrLower == "reboot --f") {
        if (g_iRebootConfirmed || sStrLower == "reboot --f") {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Rebooting your %DEVICETYPE% ....", kID);
            g_iRebootConfirmed = FALSE;
            llMessageLinked(LINK_ALL_OTHERS, REBOOT, "reboot", "");
            llSetTimerEvent(2.0);
        } else {
            g_kConfirmDialogID = llGenerateKey();
            llMessageLinked(LINK_DIALOG, DIALOG, (string)kID+"|\nAre you sure you want to reboot the %DEVICETYPE%?|0|Yes`No|Cancel|"+(string)iAuth, g_kConfirmDialogID);
        }
    } else if (sStrLower == "runaway") llSetTimerEvent(2.0);
}

PieSlice()
{
    if (llGetLinkNumber() == LINK_ROOT) return;
    if (llGetInventoryType("oc_installer_sys") == INVENTORY_SCRIPT) return;
    if (llGetAttached()) {
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, ZERO_VECTOR, PRIM_SIZE, <0.01, 0.01, 0.01>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.60, 0.80, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <0.753, 0.753, 1>, 0.0
        ]);
    } else { // rezzed on ground
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, <0,0,0.1>, PRIM_SIZE, <0.1, 0.1, 0.02>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.60, 0.80, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <0.753, 0.753, 1>, 1
        ]);
    }
}

default
{
    state_entry()
    {
        if (llGetStartParameter() == 825) llSetRemoteScriptAccessPin(0);
        if (llGetNumberOfPrims() > 5) g_lSettings = ["intern_dist", (string)llGetObjectDetails(llGetLinkKey(1), [27])];
        if (llGetInventoryType("OC_Cuffs_sync") == INVENTORY_SCRIPT) llRemoveInventory("OC_Cuffs_sync");
        llSleep(0.5);
        g_kWearer = llGetOwner();
        if (llGetStartParameter() == 0) {
            LoadLinksetData();
            llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_RESPONSE, llDumpList2String(g_lSettings, "="), "");
        }
        PieSlice();
    }

    on_rez(integer iParam)
    {
        if (g_kWearer == llGetOwner()) {
            PieSlice();
            llSetTimerEvent(2.0);
        }
        else llResetScript();
    }

    dataserver(key kID, string sData)
    {
        if (kID == g_kLineID) {
            if (sData != EOF) {
                ParseCardLine(sData, ++g_iLineNr);
                g_kLineID = llGetNotecardLine(g_sCard, g_iLineNr);
            } else {
                g_iLineNr = 0;
                ParseCardLine(sData, g_iLineNr);
                llSetTimerEvent(2.0);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == CMD_OWNER || kID == g_kWearer) UserCommand(iNum, sStr, kID);
        else if (iNum == LM_SETTING_SAVE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            g_lSettings = SetSetting(g_lSettings, sToken, sValue);
            if (sToken == "auth_tempowner" && sValue != "") g_kTempOwner = (key)sValue;
            if (LINK_CUFFS) {
                lParams = llParseString2List(sStr, ["_"], []);
                if (llListFindList(CUFFS_GROUPS,[llList2String(lParams, 0)]) != -1) llMessageLinked(LINK_CUFFS, LM_CUFF_SET, sStr, "");
            }
        }
        else if (iNum == LM_SETTING_REQUEST) {
            if (SettingExists(sStr)) llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_RESPONSE, sStr + "=" + GetSetting(sStr), "");
            else if (sStr == "ALL") {
                llSetTimerEvent(2.0);
            } else llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_EMPTY, sStr, "");
        }
        else if (iNum == LM_SETTING_DELETE) {
            DelSetting(sStr);
            if (LINK_CUFFS) {
                list lParams = llParseString2List(sStr, ["_"], []);
                if (llListFindList(CUFFS_GROUPS,[llList2String(lParams, 0)]) != -1) llMessageLinked(LINK_CUFFS, LM_CUFF_SET, sStr, "");
            }
        } else if (iNum == DIALOG_RESPONSE && kID == g_kConfirmDialogID) {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            kID = llList2Key(lMenuParams,0);
            if (llList2String(lMenuParams,1) == "Yes") {
                g_iRebootConfirmed = TRUE;
                UserCommand(llList2Integer(lMenuParams,3),"reboot",kID);
            } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Reboot aborted.", kID);
        } else if (iNum == LOADPIN && llSubStringIndex(llGetScriptName(), sStr) != -1) {
            integer iPin = (integer)llFrand(99999.0)+1;
            llSetRemoteScriptAccessPin(iPin);
            llMessageLinked(iSender, LOADPIN, (string)iPin+"@"+llGetScriptName(), llGetKey());
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_CUFFS") LINK_CUFFS = iSender;
            else if (sStr == "LINK_REQUEST") llMessageLinked(LINK_ALL_OTHERS, LINK_UPDATE, "LINK_SAVE", "");
        } else if (iNum == LM_CUFF_SET && sStr == "LINK_CUFFS") LINK_CUFFS = iSender;
        else if (iNum == REGION_CROSSED || iNum == REGION_TELEPORT) llSetTimerEvent(2.0);
    }

    timer()
    {
        llSetTimerEvent(0.0);
        SendValues();
    }
}

