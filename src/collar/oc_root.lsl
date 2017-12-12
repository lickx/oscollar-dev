 /*

 Copyright (c) 2017 virtualdisgrace.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. 
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */
 
// This plugin creates the root (or main), apps and settings menus,
// and has the default LOCK/UNLOCK button. It can also dispense the help
// and license files (if present in contents) and can print info/version.

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

key g_kWearer;

string g_sVersion = "6.7.0";

string g_sGlobalToken = "global_";
string g_sAbout;
string g_sDist;
string g_sSafeword = "RED";
integer g_iChannel = 1;
string g_sPrefix;
integer g_iLocked;
integer g_iHidden;
integer g_iLooks;
string g_sQuoter;
string g_sQuotation;
string g_sQuoteToken = "quote_";

list g_lTheseMenus;

Dialog(key kID, string sContext, list lButtons, list lArrows, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();

llMessageLinked(LINK_DIALOG,DIALOG,(string)kID+"|"+sContext+"|"+(string)iPage+"|"+llDumpList2String(lButtons,"`")+"|"+llDumpList2String(lArrows,"`")+"|"+(string)iAuth,kMenuID);
    integer index = llListFindList(g_lTheseMenus,[kID]);
    if (~index) 
        g_lTheseMenus = llListReplaceList(g_lTheseMenus,[kID,kMenuID,sName],index,index + 2);
    else 
        g_lTheseMenus += [kID,kMenuID,sName];
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
    sContext += "\n\n• Prefix: "+g_sPrefix;
    sContext += "\n• Channel: "+(string)g_iChannel;
    sContext += "\n• Safeword: "+g_sSafeword;
    if (g_sQuotation!="") {
        sContext += "\n\n“"+llDumpList2String(llParseStringKeepNulls(g_sQuotation, ["\\n"], []), "\n")+"”";
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
    if (llGetInventoryType("oc_stealth") == INVENTORY_SCRIPT) {
        if (g_iHidden) lButtons += ["☑ Stealth"];
        else lButtons += ["☐ Stealth"];
    } else lButtons += ["-"];
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
    if (osIsUUID(g_sDist)) {
        if (llKey2Name(g_sDist)!="") sContext += uri("agent/"+g_sDist);
        else sContext += "Hypergrid";
    }
    else sContext += "Unknown";
    sContext+="\n\n"+g_sAbout;
    sContext+="\n\nThe OpenCollar Six™ scripts were used in this product to an unknown extent. The OpenCollar project can't support this product. Relevant [https://raw.githubusercontent.com/VirtualDisgrace/opencollar/master/LICENSE license terms] still apply.";
    llDialog(kID,sContext,["OK"],-12345);
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
        if (osIsUUID(g_sDist)) {
            if (llKey2Name(g_sDist)!="") sMessage += uri("agent/"+g_sDist);
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
    }
}

Failsafe() {
    string sName = llGetScriptName();
    if(osIsUUID(sName)) return;
    if(sName != "oc_root") llRemoveInventory(sName);
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
    g_sPrefix = llToLower(llGetSubString(llKey2Name(llGetOwner()), 0, 1));
    Failsafe();
    llSetTimerEvent(1.0);
}

string uri(string sStr){
    return "secondlife:///app/"+sStr+"/inspect";
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
    link_message(integer sender, integer num, string sStr, key kID) {
        list lParams;
        if (num == MENUNAME_RESPONSE) {
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
        } else if (num == MENUNAME_REMOVE) {
            lParams = llParseString2List(sStr,["|"],[]);
            string sParentMenu = llList2String(lParams,0);
            string sSubMenu = llList2String(lParams,1);
            if (sParentMenu == "Apps") {
                integer index = llListFindList(g_lApps,[sSubMenu]);
                if (~index) g_lApps = llDeleteSubList(g_lApps,index,index);
            } else if (sSubMenu == "Size/Position") g_lAdjusters = [];
        } else if (num == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = sender;
            else if (sStr == "LINK_RLV") LINK_RLV = sender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = sender;
        } else if (num == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lTheseMenus,[kID]);
            if (~iMenuIndex) {
                lParams = llParseString2List(sStr,["|"],[]);
                kID = (key)llList2String(lParams,0);
                string sButton = llList2String(lParams,1);
                integer iPage = (integer)llList2String(lParams,2);
                integer iAuth = (integer)llList2String(lParams,3);
                string sMenu = llList2String(g_lTheseMenus,iMenuIndex + 1);
                g_lTheseMenus = llDeleteSubList(g_lTheseMenus,iMenuIndex - 1,iMenuIndex + 1);
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
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quotation=" + osReplaceString(g_sQuotation, "\n", "\\n", -1, 0), "");
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sQuoteToken + "quoter=" + g_sQuoter, "");
                }
            }
        } else if (num >= CMD_OWNER && num <= CMD_WEARER) UserCommand(num,sStr,kID,FALSE);
        else if (num == LM_SETTING_RESPONSE) {
            lParams = llParseString2List(sStr,["="],[]);
            string sToken = llList2String(lParams,0);
            string sValue = llList2String(lParams,1);
            if (sToken == g_sGlobalToken+"locked") g_iLocked = (integer)sValue;
            else if (sToken == g_sGlobalToken+"safeword") g_sSafeword = sValue;
            else if (sToken == "intern_dist") g_sDist = sValue;
            else if (sToken == "intern_looks") g_iLooks = (integer)sValue;
            else if (sToken == "channel") g_iChannel = (integer)sValue;
            else if (sToken == g_sGlobalToken+"prefix") g_sPrefix = sValue;
            else if (sToken == g_sQuoteToken+"quotation") g_sQuotation = sValue;
            else if (sToken == g_sQuoteToken+"quoter") g_sQuoter = sValue;
        } else if (num == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lTheseMenus,[kID]);
            g_lTheseMenus = llDeleteSubList(g_lTheseMenus,iMenuIndex - 1,iMenuIndex + 1);
        } else if (num == REBOOT && sStr == "reboot") llResetScript();
    }
    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if ((iChange & CHANGED_INVENTORY) && !llGetStartParameter()) {
            Failsafe();
            llSetTimerEvent(1.0);
            llMessageLinked(LINK_ALL_OTHERS,LM_SETTING_REQUEST,"ALL","");
        }
        if (iChange & CHANGED_COLOR)
            g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
        if (iChange & CHANGED_LINK)
            llMessageLinked(LINK_ALL_OTHERS,LINK_UPDATE,"LINK_REQUEST","");
    }
    timer() {
        MakeMenus();
        llSetTimerEvent(0.0);
    }
}




