
//  oc_dialog.lsl
//
//  Copyright (c) 2007 - 2017 Schmobag Hogfather, Nandana Singh,
//  Cleo Collins, Satomi Ahn, Joy Stipe, Wendy Starfall, littlemousy,
//  Romka Swallowtail, Garvin Twine et al.
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

integer CMD_ZERO = 0;

integer NOTIFY = 1002;
integer NOTIFY_OWNERS=1003;
integer SAY = 1004;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer REBOOT = -1000;
integer LOADPIN = -1904;
integer LM_SETTING_RESPONSE = 2002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer SENSORDIALOG = -9003;

integer g_iTimeOut = 300;
integer g_iReapeat = 5;

list g_lMenus;
integer g_iStrideLength = 12;

key g_kWearer = NULL_KEY;
string g_sGlobalToken = "global_";
integer g_iListenChan=1;
string g_sPrefix;
string g_sDeviceType = "collar";
string g_sDeviceName = "Collar";
string g_sWearerName;
list g_lOwners;

list g_lSensorDetails;
integer g_bSensorLock;
integer g_iSensorTimeout;
integer g_iSelectAviMenu;
integer g_iColorMenu;

list g_lColors = [
"Red",<1.00000, 0.00000, 0.00000>,
"Green",<0.00000, 1.00000, 0.00000>,
"Blue",<0.00000, 0.50196, 1.00000>,
"Yellow",<1.00000, 1.00000, 0.00000>,
"Pink",<1.00000, 0.50588, 0.62353>,
"Brown",<0.24314, 0.14902, 0.07059>,
"Purple",<0.62353, 0.29020, 0.71765>,
"Black",<0.00000, 0.00000, 0.00000>,
"White",<1.00000, 1.00000, 1.00000>,
"Barbie",<0.91373, 0.00000, 0.34510>,
"Orange",<0.96078, 0.60784, 0.00000>,
"Toad",<0.25098, 0.25098, 0.00000>,
"Khaki",<0.62745, 0.50196, 0.38824>,
"Pool",<0.14902, 0.88235, 0.94510>,
"Blood",<0.42353, 0.00000, 0.00000>,
"Gray",<0.70588, 0.70588, 0.70588>,
"Anthracite",<0.08627, 0.08627, 0.08627>,
"Midnight",<0.00000, 0.10588, 0.21176>
];

integer g_iIsLED;

string NameURI(key kID)
{
    return "secondlife:///app/agent/"+(string)kID+"/about";
}

string SubstitudeVars(string sMsg)
{
        if (sMsg == "%NOACCESS%") return "Access denied.";
        if (llSubStringIndex(sMsg, "%PREFIX%") != -1)
            sMsg = osReplaceString(sMsg, "%PREFIX%", g_sPrefix, -1, 0);
        if (llSubStringIndex(sMsg, "%CHANNEL%") != -1)
            sMsg = osReplaceString(sMsg, "%CHANNEL%", (string)g_iListenChan, -1, 0);
        if (llSubStringIndex(sMsg, "%DEVICETYPE%") != -1)
            sMsg = osReplaceString(sMsg, "%DEVICETYPE%", g_sDeviceType, -1, 0);
        if (llSubStringIndex(sMsg, "%WEARERNAME%") != -1)
            sMsg = osReplaceString(sMsg, "%WEARERNAME%", g_sWearerName, -1, 0);
        return sMsg;
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == NULL_KEY) return;
    sMsg = SubstitudeVars(sMsg);
    string sObjectName = llGetObjectName();
    if (g_sDeviceName != sObjectName) llSetObjectName(g_sDeviceName);
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID) != ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
    llSetObjectName(sObjectName);
}

NotifyOwners(string sMsg, string comments)
{
    integer n;
    integer iStop = llGetListLength(g_lOwners);
    for (n = 0; n < iStop; ++n) {
        key kAv = llList2Key(g_lOwners, n);
        if (comments == "ignoreNearby") {
            vector vOwnerPos = llList2Vector(llGetObjectDetails(kAv, [OBJECT_POS]), 0);
            if (vOwnerPos == ZERO_VECTOR || llVecDist(vOwnerPos, llGetPos()) > 20.0)
                Notify(kAv, sMsg,FALSE);
        } else Notify(kAv, sMsg,FALSE);
    }
}

