
//  oc_root.lsl
//
//  Copyright (c) 2017 virtualdisgrace.com
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License. 
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  This file contains modifications by Lotek Ixtar
// 
//  This script creates the root (or main), apps and settings menus,
//  and has the default LOCK/UNLOCK functionality. It can also dispense
//  the help and license files (if present in contents) and can print
//  info/version. It can also be used to hide and show the whole device.

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

string g_sHeadline = "O  s  C  o  l  l  a  r";
// Example: string g_sHeadline = "Property of House Lannister";

string g_sAbout = "";
// Example: string g_sAbout = "This collar was forged by the mighty duergar of Undrendark!";

string g_sVersion = "6.9.0";
// Example: string g_sVersion = "1.0";

string g_sGroup = "";  // Group URI
// Example: string g_sGroup = "secondlife:///app/group/19657888-576f-83e9-2580-7c3da7c0e4ca/about";

string g_sLandmark = ""; // SLURL
// Example: string g_sLandmark = "http://maps.secondlife.com/secondlife/Hippo%20Hollow/128/128/2";

string g_sLocking = "73f3f84b-0447-487d-8246-4ab3e5fdbf40"; // key of the lock sound
string g_sUnlocking = "d64c3566-cf76-44b5-ae76-9aabf60efab8"; // key of the unlock sound

string g_sSafeword = "RED";

/*------------------------------------------------------------------------------
         Everything below this line should only by edited by scripters!
--------------------------------------------------------------------------------

     This plugin creates the root (or main), apps and settings menus,
     and has the default LOCK/UNLOCK button. It can also dispense the help
     and license files (if present in contents) and can print info/version.

     It also includes code for the tiny steam-engine behind the LOCK/UNLOCK
     button and can play different noises depending on lock/unlock action,
     and reveal or hide a lock element on the device. There is also dedicated
     logic for a stealth function that can optionally hide the whole device.

------------------------------------------------------------------------------*/

integer g_iBuild = 16;

integer CMD_OWNER = 500;
integer CMD_WEARER = 503;
integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer BUILD_REQUEST = 17760501;

key g_kWearer;

string g_sGlobalToken = "global_";
string g_sDist;
integer g_iLocked;
integer g_iHidden;
integer g_iLooks;

string g_sQuoter;
string g_sQuotation;
string g_sQuoteToken = "quote_";

//lock
list g_lClosedLocks;
list g_lOpenLocks;
list g_lClosedLocksGlows;
list g_lOpenLocksGlows;

ShowHideLock() {
    if (g_iHidden) return;
    integer i;
    integer iLinks = llGetListLength(g_lOpenLocks);
    for (;i < iLinks; ++i) {
        llSetLinkAlpha(llList2Integer(g_lOpenLocks,i), !g_iLocked, ALL_SIDES);
        UpdateGlows(llList2Integer(g_lOpenLocks,i),!g_iLocked);
    }
    iLinks = llGetListLength(g_lClosedLocks);
    for (i=0; i < iLinks; ++i) {
        llSetLinkAlpha(llList2Integer(g_lClosedLocks,i), g_iLocked, ALL_SIDES);
        UpdateGlows(llList2Integer(g_lClosedLocks,i), g_iLocked);
    }
}

UpdateGlows(integer iLink, integer iAlpha) {
    list lGlows;
    integer iIndex;
    if (iAlpha) {
        lGlows = g_lOpenLocksGlows;
        if (g_iLocked) lGlows = g_lClosedLocksGlows;
        iIndex = llListFindList(lGlows, [iLink]);
        if (iIndex == -1) llSetLinkPrimitiveParamsFast(iLink,[PRIM_GLOW,ALL_SIDES,llList2Float(lGlows,iIndex+1)]);
    } else {
        float fGlow = llList2Float(llGetLinkPrimitiveParams(iLink, [PRIM_GLOW,0]), 0);
        lGlows = g_lClosedLocksGlows;
        if (g_iLocked) lGlows = g_lOpenLocksGlows;
        iIndex = llListFindList(lGlows, [iLink]);
        if ((~iIndex) && fGlow > 0) lGlows = llListReplaceList(lGlows, [fGlow], iIndex+1, iIndex+1);
        if ((~iIndex) && fGlow == 0) lGlows = llDeleteSubList(lGlows, iIndex, iIndex+1);
        if (iIndex == -1 && fGlow > 0) lGlows += [iLink, fGlow];
        if (g_iLocked) g_lOpenLocksGlows = lGlows;
        else g_lClosedLocksGlows = lGlows;
        llSetLinkPrimitiveParamsFast(iLink,[PRIM_GLOW, ALL_SIDES, 0.0]);
    }
}

