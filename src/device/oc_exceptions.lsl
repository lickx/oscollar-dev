
//  oc_exceptions.lsl
//
//  Copyright (c) 2008 - 2016 Satomi Ahn, Nandana Singh, Joy Stipe,
//  Wendy Starfall, Medea Destiny, Garvin Twine, littlemousy,
//  Romka Swallowtail et al.
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

list g_lMenuIDs;
integer g_iMenuStride = 3;

list g_lOwners;
list g_lSecOwners;
list g_lTempOwners;

string g_sParentMenu = "RLV";
string g_sSubMenu = "Exceptions";

integer OWNER_DEFAULT = 127;
integer TRUSTED_DEFAULT = 110;

integer g_iOwnerDefault = 127;
integer g_iTrustedDefault = 110;
list g_lSettings;

list g_lRLVcmds = [
    "sendim",
    "recvim",
    "recvchat",
    "recvemote",
    "tplure",
    "accepttp",
    "startim"
        ];

list g_lBinCmds = [
    8,
    4,
    2,
    32,
    1,
    16,
    8
        ];

list g_lPrettyCmds = [
    "IM",
    "RcvIM",
    "RcvChat",
    "RcvEmote",
    "Lure",
    "refuseTP"
        ];

list g_lDescriptionsOn = [
    "Can send or start IMs even when blocked",
    "Can receive their IMs even when blocked",
    "Can see their Chat even when blocked",
    "Can see their Emotes even when blocked",
    "Can receive their Teleport offers even when blocked",
    "Wearer cannot refuse a tp offer from them"
];
list g_lDescriptionsOff =[
    "Sending and starting IMs to them can be blocked",
    "Receiving IMs from them can be blocked",
    "Seeing chat from them can be blocked",
    "Seeing emotes from them can be blocked",
    "Teleport offers from them can be blocked",
    "Wearer can refuse their tp offers"
        ];

string TURNON = "☐";
string TURNOFF = "☑";

integer g_iRLVOn;

key g_kWearer;

integer CMD_OWNER = 500;
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

integer RLV_CLEAR = 6002;

integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

string g_sSettingToken = "rlvex_";

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth,string sMenuID) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

Menu(key kID, integer iAuth) {
    if (!g_iRLVOn) {
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"RLV features are now disabled in this %DEVICETYPE%. You can enable those in RLV submenu. Opening it now.",kID);
        llMessageLinked(LINK_RLV, iAuth, "menu RLV", kID);
        return;
    }
    list lButtons = ["Owner", "Trusted"];
    string sPrompt = "\nExceptions\n\nSet execptions to the restrictions for RLV commands.\n\n(\"Force Teleports\" are already defaulted for Owners.)";
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "main");
}

ExMenu(key kID, string sWho, integer iAuth) {
    if (!g_iRLVOn) {
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"RLV features are now disabled in this %DEVICETYPE%. You can enable those in RLV submenu. Opening it now.",kID);
        llMessageLinked(LINK_RLV, iAuth, "menu RLV", kID);
        return;
    }
    integer iExSettings = 0;
    integer iInd;
    if (sWho == "owner" || ~llListFindList(g_lOwners, [sWho]))
        iExSettings = g_iOwnerDefault;
    else if (sWho == "trusted" || ~llListFindList(g_lSecOwners, [sWho]))
        iExSettings = g_iTrustedDefault;
    iInd = llListFindList(g_lSettings, [sWho]);
    if (~iInd)
        iExSettings = llList2Integer(g_lSettings, iInd + 1);

    string sPrompt = "\nCurrent Settings for "+sWho+": "+"\n";
    list lButtons;
    integer n;
    for (; n < llGetListLength(g_lPrettyCmds); n++) {
        string sPretty = llList2String(g_lPrettyCmds, n);
        if (iExSettings & llList2Integer(g_lBinCmds, n)) {
            lButtons += [TURNOFF + " " + sPretty];
            sPrompt += "\n" + llList2String(g_lDescriptionsOn,n)+".";
        } else {
            lButtons += [TURNON + " " + sPretty];
            sPrompt += "\n" + llList2String(g_lDescriptionsOff,n)+".";
        }
    }
    lButtons += ["All","None"];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "ex "+sWho);
}

SaveDefaults() {
    if (OWNER_DEFAULT == g_iOwnerDefault && TRUSTED_DEFAULT == g_iTrustedDefault) {
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "owner", "");
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "trusted", "");
        return;
    }
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "owner=" + (string)g_iOwnerDefault, "");
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "trusted=" + (string)g_iTrustedDefault, "");
}

SaveSettings() {
    if (llGetListLength(g_lSettings))
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "List=" + llDumpList2String(g_lSettings, ","), "");
    else
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "List", "");
}