Say(string sMsg, integer iWhisper)
{
    sMsg = SubstitudeVars(sMsg);
    string sObjectName = llGetObjectName();
    llSetObjectName("");
    if (iWhisper) llWhisper(0,"/me "+sMsg);
    else llSay(0, sMsg);
    llSetObjectName(sObjectName);
}

Dialog(key kRecipient, string sPrompt, list lMenuItems, list lUtilityButtons, integer iPage, key kID, integer iWithNums, integer iAuth,string extraInfo)
{
    integer iNumitems = llGetListLength(lMenuItems);
    integer iStart = 0;
    integer iMyPageSize = 12 - llGetListLength(lUtilityButtons);
    if (g_iSelectAviMenu) {
        iMyPageSize = iMyPageSize-3;
        if (iNumitems == 8) iMyPageSize = iMyPageSize-1;
        else if (iNumitems == 7) iMyPageSize = iMyPageSize-2;
    }
    string sPagerPrompt;
    if (iNumitems > iMyPageSize) {
        iMyPageSize = iMyPageSize-2;
        integer numPages = (iNumitems-1)/iMyPageSize;
        if (iPage>numPages) iPage = 0;
        else if (iPage < 0) iPage = numPages;
        iStart = iPage*iMyPageSize;
        sPagerPrompt = sPagerPrompt+"\nPage "+(string)(iPage+1)+"/"+(string)(numPages+1);
    }
    integer iEnd = iStart + iMyPageSize - 1;
    if (iEnd >= iNumitems) iEnd = iNumitems - 1;
    integer iPagerPromptLen = GetStringBytes(sPagerPrompt);
    if (iWithNums == -1) {
        integer iNumButtons = llGetListLength(lMenuItems);
        iWithNums = llStringLength((string)iNumButtons);
        while (iNumButtons--) {
            if (GetStringBytes(llList2String(lMenuItems,iNumButtons)) > 18) {
                jump longButtonName;
            }
        }
        iWithNums=0;
        @longButtonName;
    }
    string sNumberedButtons;
    integer iNBPromptlen;
    list lButtons;
    if (iWithNums) {
        integer iCur;
        sNumberedButtons="\n";
        for (iCur = iStart; iCur <= iEnd; iCur++) {
            string sButton = llList2String(lMenuItems, iCur);
            if (osIsUUID(sButton)) {
                if (g_iSelectAviMenu) sButton = NameURI((key)sButton);
                else if (llGetDisplayName((key)sButton)) sButton = llGetDisplayName((key)sButton);
                else sButton = llKey2Name((key)sButton);
            }
            string sButtonNumber = (string)iCur;
            while (llStringLength(sButtonNumber) < iWithNums)
                sButtonNumber = "0"+sButtonNumber;
            sButton = sButtonNumber + " " + sButton;
            sNumberedButtons += sButton+"\n";
            sButton = TruncateString(sButton, 24);
            if(g_iSelectAviMenu) sButton = sButtonNumber;
            lButtons += [sButton];
        }
        iNBPromptlen = GetStringBytes(sNumberedButtons);
    } else if (iNumitems > iMyPageSize) lButtons = llList2List(lMenuItems, iStart, iEnd);
    else  lButtons = lMenuItems;
    sPrompt = SubstitudeVars(sPrompt);
    integer iPromptlen = GetStringBytes(sPrompt);
    string sThisPrompt;
    string sThisChat;
    if (iPromptlen + iNBPromptlen + iPagerPromptLen < 512)
        sThisPrompt = sPrompt + sNumberedButtons + sPagerPrompt ;
    else if (iPromptlen + iPagerPromptLen < 512) {
        if (iPromptlen + iPagerPromptLen < 459)
            sThisPrompt = sPrompt + "\nPlease check nearby chat for button descriptions.\n" + sPagerPrompt;
        else sThisPrompt = sPrompt + sPagerPrompt;
        sThisChat = sNumberedButtons;
    } else {
        sThisPrompt = TruncateString(sPrompt, 510-iPagerPromptLen) + sPagerPrompt;
        sThisChat = sPrompt + sNumberedButtons;
    }
    integer iRemainingChatLen;
    while (iRemainingChatLen = llStringLength(sThisChat)) {
        if (iRemainingChatLen < 1015) {
            Notify(kRecipient, sThisChat, FALSE);
            sThisChat = "";
        } else {
            string sMessageChunk = TruncateString(sPrompt,1015);
            Notify(kRecipient, sMessageChunk, FALSE);
            sThisChat = llGetSubString(sThisChat, llStringLength(sMessageChunk), -1);
        }
    }
    integer iChan = llRound(llFrand(10000000)) + 100000;
    while (llListFindList(g_lMenus, [iChan]) != -1) iChan=llRound(llFrand(10000000)) + 100000;
    integer iListener = llListen(iChan, "", kRecipient, "");
    if (g_iIsLED) llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_FULLBRIGHT, ALL_SIDES, TRUE, PRIM_BUMP_SHINY, ALL_SIDES, PRIM_SHINY_NONE, PRIM_BUMP_NONE, PRIM_GLOW, ALL_SIDES, 0.4]);
    if (llGetListLength(lMenuItems+lUtilityButtons) > 0){
        list lNavButtons;
        if (iNumitems > iMyPageSize) lNavButtons=["◄","►"];
        llDialog(kRecipient, sThisPrompt, PrettyButtons(lButtons, lUtilityButtons, lNavButtons), iChan);
    }
    else llTextBox(kRecipient, sThisPrompt, iChan);
    if (g_iIsLED) llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_FULLBRIGHT, ALL_SIDES, FALSE, PRIM_BUMP_SHINY, ALL_SIDES, PRIM_SHINY_HIGH, PRIM_BUMP_NONE, PRIM_GLOW, ALL_SIDES, 0.0]);
    llSetTimerEvent(g_iReapeat);
    integer ts = llGetUnixTime() + g_iTimeOut;
    g_lMenus += [iChan, kID, iListener, ts, kRecipient, sPrompt, llDumpList2String(lMenuItems, "|"), llDumpList2String(lUtilityButtons, "|"), iPage, iWithNums, iAuth,extraInfo];
}