GetLocks() {
    g_lOpenLocks = [];
    g_lClosedLocks = [];
    integer i = llGetNumberOfPrims();
    string sPrimName;
    for (;i > 1; --i) {
        sPrimName = (string)llGetLinkPrimitiveParams(i,[PRIM_NAME]);
        if (sPrimName == "Lock" || sPrimName == "ClosedLock")
            g_lClosedLocks += i;
        else if (sPrimName == "OpenLock")
            g_lOpenLocks += i;
    }
}

//stealth
list g_lGlowy;
Stealth (string sStr) {
    if (sStr == "hide") g_iHidden = TRUE;
    else if (sStr == "show") g_iHidden = FALSE;
    else g_iHidden = !g_iHidden;
    llSetLinkAlpha(LINK_SET, (float)(!g_iHidden), ALL_SIDES);
    integer iCount;
    if (g_iHidden) {
        iCount = llGetNumberOfPrims();
        float fGlow;
        for (;iCount > 0; --iCount) {
            fGlow = llList2Float(llGetLinkPrimitiveParams(iCount, [PRIM_GLOW,0]), 0);
            if (fGlow > 0) g_lGlowy += [iCount, fGlow];
        }
        llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_GLOW, ALL_SIDES, 0.0]);
    } else {
        integer i;
        iCount = llGetListLength(g_lGlowy);
        for (;i < iCount;i += 2)
            llSetLinkPrimitiveParamsFast(llList2Integer(g_lGlowy,i),[PRIM_GLOW, ALL_SIDES, llList2Float(g_lGlowy, i+1)]);
        g_lGlowy = [];
    }
    ShowHideLock();
}

//menus
list g_lTheseMenus;

Dialog(key kID, string sContext, list lButtons, list lArrows, integer iPage, integer iAuth, string sName) {
    key kThatMenu = llGenerateKey();
    llMessageLinked(LINK_DIALOG,DIALOG,(string)kID+"|"+sContext+"|"+(string)iPage+"|"+llDumpList2String(lButtons,"`")+"|"+llDumpList2String(lArrows,"`")+"|"+(string)iAuth,kThatMenu);
    integer index = llListFindList(g_lTheseMenus, [kID]);
    if (~index)
        g_lTheseMenus = llListReplaceList(g_lTheseMenus, [kID,kThatMenu,sName], index, index + 2);
    else
        g_lTheseMenus += [kID,kThatMenu,sName];
}

list g_lApps;
list g_lAdjusters;
integer g_iMenuAnim;
integer iMenuRlv;
integer iMenuKidnap;

MenuRoot(key kID, integer iAuth) {
    string sContext = "\n" + g_sHeadline;
    sContext += "\n\nPrefix: %PREFIX%";
    sContext += "\nChannel: /%CHANNEL%";
    if (g_sSafeword) sContext += "\nSafeword: " + g_sSafeword;
    if (g_sQuotation != "") {
        sContext += "\n\n“" + osReplaceString(g_sQuotation, "\\n", "\n", -1, 0)+"”";
        if (g_sQuoter != "") sContext += "\n—"+g_sQuoter;
    }
    list lTheseButtons = ["Apps"];
    if (g_iMenuAnim) lTheseButtons += "Animations";
    else lTheseButtons += "-";
    if (iMenuKidnap) lTheseButtons += "Capture";
    else lTheseButtons += "-";
    lTheseButtons += ["Leash"];
    if (iMenuRlv) lTheseButtons += "RLV";
    else lTheseButtons += "-";
    lTheseButtons += ["Access","Settings","About"];
    if (g_iLocked) lTheseButtons = "UNLOCK" + lTheseButtons;
    else lTheseButtons = "LOCK" + lTheseButtons;
    Dialog(kID, sContext, lTheseButtons, [], 0, iAuth, "Main");
}

