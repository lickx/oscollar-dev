
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
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;

key g_kWearer;

string g_sVersion = "6.8.5";

string g_sGlobalToken = "global_";
string g_sAbout;
string g_sDist;
string g_sSafeword = "RED";
integer g_iLocked;
integer g_iHidden;
integer g_iLooks;
string g_sQuoter;
string g_sQuotation;
string g_sQuoteToken = "quote_";
key g_kInstallerID;

list g_lMenus;

Dialog(key kID, string sContext, list lButtons, list lArrows, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();

llMessageLinked(LINK_DIALOG,DIALOG,(string)kID+"|"+sContext+"|"+(string)iPage+"|"+llDumpList2String(lButtons,"`")+"|"+llDumpList2String(lArrows,"`")+"|"+(string)iAuth,kMenuID);
    integer index = llListFindList(g_lMenus,[kID]);
    if (~index) 
        g_lMenus = llListReplaceList(g_lMenus,[kID,kMenuID,sName],index,index + 2);
    else 
        g_lMenus += [kID,kMenuID,sName];
}

list g_lApps;
list g_lAdjusters;
integer g_iMenuAnim;
integer g_iMenuRLV;
integer g_iMenuKidnap;

MenuRoot(key kID, integer iAuth) {
    string sContext = "\n";
    if (g_iLocked) sContext += "🔒 ";
    else sContext += "🔓 ";
    sContext += "O  s  C  o  l  l  a  r    "+g_sVersion;
    sContext += "\n\n• Prefix: %PREFIX%";
    sContext += "\n• Channel: %CHANNEL%";
    sContext += "\n• Safeword: "+g_sSafeword;
    if (g_sQuotation!="") {
        sContext += "\n\n“"+iwReplaceString(g_sQuotation, "\\n", "\n")+"”";
        if (g_sQuoter!="") sContext += "\n—"+g_sQuoter;
    }
    
    list lButtons = ["Apps"];
    if (g_iMenuAnim) lButtons += "Animations";
    else lButtons += "-";
    if (g_iMenuKidnap) lButtons += "Capture";
    else lButtons += "-";
    lButtons += ["Leash"];
    if (g_iMenuRLV) lButtons += "RLV";
    else lButtons += "-";
    lButtons += ["Access","Settings","About"];
    if (g_iLocked) lButtons = "UNLOCK" + lButtons;
    else lButtons = "LOCK" + lButtons;
    Dialog(kID,sContext,lButtons,[],0,iAuth,"Main");
}

MenuSettings(key kID, integer iAuth) {
    string sContext = "\nSettings";
    list lButtons = ["Print","Load","Save","Fix"];
    lButtons += g_lAdjusters;
    if (g_iHidden) lButtons += ["☑ Stealth"];
    else lButtons += ["☐ Stealth"];
    if (g_iLooks) lButtons += "Looks";
    else if (llGetInventoryType("oc_themes") == INVENTORY_SCRIPT)
        lButtons += "Themes";
    Dialog(kID,sContext,lButtons,["BACK"],0,iAuth,"Settings");
}

MenuApps(key kID, integer iAuth) {
    string sContext="\nApps, extras and custom features";
    Dialog(kID,sContext,g_lApps,["BACK"],0,iAuth,"Apps");
}

MenuAbout(key kID) {
    string sContext = "\nVersion: "+g_sVersion+"\nOrigin: ";
    if (iwVerifyType(g_sDist,TYPE_KEY)) {
        if (llKey2Name(g_sDist)!="") sContext += NameURI("agent/"+g_sDist);
        else sContext += "Hypergrid";
    }
    else sContext += "Unknown";
    sContext+="\n\n"+g_sAbout;
    sContext+="\n\nThe OpenCollar Six™ scripts were used in this product to an unknown extent. The OpenCollar project can't support this product. Relevant [https://raw.githubusercontent.com/VirtualDisgrace/opencollar/master/LICENSE license terms] still apply.";
    llDialog(kID,sContext,["OK"],-12345);
}

list g_lClosedLocks;
list g_lOpenLocks;
list g_lClosedLocksGlows;
list g_lOpenLocksGlows;