SetAllExs() {
    if (!g_iRLVOn) return;
    integer iStop = llGetListLength(g_lRLVcmds);
    integer n;
    integer i;
    string sRLVCmd = "@";
    integer iLength = llGetListLength(g_lSecOwners);
    for (n = 0; n < iLength; ++n) {
        string sTmpOwner = llList2String(g_lSecOwners, n);
        if (llListFindList(g_lSettings, [sTmpOwner]) == -1 && sTmpOwner!=g_kWearer) {
            for (i = 0; i<iStop; i++) {
                if (g_iTrustedDefault & llList2Integer(g_lBinCmds, i) )
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n";
                else
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y";
                llOwnerSay(sRLVCmd);
                sRLVCmd = "@";
            }
        }
    }
    iLength = llGetListLength(g_lOwners+g_lTempOwners);
    for (n = 0; n < iLength; ++n) {
        string sTmpOwner = llList2String(g_lOwners+g_lTempOwners, n);
        if (llListFindList(g_lSettings, [sTmpOwner]) == -1 && sTmpOwner!=g_kWearer) {
            for (i = 0; i<iStop; i++) {
                if (g_iOwnerDefault & llList2Integer(g_lBinCmds, i) )
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n";
                else
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y";
                llOwnerSay(sRLVCmd);
                sRLVCmd = "@";
            }
        }
    }
    iLength = llGetListLength(g_lSettings);
    for (n = 0; n < iLength; n += 2) {
        string sTmpOwner = llList2String(g_lSettings, n);
        if(sTmpOwner!=g_kWearer) {
            integer iTmpOwner = llList2Integer(g_lSettings, n+1);
            for (i = 0; i<iStop; i++) {
                if (iTmpOwner & llList2Integer(g_lBinCmds, i) )
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n";
                else
                    sRLVCmd += llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y";
            }
            llOwnerSay(sRLVCmd);
            sRLVCmd = "@";
        }
    }
}

ClearEx() {
    if (g_iRLVOn) {
        integer i = llGetListLength(g_lRLVcmds);
        do { i--;
            llOwnerSay("@clear="+llList2String(g_lRLVcmds,i));
        } while (i);
    }
}

UserCommand(integer iNum, string sStr, key kID) {
    string sLower = llToLower(sStr);
    if (iNum != CMD_OWNER) {
        if (sLower == "ex" || sLower == "menu exceptions") {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
            llMessageLinked(LINK_RLV, iNum, "menu rlv", kID);
        }
        return;
    }
    if (sLower == "ex" || sLower == "menu " + llToLower(g_sSubMenu)) {
        Menu(kID,iNum);
        jump UCDone;
    }
    list lParts = llParseString2List(sStr, [" "], []);
    integer iInd = llGetListLength(lParts);
    if (iInd < 1 || iInd > 4 || llList2String(lParts, 0) != "ex") return;
    lParts = llDeleteSubList(lParts, 0, 0);
    iInd = llGetListLength(lParts);
    string sCom = llList2String(lParts, 0);
    if (iInd == 1) {
        if (sCom == "owner") ExMenu(kID, "owner", iNum);
        else if (sCom == "trusted") ExMenu(kID, "trusted", iNum);
        if (!llSubStringIndex(sCom, ":")) jump UCDone;
    }
    string sVal = llList2String(lParts, 1);
    lParts = llParseString2List(llList2String(lParts, 0), [":"], []);
    iInd = llGetListLength(lParts) - 1;
    list lCom;
    string sWho;
    integer bChange;
    integer iRLV;
    integer iBin;
    integer iSet;
    integer iNames;
    integer iL = 0;
    integer iC = 0;
    for (; iL < iInd; iL += 2) {
        sWho = llList2String(lParts, iL);
        string sWhoName;
        if (osIsUUID(sWho)) sWhoName = "secondlife:///app/agent/"+sWho+"/about";
        else sWhoName = sWho;
        sLower = llToLower(sWho);
        if (~llListFindList(g_lOwners, [sWho])) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"You cannot set exceptions for "+sWhoName + " different from other Owners, unless you use terminal.",kID);
            jump nextwho;
        } else if (~llListFindList(g_lSecOwners, [sWho])) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"You cannot set exceptions for "+sWhoName + " different from other Trusted, unless you use terminal.",kID);
            jump nextwho;
        }
        lCom = llParseString2List(llToLower(llList2String(lParts, iL + 1)), [","], []);
        sCom = llList2String(lCom, 0);
        if (llGetSubString(sCom, 0, 3) == "all=") {
            lCom = [];
            sVal = llGetSubString(sCom, 3, -1);
            for (iC = 0; iC < llGetListLength(g_lRLVcmds); iC++)
                lCom += [llList2String(g_lRLVcmds, iC) + sVal];
        }
        for (iC = 0; iC < llGetListLength(lCom); iC++) {
            sCom = llList2String(lCom, iC);
            if (sCom == "clear") jump nextcom;
            iNames = llSubStringIndex(sCom, "=");
            if (~iNames) {
                sVal = llGetSubString(sCom, iNames + 1, -1);
                sCom = llGetSubString(sCom, 0, iNames -1);
            } else sVal = "";
            if (sVal == "exempt" || sVal == "add") sVal = "n";
            else if (sVal == "enforce" || sVal == "rem") sVal = "y";
            iRLV = llListFindList(g_lRLVcmds, [sCom]);
            if (iRLV == -1 && sCom != "defaults") jump nextcom;
            iBin = llList2Integer(g_lBinCmds, iRLV);
            if (sWho == "owner") {
                if (sCom == "defaults") g_iOwnerDefault = OWNER_DEFAULT;
                else if (sVal == "n") g_iOwnerDefault = g_iOwnerDefault | iBin;
                else if (sVal == "y") g_iOwnerDefault = g_iOwnerDefault & ~iBin;
                bChange = bChange | 1;
                jump nextcom;
            } else if (sWho == "trusted") {
                if (sCom == "defaults") g_iTrustedDefault = TRUSTED_DEFAULT;
                else if (sVal == "n") g_iTrustedDefault = g_iTrustedDefault | iBin;
                else if (sVal == "y") g_iTrustedDefault = g_iTrustedDefault & ~iBin;
                bChange = bChange | 1;
                jump nextcom;
            }
            iNames = llListFindList(g_lSettings, [sWho]);
            if (sCom == "defaults") {
                if (~iNames) g_lSettings = llDeleteSubList(g_lSettings, iNames, iNames + 1);
                bChange = bChange | 2;
                jump nextcom;
            }
            if (~iNames) iSet = llList2Integer(g_lSettings, iNames + 1);
            else if (~llListFindList(g_lOwners, [sWho])) iSet = g_iOwnerDefault;
            else if (~llListFindList(g_lSecOwners, [sWho])) iSet = g_iTrustedDefault;
            else iSet = 0;
            if (sVal == "n") iSet = iSet | iBin;
            else if (sVal == "y") iSet = iSet & ~iBin;
            else jump nextcom;
            if (~iNames) g_lSettings = llListReplaceList(g_lSettings, [iSet], iNames + 1, iNames + 1);
            else g_lSettings += [sWho, iSet];
            bChange = bChange | 2;
            @nextcom;
        }
        @nextwho;
        if (bChange) {
            SetAllExs();
            if(bChange & 1) SaveDefaults();
            if(bChange & 2) SaveSettings();
        }
    }
    @UCDone;
}