integer GetStringBytes(string sStr)
{
    sStr = llEscapeURL(sStr);
    integer l = llStringLength(sStr);
    list lAtoms = llParseStringKeepNulls(sStr, ["%"], []);
    return l - (2*llGetListLength(lAtoms)) + 2;
}

string TruncateString(string sStr, integer iBytes)
{
    sStr = llEscapeURL(sStr);
    integer j = 0;
    string sOut;
    integer l = llStringLength(sStr);
    for (j = 0; j < l; j++) {
        string c = llGetSubString(sStr, j, j);
        if (c == "%") {
            if (iBytes >= 2) {
                sOut += llGetSubString(sStr, j, j+2);
                j += 2;
                iBytes -= 2;
            }
        } else if (iBytes >= 1) {
            sOut += c;
            iBytes--;
        }
    }
    return llUnescapeURL(sOut);
}

list PrettyButtons(list lOptions, list lUtilityButtons, list lPagebuttons)
{
    list lSpacers;
    list lCombined = lOptions + lUtilityButtons + lPagebuttons;
    while (llGetListLength(lCombined) % 3 != 0 && llGetListLength(lCombined) < 12) {
        lSpacers += ["-"];
        lCombined = lOptions + lSpacers + lUtilityButtons + lPagebuttons;
    }
    lSpacers = lOptions = lUtilityButtons = lPagebuttons = [];
    integer u = llListFindList(lCombined, ["BACK"]);
    if (u != -1) lCombined = llDeleteSubList(lCombined, u, u);
    lCombined =   llList2List(lCombined, 9, 11) 
                + llList2List(lCombined, 6, 8)
                + llList2List(lCombined, 3, 5)
                + llList2List(lCombined, 0, 2);
    if (u != -1) lCombined = llListInsertList(lCombined, ["BACK"], 2);
    return lCombined;
}