ShowHideLock() {
    if (g_iHidden) return;
    integer i;
    integer iLinks = llGetListLength(g_lOpenLocks);
    for (;i < iLinks; ++i) {
        llSetLinkAlpha(llList2Integer(g_lOpenLocks,i),!g_iLocked,ALL_SIDES);
        UpdateGlows(llList2Integer(g_lOpenLocks,i),!g_iLocked);
    }
    iLinks = llGetListLength(g_lClosedLocks);
    for (i=0; i < iLinks; ++i) {
        llSetLinkAlpha(llList2Integer(g_lClosedLocks,i),g_iLocked,ALL_SIDES);
        UpdateGlows(llList2Integer(g_lClosedLocks,i),g_iLocked);
    }
}

UpdateGlows(integer iLink, integer iAlpha) {
    list lGlows;
    integer iIndex;
    if (iAlpha) {
        lGlows = g_lOpenLocksGlows;
        if (g_iLocked) lGlows = g_lClosedLocksGlows;
        iIndex = llListFindList(lGlows,[iLink]);
        if (!(~iIndex)) llSetLinkPrimitiveParamsFast(iLink,[PRIM_GLOW,ALL_SIDES,llList2Float(lGlows,iIndex+1)]);
    } else {
        float fGlow = llList2Float(llGetLinkPrimitiveParams(iLink,[PRIM_GLOW,0]),0);
        lGlows = g_lClosedLocksGlows;
        if (g_iLocked) lGlows = g_lOpenLocksGlows;
        iIndex = llListFindList(lGlows,[iLink]);
        if ((~iIndex) && fGlow > 0) lGlows = llListReplaceList(lGlows,[fGlow],iIndex+1,iIndex+1);
        if ((~iIndex) && fGlow == 0) lGlows = llDeleteSubList(lGlows,iIndex,iIndex+1);
        if (!(~iIndex) && fGlow > 0) lGlows += [iLink,fGlow];
        if (g_iLocked) g_lOpenLocksGlows = lGlows;
        else g_lClosedLocksGlows = lGlows;
        llSetLinkPrimitiveParamsFast(iLink,[PRIM_GLOW,ALL_SIDES,0.0]);
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

Stealth (string sStr) {
    list lGlowy;
    if (sStr == "hide") g_iHidden = TRUE;
    else if (sStr == "show") g_iHidden = FALSE;
    else g_iHidden = !g_iHidden;
    llSetLinkAlpha(LINK_SET,(float)(!g_iHidden),ALL_SIDES);
    integer iCount;
    if (g_iHidden) {
        iCount = llGetNumberOfPrims();
        float fGlow;
        for (;iCount > 0; --iCount) {
            fGlow = llList2Float(llGetLinkPrimitiveParams(iCount,[PRIM_GLOW,0]),0);
            if (fGlow > 0) lGlowy += [iCount,fGlow];
        }
        llSetLinkPrimitiveParamsFast(LINK_SET,[PRIM_GLOW,ALL_SIDES,0.0]);
    } else {
        integer i;
        iCount = llGetListLength(lGlowy);
        for (;i < iCount;i += 2)
            llSetLinkPrimitiveParamsFast(llList2Integer(lGlowy,i),[PRIM_GLOW,ALL_SIDES,llList2Float(lGlowy,i+1)]);
        lGlowy = [];
    }
}

Update(){
    integer iPin = (integer)llFrand(99999998.0) + 1;
    llSetRemoteScriptAccessPin(iPin);
    integer iChanInstaller = -7483213;
    llRegionSayTo(g_kInstallerID,iChanInstaller,"ready|"+(string)iPin);
}

UserCommand(integer iAuth, string sStr, key kID, integer iClicked) {
    list lParams = llParseString2List(sStr,[" "],[]);
    string sCmd = llToLower(llList2String(lParams,0));
    sStr = llToLower(sStr);
    if (sCmd == "menu") {
        string sSubMenu = llToLower(llList2String(lParams,1));
        if (sSubMenu == "main" || sSubMenu == "") MenuRoot(kID,iAuth);
        else if (sSubMenu == "apps") MenuApps(kID,iAuth);
        else if (sSubMenu == "settings") {
            if (iAuth != CMD_OWNER && iAuth != CMD_WEARER) {
                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
                MenuRoot(kID,iAuth);
            } else MenuSettings(kID,iAuth);
        }
    } else if (sStr == "info" || sStr == "version") {
        string sMessage = "\n\nModel: "+llGetObjectName();
        sMessage += "\nVersion: "+g_sVersion+"\nOrigin: ";
        if (iwVerifyType(g_sDist,TYPE_KEY)) {
            if (llKey2Name(g_sDist)!="") sMessage += NameURI("agent/"+g_sDist);
            else sMessage += "Hypergrid";
        }
        else sMessage += "Unknown";
        sMessage += "\nUser: "+llGetUsername(g_kWearer);
        sMessage += "\nPrefix: %PREFIX%\nChannel: %CHANNEL%\nSafeword: "+g_sSafeword+"\n";
        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+sMessage,kID);
    } else if (sStr == "license") {
        if (llGetInventoryType(".license") == INVENTORY_NOTECARD) llGiveInventory(kID,".license");
        else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"There is no license file in this %DEVICETYPE%. Please request one directly from the creator!",kID);
    } else if (sStr == "help") {
        if (llGetInventoryType(".help") == INVENTORY_NOTECARD) llGiveInventory(kID,".help");
        else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"There is no help file in this %DEVICETYPE%. Please request one directly from the creator!",kID);
    } else if (sStr == "about") MenuAbout(kID);
    else if (sStr == "apps") MenuApps(kID,iAuth);
    else if (sStr == "settings") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) MenuSettings(kID,iAuth);
    } else if (sCmd == "fix") {
        MakeMenus();
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"I've fixed the menus.",kID);
    } else if (sCmd == "quote") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) {
            string sContext = "\nEnter a quote and press [Submit.]\n\n(Submit an empty field to cancel.)";
            Dialog(kID,sContext,[],[],0,iAuth,"Quote");
        } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
    } else if (sStr == "rm quote") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) {
            g_sQuotation = "";
            g_sQuoter = "";
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sQuoteToken + "quotation", "");
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sQuoteToken + "quoter", "");
        } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
    } else if (sStr == "lock") {
        if (iAuth == CMD_OWNER || kID == g_kWearer ) {
            g_iLocked = TRUE;
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sGlobalToken+"locked=1","");
            llMessageLinked(LINK_ROOT,LM_SETTING_RESPONSE,g_sGlobalToken+"locked=1","");
            llOwnerSay("@detach=n");
            llMessageLinked(LINK_RLV,RLV_CMD,"detach=n","main");
            llPlaySound("73f3f84b-0447-487d-8246-4ab3e5fdbf40",1.0);
            ShowHideLock();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"/me is locked.",kID);
        } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
    } else if (sStr == "runaway" || sStr == "unlock") {
        if (iAuth == CMD_OWNER)  {
            g_iLocked = FALSE;
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,g_sGlobalToken+"locked","");
            llMessageLinked(LINK_ROOT,LM_SETTING_RESPONSE,g_sGlobalToken+"locked=0","");
            llOwnerSay("@detach=y");
            llMessageLinked(LINK_RLV,RLV_CMD,"detach=y","main");
            llPlaySound("d64c3566-cf76-44b5-ae76-9aabf60efab8",1.0);
            ShowHideLock();
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"/me is unlocked.",kID);
        } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
    } else if (sStr == "hide" || sStr == "show" || sStr == "stealth") {
        if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) Stealth(sStr);
        else if (iwVerifyType(kID,TYPE_KEY)) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
    }
}