default {
    on_rez(integer iParam) {
        llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID);
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "owner") g_iOwnerDefault = (integer)sValue;
                else if (sToken == "trusted") g_iTrustedDefault = (integer)sValue;
            } else if (llGetSubString(sToken, 0, i) == "auth_") {
                if (sToken == "auth_owner") g_lOwners = llParseString2List(sValue, [","], []);
                else if (sToken == "auth_trust") g_lSecOwners = llParseString2List(sValue, [","], []);
                else if (sToken == "auth_tempowner") g_lTempOwners = llParseString2List(sValue, [","], []);
                ClearEx();
                SetAllExs();
            } else if (sToken == "settings") {
                if (sValue == "sent") SetAllExs();
            }
        } else if (iNum == RLV_CLEAR) {
            llSleep(2.0);
            SetAllExs();
        } else if (iNum == RLV_OFF) {
            ClearEx();
            g_iRLVOn= FALSE;
        } else if (iNum == RLV_ON) {
            g_iRLVOn = TRUE;
            SetAllExs();
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenu == "main") {
                    if (sMessage == UPMENU)
                        llMessageLinked(LINK_RLV, iAuth, "menu " + g_sParentMenu, kAv);
                    else if (sMessage == "Owner")
                        ExMenu(kAv, "owner", iAuth);
                    else if (sMessage == "Trusted")
                        ExMenu(kAv, "trusted", iAuth);

                } else if (llGetSubString(sMenu,0,1) == "ex") {
                    if (sMessage == UPMENU) Menu(kAv,iAuth);
                    else {
                        list lParams = llParseString2List(sMessage, [" "], []);
                        string sSwitch = llList2String(lParams, 0);
                        string sCmd = llList2String(lParams, 1);
                        string sOut = sMenu + ":";
                        sMenu = llGetSubString(sMenu,3,-1);
                        integer iIndex = llListFindList(g_lPrettyCmds, [sCmd]);
                        if (sSwitch == "All") {
                            sOut += "all=n";
                            UserCommand(iAuth, sOut, kAv);
                            ExMenu(kAv, sMenu, iAuth);
                        } else if (sSwitch == "None") {
                            sOut += "all=y";
                            UserCommand(iAuth, sOut, kAv);
                            ExMenu(kAv, sMenu, iAuth);
                        } else if (~iIndex) {
                            sOut += llList2String(g_lRLVcmds, iIndex);
                            if (sSwitch == TURNOFF) sOut += "=y";
                            else if (sSwitch == TURNON) sOut += "=n";
                            UserCommand(iAuth, sOut, kAv);
                            ExMenu(kAv, sMenu, iAuth);
                        } else if (sMessage == "Defaults") {
                            UserCommand(iAuth, sOut + "defaults", kAv);
                            ExMenu(kAv, sMenu, iAuth);
                        }
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }
}