RemoveMenuStride(integer iIndex)
{
    integer iListener = llList2Integer(g_lMenus, iIndex + 2);
    llListenRemove(iListener);
    g_lMenus = llDeleteSubList(g_lMenus, iIndex, iIndex + g_iStrideLength - 1);
}

CleanList()
{
    integer n = llGetListLength(g_lMenus) - g_iStrideLength;
    integer iNow = llGetUnixTime();
    for (; n >= 0; n -= g_iStrideLength) {
        if (iNow > llList2Integer(g_lMenus,n+3)) {
            llMessageLinked(LINK_ALL_OTHERS, DIALOG_TIMEOUT,"",llList2Key(g_lMenus,n+1));
            RemoveMenuStride(n);
        }
    }
    if (g_iSensorTimeout > iNow) {
        g_lSensorDetails = llDeleteSubList(g_lSensorDetails,0,3);
        if (llGetListLength(g_lSensorDetails)) dequeueSensor();
    }
}

ClearUser(key kRCPT)
{
    integer iIndex = llListFindList(g_lMenus, [kRCPT]);
    while (iIndex != -1) {
        RemoveMenuStride(iIndex -4);
        iIndex = llListFindList(g_lMenus, [kRCPT]);
    }
}

dequeueSensor()
{
    list lParams = llParseStringKeepNulls(llList2String(g_lSensorDetails,2), ["|"], []);
    list lSensorInfo = llParseStringKeepNulls(llList2String(lParams, 3), ["`"], []);
    if (llList2Integer(lSensorInfo, 2) == (integer)AGENT) g_iSelectAviMenu = TRUE;
    else g_iSelectAviMenu = FALSE;
    llSensor(llList2String(lSensorInfo, 0), llList2Key(lSensorInfo,1), llList2Integer(lSensorInfo,2), llList2Float(lSensorInfo,3), llList2Float(lSensorInfo,4));
    g_iSensorTimeout = llGetUnixTime()+10;
    llSetTimerEvent(g_iReapeat);
}