MenuSettings(key kID, integer iAuth) {
    string sContext = "\nSettings";
    list lTheseButtons = ["Print","Load","Save","Fix"];
    lTheseButtons += g_lAdjusters;
    if (g_iHidden) lTheseButtons += ["☑ Stealth"];
    else lTheseButtons += ["☐ Stealth"];
    if (g_iLooks) lTheseButtons += "Looks";
    else if (llGetInventoryType("oc_themes") == INVENTORY_SCRIPT)
        lTheseButtons += "Themes";
    Dialog(kID, sContext, lTheseButtons, ["BACK"], 0, iAuth, "Settings");
}

MenuApps(key kID, integer iAuth) {
    string sContext="\nApps & Plugins";
    Dialog(kID, sContext, g_lApps, ["BACK"], 0, iAuth, "Apps");
}

MenuAbout(key kID) {
    string sContext = "\nVersion: "+(string)g_sVersion+"\nOrigin: ";
    if (osIsUUID(g_sDist)) sContext += URI("agent/"+g_sDist);
    else sContext += "";
    sContext += "\n\n“"+g_sAbout+"”";
    sContext += "\n\n"+g_sGroup;
    sContext += "\n"+g_sLandmark;
    sContext += "\n\nOsCollar is based on the work of the Peanut and OpenCollar projects.";
    llDialog(kID, sContext, ["OK"], -12345);
}

Commands(integer iAuth, string sStr, key kID) {
    list lParams = llParseString2List(sStr,[" "],[]);
    string sCmd = llToLower(llList2String(lParams,0));
    sStr = llToLower(sStr);
    if (sCmd == "menu") {
        string sSubmenu = llToLower(llList2String(lParams,1));
        if (sSubmenu == "main" || sSubmenu == "") MenuRoot(kID, iAuth);
        else if (sSubmenu == "apps") MenuApps(kID, iAuth);
        else if (sSubmenu == "settings") {
            if (iAuth != CMD_OWNER && iAuth != CMD_WEARER) {
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
                MenuRoot(kID, iAuth);
            } else MenuSettings(kID, iAuth);
        }
    } else if (sCmd == "safeword") {
        string sNewSafeword = llList2String(lParams,1);
        if(llStringTrim(sNewSafeword, STRING_TRIM) != "") {
            g_sSafeword = sNewSafeword;
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You set a new safeword: "+g_sSafeword, g_kWearer);
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"safeword="+g_sSafeword, "");
            llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, g_sGlobalToken+"safeword="+g_sSafeword, "");
        } else
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Your safeword is: "+g_sSafeword, g_kWearer);
    } else if (sStr == "info" || sStr == "version") {
        string sMessage = "\n\nModel: "+llGetObjectName();
        sMessage += "\nVersion: "+(string)g_sVersion+"\nOrigin: ";
        if (osIsUUID(g_sDist)) sMessage += URI("agent/"+g_sDist);
        else sMessage += "Unknown";
        sMessage += "\nUser: "+llGetUsername(g_kWearer);
        sMessage += "\nPrefix: %PREFIX%\nChannel: %CHANNEL%\nSafeword: "+g_sSafeword+"\n";
        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+sMessage, kID);
    } else if (sStr == "license") {
        if (llGetInventoryType(".license") == INVENTORY_NOTECARD) llGiveInventory(kID, ".license");
        else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"There is no license file in this %DEVICETYPE%. Please request one directly from "+URI("agent/"+g_sDist)+"!", kID);
    } else if (sStr == "help") {
        if (llGetInventoryType(".help") == INVENTORY_NOTECARD) llGiveInventory(kID, ".help");
        else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"There is no help file in this %DEVICETYPE%. Please request one directly from "+URI("agent/"+g_sDist)+"!", kID);
    } else if (sStr == "about") MenuAbout(kID);
    else if (sStr == "apps") MenuApps(kID, iAuth);
    else if (sStr == "settings") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) MenuSettings(kID, iAuth);
    } else if (sCmd == "fix") {
        MakeMenus();
        //llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"The menus have been fixed.", kID);
    } else if (sCmd == "quote") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) {
            string sContext = "\nEnter a quote and press [Submit.]\n\n(Leave empty to cancel.)";
            Dialog(kID, sContext, [], [], 0, iAuth, "Quote");
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    } else if (sStr == "rm quote") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) {
            g_sQuotation = "";
            g_sQuoter = "";
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sQuoteToken + "quotation", "");
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sQuoteToken + "quoter", "");
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    } else if (sStr == "hide" || sStr == "show" || sStr == "stealth") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) Stealth(sStr);
        else if (kID != NULL_KEY) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    } else if (sStr == "lock") {
        if (iAuth == CMD_OWNER || kID == g_kWearer) {
            g_iLocked = TRUE;
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"locked=1", "");
            llMessageLinked(LINK_ROOT, LM_SETTING_RESPONSE, g_sGlobalToken+"locked=1", "");
            llOwnerSay("@detach=n");
            llMessageLinked(LINK_RLV, RLV_CMD, "detach=n", "main");
            llPlaySound(g_sLocking, 1.0);
            ShowHideLock();
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"/me is locked.", kID);
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);;
    } else if (sStr == "runaway" || sStr == "unlock") {
        if (iAuth == CMD_OWNER) {
            g_iLocked = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sGlobalToken+"locked", "");
            llMessageLinked(LINK_ROOT, LM_SETTING_RESPONSE, g_sGlobalToken+"locked=0", "");
            llOwnerSay("@detach=y");
            llMessageLinked(LINK_RLV, RLV_CMD, "detach=y", "main");
            llPlaySound(g_sUnlocking, 1.0);
            ShowHideLock();
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"/me is unlocked.", kID);
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    }
}