MakeMenus() {
    g_iMenuAnim = FALSE;
    g_iMenuRLV = FALSE;
    g_iMenuKidnap = FALSE;
    g_lAdjusters = [];
    g_lApps = [] ;
    llMessageLinked(LINK_SET,MENUNAME_REQUEST,"Main","");
    llMessageLinked(LINK_SET,MENUNAME_REQUEST,"Apps","");
    llMessageLinked(LINK_SET,MENUNAME_REQUEST,"Settings","");
    llMessageLinked(LINK_ALL_OTHERS,LINK_UPDATE,"LINK_REQUEST","");
}

Init() {
    g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
    GetLocks();
    llSetTimerEvent(1.0);
}

string NameURI(string sID) {
    return "secondlife:///app/"+sID+"/inspect";
}

default {
    state_entry() {
        //llSetMemoryLimit(32768);
        g_kWearer = llGetOwner();
        Init();
    }
    on_rez(integer iStart) {
        Init();
    }
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        list lParams;
        if (!llSubStringIndex(sStr,".- ... -.-") && kID == g_kWearer) {
            g_kInstallerID = (key)llGetSubString(sStr,-36,-1);
            Dialog(kID,"Ready to install?",["Yes", "No", "Cancel"],[],0,iNum,"Patch");
        } else if (iNum == MENUNAME_RESPONSE) {
            lParams = llParseString2List(sStr,["|"],[]);
            string sParentMenu = llList2String(lParams,0);
            string sSubMenu = llList2String(lParams,1);
            if (sParentMenu == "Apps") {
                if (!~llListFindList(g_lApps, [sSubMenu])) {
                    g_lApps += [sSubMenu];
                    g_lApps = llListSort(g_lApps,1,TRUE);
                }
            } else if (sStr == "Main|Animations") g_iMenuAnim = TRUE;
            else if (sStr == "Main|RLV") g_iMenuRLV = TRUE;
            else if (sStr == "Main|Capture") g_iMenuKidnap = TRUE;
            else if (sStr == "Settings|Size/Position") g_lAdjusters = ["Position","Rotation","Size"];
        } else if (iNum == MENUNAME_REMOVE) {
            lParams = llParseString2List(sStr,["|"],[]);
            string sParentMenu = llList2String(lParams,0);
            string sSubMenu = llList2String(lParams,1);
            if (sParentMenu == "Apps") {
                integer index = llListFindList(g_lApps,[sSubMenu]);
                if (~index) g_lApps = llDeleteSubList(g_lApps,index,index);
            } else if (sSubMenu == "Size/Position") g_lAdjusters = [];
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenus,[kID]);
            if (~iMenuIndex) {
                lParams = llParseString2List(sStr,["|"],[]);
                kID = (key)llList2String(lParams,0);
                string sButton = llList2String(lParams,1);
                integer iPage = (integer)llList2String(lParams,2);
                integer iAuth = (integer)llList2String(lParams,3);
                string sMenu = llList2String(g_lMenus,iMenuIndex + 1);
                g_lMenus = llDeleteSubList(g_lMenus,iMenuIndex - 1,iMenuIndex + 1);
                if (sMenu == "Main"){
                    if (sButton == "LOCK" || sButton== "UNLOCK")
                        llMessageLinked(LINK_ROOT,iAuth,sButton,kID);
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
                         UserCommand(iAuth,sButton,kID,TRUE);
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
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quotation=" + iwReplaceString(g_sQuotation, "\n", "\\n"), "");
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quoter=" + g_sQuoter, "");
                } else if (sMenu == "Patch") {
                    if (sButton == "Yes") Update();
                    else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"cancelled",kID);
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum,sStr,kID,FALSE);
        else if (iNum == LM_SETTING_RESPONSE) {
            lParams = llParseString2List(sStr,["="],[]);
            string sToken = llList2String(lParams,0);
            string sValue = llList2String(lParams,1);
            if (sToken == g_sGlobalToken+"locked") {
                g_iLocked = (integer)sValue;
                if (g_iLocked) llOwnerSay("@detach=n");
                ShowHideLock();
            } else if (sToken == g_sGlobalToken+"safeword") g_sSafeword = sValue;
            else if (sToken == "intern_dist") g_sDist = sValue;
            else if (sToken == "intern_looks") g_iLooks = (integer)sValue;
            else if (sToken == g_sQuoteToken+"quotation") g_sQuotation = sValue;
            else if (sToken == g_sQuoteToken+"quoter") g_sQuoter = sValue;
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenus,[kID]);
            g_lMenus = llDeleteSubList(g_lMenus,iMenuIndex - 1,iMenuIndex + 1);
        } else if (iNum == RLV_REFRESH || iNum == RLV_CLEAR) {
            if (g_iLocked) llMessageLinked(LINK_RLV, RLV_CMD,"detach=n","main");
            else llMessageLinked(LINK_RLV,RLV_CMD,"detach=y","main");
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }
    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if ((iChange & CHANGED_INVENTORY) && !llGetStartParameter()) {
            llSetTimerEvent(1.0);
            llMessageLinked(LINK_ALL_OTHERS,LM_SETTING_REQUEST,"ALL","");
        }
        if (iChange & CHANGED_COLOR) {
            integer iNewHide = !(integer)llGetAlpha(ALL_SIDES);
            if (g_iHidden != iNewHide) {
                g_iHidden = iNewHide;
                ShowHideLock();
            }
        }
        if (iChange & CHANGED_LINK) {
            GetLocks();
            llMessageLinked(LINK_ALL_OTHERS,LINK_UPDATE,"LINK_REQUEST","");
        }
    }
    timer() {
        MakeMenus();
        llSetTimerEvent(0.0);
    }
}