PieSlice()
{
    if (llGetLinkNumber() == LINK_ROOT) return;
    if (llGetInventoryType("oc_installer_sys")==INVENTORY_SCRIPT) return;
    if (llGetAttached()) {
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, ZERO_VECTOR, PRIM_SIZE, <0.01, 0.01, 0.01>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.20, 0.40, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <1.000, 1.000, 0.753>, 0.0
        ]);
    } else { // rezzed on ground
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, <0,0,0.1>, PRIM_SIZE, <0.1, 0.1, 0.02>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.20, 0.40, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <1.000, 1.000, 0.753>, 1
        ]);
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
        if (llGetStartParameter() == 825) llSetRemoteScriptAccessPin(0);
        g_kWearer = llGetOwner();
        if (llSubStringIndex(llGetObjectDesc(),"LED") == 0) g_iIsLED = TRUE;
        g_sPrefix = llToLower(llGetSubString(llKey2Name(g_kWearer),0,1));
        g_sWearerName = NameURI(g_kWearer);
        if (g_iIsLED == FALSE) PieSlice();
        llSetLinkPrimitiveParamsFast(LINK_THIS,[PRIM_NAME,g_sDeviceName]);
    }

    sensor(integer num_detected)
    {
        list lSensorInfo = llList2List(g_lSensorDetails, 0, 3);
        g_lSensorDetails = llDeleteSubList(g_lSensorDetails, 0, 3);
        list lParams = llParseStringKeepNulls(llList2String(lSensorInfo,2), ["|"], []);
        list lButtons = llParseStringKeepNulls(llList2String(lParams, 3), ["`"], []);
        string sFind = llList2String(lButtons, 5);
        integer bReturnFirstMatch = llList2Integer(lButtons, 6);
        lButtons=[];
        integer i;
        for (i = 0; i < num_detected; i++) {
            lButtons += llDetectedKey(i);
            if (bReturnFirstMatch || (sFind != "")) {
                if (llSubStringIndex(llToLower(llDetectedName(i)),llToLower(sFind))==0
                    || llSubStringIndex(llToLower(llGetDisplayName(llDetectedKey(i))),llToLower(sFind))==0 ) {
                    if (bReturnFirstMatch == FALSE) {
                        lButtons = [llDetectedKey(i)];
                        jump next;
                    }
                    llMessageLinked(LINK_ALL_OTHERS, DIALOG_RESPONSE, llList2String(lParams,0) + "|" + (string)llDetectedKey(i)+ "|0|" + llList2String(lParams,5), (key)llList2String(lSensorInfo,3));
                    if (llGetListLength(g_lSensorDetails) > 0)
                        dequeueSensor();
                    else g_bSensorLock=FALSE;
                    g_iSelectAviMenu = FALSE;
                    return;
                }

            }
        }
        @next;
        string sButtons = llDumpList2String(lButtons, "`");
        lParams = llListReplaceList(lParams, [sButtons], 3, 3);
        llMessageLinked(LINK_THIS, DIALOG, llDumpList2String(lParams, "|"), llList2Key(lSensorInfo, 3));
        if (llGetListLength(g_lSensorDetails) > 0)
            dequeueSensor();
        else g_bSensorLock = FALSE;
    }

    no_sensor()
    {
        list lSensorInfo = llList2List(g_lSensorDetails, 0, 3);
        g_lSensorDetails = llDeleteSubList(g_lSensorDetails, 0, 3);
        list lParams = llParseStringKeepNulls(llList2String(lSensorInfo, 2), ["|"], []);
        lParams = llListReplaceList(lParams, [""], 3, 3);
        llMessageLinked(LINK_THIS, DIALOG, llDumpList2String(lParams,"|"), llList2Key(lSensorInfo,3));
        if (llGetListLength(g_lSensorDetails) > 0)
            dequeueSensor();
        else {
            g_iSelectAviMenu = FALSE;
            g_bSensorLock = FALSE;
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == SENSORDIALOG){
            g_lSensorDetails += [iSender, iNum, sStr, kID];
            if (g_bSensorLock == FALSE){
                g_bSensorLock=TRUE;
                dequeueSensor();
            }
        } else if (iNum == DIALOG) {
            if (iSender != llGetLinkNumber()) g_iSelectAviMenu = FALSE;
            list lParams = llParseStringKeepNulls(sStr, ["|"], []);
            key kRCPT = llGetOwnerKey((key)llList2String(lParams, 0));
            string sPrompt = llList2String(lParams, 1);
            integer iPage = llList2Integer(lParams, 2);
            if (iPage < 0 ) {
                g_iSelectAviMenu = TRUE;
                iPage = 0;
            }
            list lButtons = llParseString2List(llList2String(lParams, 3), ["`"], []);
            if (llList2String(lButtons, 0) == "colormenu please") {
                lButtons = llList2ListStrided(g_lColors, 0, -1, 2);
                g_iColorMenu = TRUE;
            }
            integer iDigits = -1;
            list ubuttons = llParseString2List(llList2String(lParams, 4), ["`"], []);
            integer iAuth = CMD_ZERO;
            if (llGetListLength(lParams) >= 6) iAuth = llList2Integer(lParams, 5);
            ClearUser(kRCPT);
            Dialog(kRCPT, sPrompt, lButtons, ubuttons, iPage, kID, iDigits, iAuth,"");
        }
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sGlobalToken+"DeviceType") g_sDeviceType = sValue;
            else if (sToken == g_sGlobalToken+"DeviceName") {
                g_sDeviceName = sValue;
                llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_NAME,g_sDeviceName]);
            } else if (sToken == g_sGlobalToken+"WearerName") {
                if (llSubStringIndex(sValue, "secondlife:///app/agent") > 0)
                    g_sWearerName =  "["+NameURI(g_kWearer)+" " + sValue + "]";
                else g_sWearerName = sValue;
            } else if (sToken == g_sGlobalToken+"prefix") {
                if (sValue != "") g_sPrefix = sValue;
            } else if (sToken == g_sGlobalToken+"channel") g_iListenChan = (integer)sValue;
            else if (sToken == "auth_owner")
                g_lOwners = llParseString2List(sValue, [","], []);
        } else if (iNum == LOADPIN && llSubStringIndex(llGetScriptName(), sStr) != -1) {
            integer iPin = (integer)llFrand(99999.0)+1;
            llSetRemoteScriptAccessPin(iPin);
            llMessageLinked(iSender, LOADPIN, (string)iPin+"@"+llGetScriptName(), llGetKey());
        } else if (iNum == NOTIFY) Notify(kID, llGetSubString(sStr,1, -1), (integer)llGetSubString(sStr, 0, 0));
        else if (iNum == SAY) Say(llGetSubString(sStr,1, -1), (integer)llGetSubString(sStr, 0, 0));
        else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
            else if (sStr == "LINK_REQUEST") llMessageLinked(LINK_ALL_OTHERS, LINK_UPDATE, "LINK_DIALOG", "");
        } else if (iNum==NOTIFY_OWNERS) NotifyOwners(sStr,(string)kID);
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    listen(integer iChan, string sName, key kID, string sMessage)
    {
        integer iMenuIndex = llListFindList(g_lMenus, [iChan]);
        if (iMenuIndex != -1) {
            key kMenuID = llList2Key(g_lMenus, iMenuIndex + 1);
            key kAv = llList2Key(g_lMenus, iMenuIndex + 4);
            string sPrompt = llList2String(g_lMenus, iMenuIndex + 5);
            list items = llParseString2List(llList2String(g_lMenus, iMenuIndex + 6), ["|"], []);
            list ubuttons = llParseString2List(llList2String(g_lMenus, iMenuIndex + 7), ["|"], []);
            integer iPage = llList2Integer(g_lMenus, iMenuIndex + 8);
            integer iDigits = llList2Integer(g_lMenus, iMenuIndex + 9);
            integer iAuth = llList2Integer(g_lMenus, iMenuIndex + 10);
            string sExtraInfo = llList2String(g_lMenus, iMenuIndex + 11);
            RemoveMenuStride(iMenuIndex);
            if (sMessage == "►") Dialog(kID, sPrompt, items, ubuttons, ++iPage, kMenuID, iDigits, iAuth,sExtraInfo);
            else if (sMessage == "◄") Dialog(kID, sPrompt, items, ubuttons, --iPage, kMenuID, iDigits, iAuth, sExtraInfo);
            else if (sMessage == "-") Dialog(kID, sPrompt, items, ubuttons, iPage, kMenuID, iDigits, iAuth, sExtraInfo);
            else {
                g_iSelectAviMenu = FALSE;
                string sAnswer;
                integer iIndex = llListFindList(ubuttons, [sMessage]);
                if (iDigits && iIndex == -1) {
                    integer iBIndex = (integer) llGetSubString(sMessage, 0, iDigits);
                    sAnswer = llList2String(items, iBIndex);
                } else if (g_iColorMenu) {
                    integer iColorIndex = llListFindList(llList2ListStrided(g_lColors, 0, -1, 2), [sMessage]);
                    if (iColorIndex != -1) sAnswer = llList2String(llList2ListStrided(llDeleteSubList(g_lColors, 0, 0), 0, -1, 2), iColorIndex);
                    else sAnswer = sMessage;
                    g_iColorMenu = FALSE;
                } else sAnswer = sMessage;
                if (sAnswer == "") sAnswer = " ";
                llMessageLinked(LINK_ALL_OTHERS, DIALOG_RESPONSE, (string)kAv + "|" + sAnswer + "|" + (string)iPage + "|" + (string)iAuth, kMenuID);
            }
        }
    }

    timer()
    {
        CleanList();
        if (llGetListLength(g_lMenus) == 0 && llGetListLength(g_lSensorDetails) == 0) {
            g_iSelectAviMenu = FALSE;
            llSetTimerEvent(0.0);
        }
    }
}