MakeMenus() {
    g_iMenuAnim = FALSE;
    iMenuRlv = FALSE;
    iMenuKidnap = FALSE;
    g_lAdjusters = [];
    g_lApps = [] ;
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Main", "");
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Apps", "");
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Settings", "");
    llMessageLinked(LINK_ALL_OTHERS, LINK_UPDATE, "LINK_REQUEST", "");
}

Init() {
    GetLocks();
    g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
    llSetTimerEvent(1.0);
}

string URI(string sStr) {
    return "secondlife:///app/"+sStr+"/inspect";
}

default {
    state_entry() {
        g_kWearer = llGetOwner();
        Init();
    }

    on_rez(integer iStart) {
        Init();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        list lParams;
        if (iNum == MENUNAME_RESPONSE) {
            lParams = llParseString2List(sStr, ["|"], []);
            string sParentMenu = llList2String(lParams, 0);
            string sSubmenu = llList2String(lParams, 1);
            if (sParentMenu == "Apps") {
                if (llListFindList(g_lApps, [sSubmenu]) == -1) {
                    g_lApps += [sSubmenu];
                    g_lApps = llListSort(g_lApps, 1, TRUE);
                }
            } else if (sStr == "Main|Animations") g_iMenuAnim = TRUE;
            else if (sStr == "Main|RLV") iMenuRlv = TRUE;
            else if (sStr == "Main|Capture") iMenuKidnap = TRUE;
            else if (sStr == "Settings|Size/Position") g_lAdjusters = ["Position","Rotation","Size"];
        } else if (iNum == MENUNAME_REMOVE) {
            lParams = llParseString2List(sStr, ["|"], []);
            string sParentMenu = llList2String(lParams,0);
            string sSubmenu = llList2String(lParams,1);
            if (sParentMenu == "Apps") {
                integer iIndex = llListFindList(g_lApps, [sSubmenu]);
                if (~iIndex) g_lApps = llDeleteSubList(g_lApps, iIndex, iIndex);
            } else if (sSubmenu == "Size/Position") g_lAdjusters = [];
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lTheseMenus, [kID]);
            if (~iMenuIndex) {
                lParams = llParseString2List(sStr, ["|"], []);
                kID = (key)llList2String(lParams,0);
                string sButton = llList2String(lParams,1);
                integer iAuth = (integer)llList2String(lParams,3);
                string sMenu = llList2String(g_lTheseMenus,iMenuIndex + 1);
                g_lTheseMenus = llDeleteSubList(g_lTheseMenus,iMenuIndex - 1,iMenuIndex + 1);
                if (sMenu == "Main") {
                    if (sButton == "LOCK" || sButton== "UNLOCK")
                        llMessageLinked(LINK_ROOT, iAuth, sButton, kID);
                    else if (sButton == "About") MenuAbout(kID);
                    else if (sButton == "Apps") MenuApps(kID,iAuth);
                    else llMessageLinked(LINK_SET,iAuth,"menu "+sButton,kID);
                } else if (sMenu == "Apps") {
                    if (sButton == "BACK") MenuRoot(kID,iAuth);
                    else llMessageLinked(LINK_SET,iAuth,"menu "+sButton,kID);
                } else if (sMenu == "Settings") {
                     if (sButton == "Print") llMessageLinked(LINK_SAVE,iAuth,"print settings",kID);
                     else if (sButton == "Load") llMessageLinked(LINK_SAVE,iAuth,sButton,kID);
                     else if (sButton == "Save") llMessageLinked(LINK_SAVE,iAuth,sButton,kID);
                     else if (sButton == "Fix") {
                         Commands(iAuth,sButton,kID);
                         return;
                    } else if (sButton == "☐ Stealth") {
                         llMessageLinked(LINK_ROOT,iAuth,"hide",kID);
                         g_iHidden = TRUE;
                    } else if (sButton == "☑ Stealth") {
                        llMessageLinked(LINK_ROOT,iAuth,"show",kID);
                        g_iHidden = FALSE;
                    } else if (sButton == "Themes") {
                        llMessageLinked(LINK_ROOT,iAuth,"menu Themes",kID);
                        return;
                    } else if (sButton == "Looks") {
                        llMessageLinked(LINK_ROOT,iAuth,"looks",kID);
                        return;
                    } else if (sButton == "BACK") {
                        MenuRoot(kID,iAuth);
                        return;
                    } else if (sButton == "Position" || sButton == "Rotation" || sButton == "Size") {
                        llMessageLinked(LINK_ROOT,iAuth,llToLower(sButton),kID);
                        return;
                    }
                    MenuSettings(kID,iAuth);
                } else if (sMenu == "Quote") {
                    if (sButton == "") return;
                    g_sQuoter = llKey2Name(kID);
                    g_sQuotation = sButton;
                    llOwnerSay("\n\n"+g_sQuoter+" cites a quote in "+llKey2Name(g_kWearer)+
                                "'s main menu:\n\n\""+g_sQuotation+"\"\n");
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quotation=" + osReplaceString(g_sQuotation, "\n", "\\n", -1, 0), "");
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quoter=" + g_sQuoter, "");
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) Commands(iNum,sStr,kID);
        else if (iNum == RLV_REFRESH || iNum == RLV_CLEAR) {
            if (g_iLocked) llMessageLinked(LINK_RLV, RLV_CMD,"detach=n","main");
            else llMessageLinked(LINK_RLV,RLV_CMD,"detach=y","main");
        } else if (iNum == LM_SETTING_RESPONSE) {
            lParams = llParseString2List(sStr,["="],[]);
            string sThisToken = llList2String(lParams,0);
            string sValue = llList2String(lParams,1);
            if (sThisToken == g_sGlobalToken+"locked") {
                g_iLocked = (integer)sValue;
                if (g_iLocked) llOwnerSay("@detach=n");
                ShowHideLock();
            } else if (sThisToken == g_sGlobalToken+"safeword") g_sSafeword = sValue;
            else if (sThisToken == "intern_dist") g_sDist = sValue;
            else if (sThisToken == "intern_looks") g_iLooks = (integer)sValue;
            else if (sThisToken == g_sQuoteToken+"quotation") g_sQuotation = sValue;
            else if (sThisToken == g_sQuoteToken+"quoter") g_sQuoter = sValue;
            else if (sStr == "settings=sent")
                llMessageLinked(LINK_SET,LM_SETTING_RESPONSE,g_sGlobalToken+"safeword="+g_sSafeword,"");
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lTheseMenus,[kID]);
            g_lTheseMenus = llDeleteSubList(g_lTheseMenus,iMenuIndex - 1,iMenuIndex + 1);
        } else if (iNum == BUILD_REQUEST)
            llMessageLinked(iSender,iNum+g_iBuild,llGetScriptName(),"");
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    changed(integer iChanges) {
        if (iChanges & CHANGED_OWNER) llResetScript();
        if ((iChanges & CHANGED_INVENTORY) && !llGetStartParameter()) {
            llSetTimerEvent(1.0);
            llMessageLinked(LINK_ALL_OTHERS,LM_SETTING_REQUEST,"ALL","");
        }
        if (iChanges & CHANGED_COLOR)
            g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
        if (iChanges & CHANGED_LINK) {
            GetLocks();
            llMessageLinked(LINK_ALL_OTHERS,LINK_UPDATE,"LINK_REQUEST","");
        }
    }

    timer() {
        MakeMenus();
        llSetTimerEvent(0.0);
    }
}
