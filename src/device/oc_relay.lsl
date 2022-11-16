
//  oc_relay.lsl
//
//  Copyright (c) 2008 - 2017 Satomi Ahn, Nandana Singh, Wendy Starfall,
//  Sumi Perl, littlemousy, Romka Swallowtail, Garvin Twine et al.
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
string g_sSubMenu = "Relay";
float g_fPause = 10;

integer RELAY_CHANNEL = -1812221819;
integer SAFETY_CHANNEL = -201818;
integer g_iRlvListener;
integer g_iSafetyListener;

integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_WEARER = 503;
integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;
integer CMD_RELAY_SAFEWORD = 511;

integer NOTIFY = 1002;

integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer REBOOT = -1000;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

key g_kWearer;
string g_sSettingsToken = "relay_";

list g_lMenuIDs;
integer g_iMenuStride = 3;

integer g_iGarbageRate = 60;

string g_sSourceID;

string g_sTempTrustObj;
string g_sTempTrustUser;
key g_kObjectUser;

list g_lBlockObj;
list g_lBlockAv;

integer g_iRLV = FALSE;
list g_lQueue;
integer g_iRecentSafeword;

integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

list g_lOwner;
string g_sTempOwner;
list g_lTrust;
list g_lBlock;

integer g_iMinBaseMode;
integer g_iMinHelplessMode ;
integer g_iBaseMode = 2;
integer g_iHelpless;

integer g_iSmartStrip = TRUE;
integer g_iAllowAttach = FALSE; // when TRUE, disallow @addattach=n restraint

key g_kDebugRcpt;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

key SanitizeKey(string uuid) {
    if (osIsUUID(uuid)) return llToLower(uuid);
    return NULL_KEY;
}

RelayNotify(key kID, string sMessage, integer iNofityWearer) {
    string sObjectName = llGetObjectName();
    llSetObjectName("Relay");
    if (kID == g_kWearer) llOwnerSay(sMessage);
    else {
        llRegionSayTo(kID,0,sMessage);
        if (iNofityWearer) llOwnerSay(sMessage);
    }
    llSetObjectName(sObjectName);
}

UpdateMode(integer iMode) {
    g_iBaseMode = iMode & 3;
    if (g_iBaseMode == 1) g_iBaseMode = 2;
    g_iHelpless = (iMode >> 2) & 1;
    g_iMinBaseMode = (iMode >> 5) & 3;
    if (g_iMinBaseMode == 1) g_iMinBaseMode = 2;
    g_iMinHelplessMode = (iMode >> 7) & 1;
    g_iSmartStrip = (iMode >> 10) & 1;
}

SaveMode() {
    string sMode = (string)(1024*g_iSmartStrip + 512*128*g_iMinHelplessMode + 32*g_iMinBaseMode + 4*g_iHelpless + g_iBaseMode);
    llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sSettingsToken+"mode="+sMode,"");
}

integer Auth(string sObjectID, string sUserID) {
    integer iAuth = 1;
    string sOwner = llGetOwnerKey(sObjectID);
    if (sObjectID == g_sSourceID) {}
    else if (~llListFindList(g_lBlockObj,[sObjectID])) return -1;
    else if (~llListFindList(g_lBlockAv+g_lBlock,[sOwner])) return -1;
    else if (g_iBaseMode == 3) {}
    else if (g_sTempTrustObj == sObjectID) {}
    else if (~llListFindList(g_lOwner+g_lTrust+[g_sTempOwner],[sOwner])) {}
    else iAuth = 0;
    if (osIsUUID(sUserID)) {
        if (~llListFindList(g_lBlock+g_lBlockAv,[sUserID])) return -1;
        else if (g_iBaseMode == 3) {}
        else if (g_sTempTrustUser == sUserID) {}
        else if (~llListFindList(g_lOwner+g_lTrust+[g_sTempOwner],[sUserID])) {}
        else return 0;
    }
    return iAuth;
}

string NameURI(string sID) {
    return "secondlife:///app/agent/"+sID+"/inspect";
}

string ObjectURI(string sID) {
    vector vPos = llGetPos();
    string surl = llEscapeURL(llGetRegionName())+"/"+(string)((integer)(vPos.x))+"/"+"/"+(string)((integer)(vPos.y))+"/"+(string)((integer)(vPos.z));
    return "secondlife:///app/objectim/"+sID+"?name="+llEscapeURL(llKey2Name(sID))+"&owner="+(string)llGetOwnerKey(sID)+"&slurl="+surl;
}

string HandleCommand(string sIdent, key kID, string sCom, integer iAuthed) {
    list lCommands=llParseString2List(sCom,["|"],[]);
    sCom = llList2String(lCommands, 0);
    string sAck;
    integer i;
    for (i=0;i<llGetListLength(lCommands);++i) {
        sCom = llList2String(lCommands,i);
        list lSubArgs = llParseString2List(sCom,["="],[]);
        string sVal = llList2String(lSubArgs,1);
        sAck = "ok";
        if (sCom == "!release" || sCom == "@clear") {
            llMessageLinked(LINK_RLV,RLV_CMD,"clear",kID);
            g_sSourceID = g_sTempTrustObj =  g_sTempTrustUser = "";
        } else if (sCom == "!version") sAck = "1100";
        else if (sCom == "!implversion") sAck = "relay_171201";
        else if (sCom == "!x-orgversions") sAck = "ORG=0003/who=001";
        else if (llGetSubString(sCom,0,0) == "!") sAck = "ko";
        else if (llGetSubString(sCom,0,0) != "@") {
             RelayNotify(g_kWearer,"\n\nBad command from "+llKey2Name(kID)+".\n\nCommand: "+sIdent+","+(string)g_kWearer+"\n\nFaulty subcommand: "+sCom+"\n\nPlease report to the maker of this device.\n",0);
            sAck = "";
        } else if ((!llSubStringIndex(sCom,"@version"))||(!llSubStringIndex(sCom,"@get"))||(!llSubStringIndex(sCom,"@findfolder"))) {
            if ((integer)sVal) llMessageLinked(LINK_RLV,RLV_CMD,llGetSubString(sCom,1,-1),kID);
            else sAck="ko";
        } else if (!iAuthed) return "need auth";
        else if (llGetListLength(lSubArgs)==2) {
            string sBehav=llGetSubString(llList2String(lSubArgs,0),1,-1);
            if (g_iSmartStrip && llSubStringIndex(sBehav,"remoutfit:")==0 && sVal=="force")
                sBehav="detachallthis:"+llDeleteSubString(sBehav,0,9);
            if (g_iAllowAttach == TRUE && llSubStringIndex(sBehav,"addattach")==0 && sVal=="n") sAck = "";
            else if (sVal=="force"||sVal=="n"||sVal=="add"||sVal=="y"||sVal=="rem"||sBehav=="clear") {
                if (kID != g_sSourceID) llMessageLinked(LINK_RLV,RLV_CMD,"clear",g_sSourceID);
                llMessageLinked(LINK_RLV,RLV_CMD,sBehav+"="+sVal,kID);
            } else sAck = "ko";
        } else {
             RelayNotify(g_kWearer,"\n\nBad command from "+llKey2Name(kID)+".\n\nCommand: "+sIdent+","+(string)g_kWearer+"\n\nFaulty subcommand: "+sCom+"\n\nPlease report to the maker of this device.\n",0);
            sAck="";
        }
        if (sAck != "") sendrlvr(sIdent, kID, sCom, sAck);
    }
    return "";
}

sendrlvr(string sIdent, key kID, string sCom, string sAck) {
    llRegionSayTo(kID, RELAY_CHANNEL, sIdent+","+(string)kID+","+sCom+","+sAck);
    if (g_kDebugRcpt == g_kWearer) llOwnerSay("From relay: "+sIdent+","+(string)kID+","+sCom+","+sAck);
    else if (g_kDebugRcpt != NULL_KEY) llRegionSayTo(g_kDebugRcpt, DEBUG_CHANNEL, "From relay: "+sIdent+","+(string)kID+","+sCom+","+sAck);
}

SafeWord() {
    if (!g_iHelpless) {
        llMessageLinked(LINK_RLV,CMD_RELAY_SAFEWORD,"","");
        RelayNotify(g_kWearer,"Restrictions lifted by safeword. You have 10 seconds to get to safety.",0);
        g_sTempTrustObj = "";
        g_sTempTrustUser = "";
        sendrlvr("release",g_sSourceID,"!release","ok");
        g_sSourceID = "";
        g_lQueue = [];
        g_iRecentSafeword = TRUE;
        refreshRlvListener();
        llSetTimerEvent(10.);
    } else RelayNotify(g_kWearer,"Access denied!",0);

}

Menu(key kID, integer iAuth) {
    string sPrompt = "\nRelay";
    list lButtons = ["☐ Ask","☐ Auto"];
    if (g_iBaseMode == 2){
        lButtons = ["☒ Ask","☐ Auto"];
        sPrompt += " is set to ask mode.";
    } else if (g_iBaseMode == 3){
        lButtons = ["☐ Ask","☒ Auto"];
        sPrompt += " is set to auto mode.";
    } else sPrompt += " is offline.";
    if (g_iSmartStrip) lButtons+=["☑ Smart"];
    else lButtons+=["☐ Smart"];
    if (g_iAllowAttach) lButtons+=["☑ AllowAttch"];
    else lButtons+=["☐ AllowAttch"];
    lButtons += ["Reset"];
    if (g_iHelpless) lButtons+=["☑ Helpless"];
    else lButtons+=["☐ Helpless"];
    if (!g_iHelpless) lButtons+=["SAFEWORD"];
    if (g_sSourceID != "")
        sPrompt+="\n\nCurrently grabbed by "+ObjectURI(g_sSourceID);
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Main");
}

refreshRlvListener() {
    llListenRemove(g_iRlvListener);
    llListenRemove(g_iSafetyListener);
    if (g_iRLV && g_iBaseMode && !g_iRecentSafeword) {
        g_iRlvListener = llListen(RELAY_CHANNEL, "", NULL_KEY, "");
        g_iSafetyListener = llListen(SAFETY_CHANNEL, "","","Safety!");
        llRegionSayTo(g_kWearer,SAFETY_CHANNEL,"SafetyDenied!");
    }
}

UserCommand(integer iAuth, string sStr, key kID) {
    if (iAuth<CMD_OWNER || iAuth>CMD_WEARER) return;
    if (llToLower(sStr) == "rm relay") {
        if (kID!=g_kWearer && iAuth!=CMD_OWNER) RelayNotify(kID,"Access denied!",0);
        else  Dialog(kID,"\nAre you sure you want to delete the relay plugin?\n", ["Yes","No","Cancel"], [], 0, iAuth,"rmrelay");
        return;
    }
    if (llSubStringIndex(sStr,"relay") && sStr != "menu "+g_sSubMenu) return;
    if (iAuth == CMD_OWNER && sStr == "runaway") {
        g_lOwner = [];
        g_lTrust = [];
        g_lBlock = [];
        return;
    }
    if (!g_iRLV) {
        llMessageLinked(LINK_RLV, iAuth, "menu RLV", kID);
        llMessageLinked(LINK_DIALOG,NOTIFY,"0\n\nThe relay requires RLV to be running in the %DEVICETYPE% but it currently is not. To make things work, click \"ON\" in the RLV menu that just popped up!\n",kID);
    } else if (sStr=="relay" || sStr == "menu "+g_sSubMenu) Menu(kID, iAuth);
    else if (iAuth!=CMD_OWNER && iAuth!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else if ((sStr=llGetSubString(sStr,6,-1))=="safeword") SafeWord();
    else if (sStr == "getdebug") {
        g_kDebugRcpt = kID;
        RelayNotify(kID,"/me messages will be forwarded to "+NameURI(kID)+".",1);
        return;
    } else if (sStr == "stopdebug") {
        g_kDebugRcpt = NULL_KEY;
        RelayNotify(kID,"/me messages won't forwarded anymore.",1);
        return;
    } else if (sStr == "reset") {
        if (g_sSourceID )
            RelayNotify(kID,"Sorry but the relay cannot be reset while in use!",1);
        else {
            integer i = g_iMinBaseMode;
            if (!i || iAuth == CMD_OWNER) i = 2;
            Dialog(kID,"\nYou are about to set the relay to "+llList2String([0,1,"ask","auto"],i)+" mode and lift all the blocks that you set on object and avatar sources.\n\nClick [Yes] to proceed with resetting the RLV relay.",["Yes","No"],["Cancel"],0,iAuth,"reset");
        }
    } else {
        integer iWSuccess;
        integer index = llSubStringIndex(sStr," ");
        string sChangetype = sStr;
        if (~index) sChangetype = llGetSubString(sStr,0,index-1);
        string sChangevalue = llGetSubString(sStr,index+1,-1);
        string sText;
        if (sChangetype == "helpless") {
            if (g_sSourceID !=  "") iWSuccess = 2;
            else if (sChangevalue == "on") {
                if (iAuth == CMD_OWNER) g_iMinHelplessMode = TRUE;
                sText = "Helplessness imposed.\n\nRestrictions from outside sources can't be cleard with the dedicated relay safeword command.\n";
                g_iHelpless = TRUE;
            } else if (sChangevalue == "off") {
                if (iAuth == CMD_OWNER) g_iMinHelplessMode = FALSE;
                if (g_iMinHelplessMode == TRUE) iWSuccess = 1;
                else {
                    if (iAuth == CMD_OWNER) g_iMinHelplessMode = FALSE;
                    g_iHelpless = FALSE;
                    sText = "Helplessness lifted.\n\nSafewording will clear restrictions from outside sources.\n";
                }
            }
        } else if (llGetSubString(sChangetype,0,4) == "smart") {
            if (sChangevalue == "off") {
                g_iSmartStrip = FALSE;
                sText = "Smartstrip turned off.\n\nAttachments and clothing, also if layers are somewhere inside #RLV folder directories, will be stripped normally.\n";
            } else if (sChangevalue == "on") {
                sText = "Smartstrip turned on.\n\nAll smartstrip ready folders in the #RLV directory will be removed as a whole when corresponding clothing layers are stripped.\n";
                g_iSmartStrip = TRUE;
            }
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sSettingsToken+"smartstrip="+g_iSmartStrip,"");
        } else if (llGetSubString(sChangetype,0,9) == "allowattch") {
            if (sChangevalue == "off") {
                g_iAllowAttach = FALSE;
                sText = "You can no longer attach objects, if the attachpoint is locked.\n";
            } else if (sChangevalue == "on") {
                sText = "You can now always attach objects, even when restrained.\n";
                g_iAllowAttach = TRUE;
            }
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sSettingsToken+"allowattach="+g_iAllowAttach,"");
        } else {
            list lModes = ["off","trust","ask","auto"];
            integer iModeType = llListFindList(lModes,[sChangetype]);
            if (sChangevalue == "off") iModeType = 0;
            if (iAuth == CMD_OWNER) g_iMinBaseMode = iModeType;
            if (~iModeType) {
                if (iModeType >= g_iMinBaseMode) {
                    if (iModeType) sText = "/me is set to "+llList2String(lModes,iModeType)+" mode.";
                    else sText = "/me is offline.";
                    g_iBaseMode = iModeType;
                } else iWSuccess = 1;
            }
        }
        if (!iWSuccess) RelayNotify(kID,sText,1);
        else if (iWSuccess == 1)  RelayNotify(kID,"Access denied!",0);
        else if (iWSuccess == 2)  RelayNotify(kID,"/me is currently in use by "+ObjectURI(g_sSourceID)+" sources.\n\nHelplessness can't be toggled at this moment.\n",1);
        SaveMode();
        refreshRlvListener();
    }
}

default {
    on_rez(integer iStart) {
        if (llGetOwner() != g_kWearer) llResetScript();
        g_lBlockObj = [];
    }

    state_entry() {
        g_kWearer = llGetOwner();
        llSetTimerEvent(g_iGarbageRate);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == CMD_ADDSRC)
            g_sSourceID = (string)kID;
        else if (iNum == CMD_REMSRC) {
            if (g_sSourceID == (string)kID) g_sSourceID = "";
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams,0);
            string sValue = llList2String(lParams,1);
            if (sToken == g_sSettingsToken+"mode") UpdateMode((integer)sValue);
            else if (sToken == g_sSettingsToken+"blockav") g_lBlockAv = llParseString2List(sValue,[","],[]);
            else if (sToken == "auth_owner") g_lOwner = llParseString2List(sValue,[","],[]);
            else if (sToken == "auth_tempowner") g_sTempOwner = sValue;
            else if (sToken == "auth_trust") g_lTrust = llParseString2List(sValue,[","],[]);
            else if (sToken == "auth_block") g_lBlock = llParseString2List(sValue,[","],[]);
            else if (sToken == "smartstrip") g_iSmartStrip = (integer)sValue;
            else if (sToken == "allowattach") g_iAllowAttach = (integer)sValue;
        } else if (iNum == RLV_OFF) {
            g_iRLV = FALSE;
            refreshRlvListener();
        } else if (iNum == RLV_ON) {
            g_iRLV = TRUE;
            refreshRlvListener();
        } else if (iNum == RLV_REFRESH) {
            g_iRLV = TRUE;
            refreshRlvListener();
        } else if (iNum == CMD_SAFEWORD) {
            g_iRecentSafeword = TRUE;
            refreshRlvListener();
            llSetTimerEvent(10.0);
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iAuth = llList2Integer(lMenuParams, 3);
                llSetTimerEvent(g_iGarbageRate);
                if (sMenu == "Menu~Main") {
                    if (sMsg==UPMENU) llMessageLinked(LINK_SET,iAuth,"menu "+g_sParentMenu,kAv);
                    else if (sMsg == "SAFEWORD") UserCommand(iAuth,"relay safeword",kAv);
                    else if (sMsg == "Reset") UserCommand(iAuth,"relay reset",kAv);
                    else {
                        sMsg = llToLower(sMsg);
                        if (!llSubStringIndex(sMsg,"☐ "))
                            sMsg = llDeleteSubString(sMsg,0,1)+" on";
                        else if (!llSubStringIndex(sMsg,"☒ ") || !llSubStringIndex(sMsg,"☑ "))
                            sMsg = llDeleteSubString(sMsg,0,1)+" off";
                        sMsg ="relay "+sMsg;
                        UserCommand(iAuth,sMsg,kAv);
                        Menu(kAv,iAuth);
                    }
                } else if (sMenu=="AuthMenu") {
                    string sCurID = llList2String(g_lQueue,1);
                    string sCom = llList2String(g_lQueue,2);
                    integer iFreeMemory = llGetFreeMemory();
                    if (sMsg == "Yes") {
                        g_sTempTrustObj = sCurID;
                        if (g_kObjectUser!=NULL_KEY) g_sTempTrustUser = g_kObjectUser;
                        iAuth = 1;
                    } else if (sMsg == "No") iAuth = -1;
                    else if (sMsg == "Block") {
                        iAuth = -1;
                        if (iFreeMemory < 4096) {
                            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Your block list is full. Unable to add more to them. To clean them click [Reset] in the menu or use the command: / %CHANNEL% %PREFIX% relay reset",kAv);
                            return;
                        } else if (iFreeMemory < 4608)
                            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Your block list is getting quite full. Unless you don't plan on blocking anymore sources, now would be a good time to reset the list. Click [Reset] in the menu or use the command: / %CHANNEL% %PREFIX% relay reset",kAv);
                        if (g_kObjectUser!=NULL_KEY) {
                            if (llListFindList(g_lBlockAv,[(string)g_kObjectUser]) == -1) {
                                g_lBlockAv += (string)g_kObjectUser;
                                llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sSettingsToken+"blockav="+llDumpList2String(g_lBlockAv,",") ,"");
                                RelayNotify(kAv,NameURI(g_kObjectUser)+" has been added to the relay blocklist.",0);
                            } else
                                RelayNotify(kAv,NameURI(g_kObjectUser)+" is already on the relay blocklist.",0);
                        } else {
                            if (llListFindList(g_lBlockObj,[sCurID]) == -1) {
                                g_lBlockObj += [sCurID,llGetUnixTime()+900];
                                RelayNotify(kAv,"Requests from "+ObjectURI(sCurID)+" are blocked for the next 15 minutes.",0);
                            } else
                                RelayNotify(kAv,ObjectURI(sCurID)+" is already blocked.",0);
                        }
                    }
                    string sIdent = llList2String(g_lQueue,0);
                    if (iAuth == 1) HandleCommand(sIdent,sCurID,sCom,TRUE);
                    else if (iAuth == -1) {
                        list lCommands = llParseString2List(sCom,["|"],[]);
                        integer j;
                        string sCommand;
                        for (;j < llGetListLength(lCommands); ++j) {
                            sCommand = llList2String(lCommands,j);
                            if (!llSubStringIndex(sCommand,"@"))
                                sendrlvr(sIdent,sCurID,sCommand,"ko");
                        }
                    }
                    g_lQueue = [];
                } else if (sMenu == "rmrelay") {
                    if (sMsg == "Yes") {
                        sendrlvr("release",g_sSourceID,"!release","ok");
                        UserCommand(500, "relay off", kAv);
                        llMessageLinked(LINK_RLV, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
                        RelayNotify(kAv,"/me has been removed.",1);
                        if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT) llRemoveInventory(llGetScriptName());
                    } else RelayNotify(kAv,"/me remains installed.",0);
                } else if (sMenu == "reset") {
                    if (sMsg == "Yes") {
                        g_lBlockAv = g_lBlockObj = [];
                        llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,g_sSettingsToken+"blockav","");
                        g_sTempTrustUser = "";
                        g_sTempTrustObj = "";
                        if (iAuth == CMD_OWNER) {
                            g_iMinBaseMode = FALSE;
                            g_iMinHelplessMode = FALSE;
                            g_iBaseMode = 2;
                            g_iHelpless = 0;
                        } else {
                            if (g_iMinBaseMode)
                                g_iBaseMode = g_iMinBaseMode;
                            else g_iBaseMode = 2;
                            g_iHelpless = g_iMinHelplessMode;
                        }
                        SaveMode();
                        RelayNotify(kID,"/me has been reset to "+llList2String([0,1,"ask","auto"],g_iBaseMode)+" mode. All previous blocks on object and avatar sources have been lifted.",1);
                    } else RelayNotify(kID,"Reset canceled.",0);
                    Menu(kAv,iAuth);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                if (llList2String(g_lMenuIDs, iMenuIndex+1) == "AuthMenu") {
                    g_lQueue = [];
                    g_sSourceID = "";
                }
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    listen(integer iChan, string who, key kID, string sMsg) {
        if (iChan == SAFETY_CHANNEL) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0\n\n⚠ "+who+" detected ⚠\n\nTo prevent conflicts this relay is being detached now! If you wish to use "+who+" anyway, type \"/%CHANNEL% %PREFIX% relay off\" to temporarily disable or type \"/%CHANNEL% %PREFIX% rm relay\" to permanently uninstall the relay plugin.\n",g_kWearer);
            llRegionSayTo(g_kWearer,SAFETY_CHANNEL,"SafetyDenied!");
        }
        list lArgs = llParseString2List(sMsg,[","],[]);
        sMsg = "";
        if (llGetListLength(lArgs)!=3) return;
        if (llList2Key(lArgs,1) != g_kWearer && llList2String(lArgs,1) != "ffffffff-ffff-ffff-ffff-ffffffffffff") return;
        string sIdent = llList2String(lArgs,0);
        sMsg = llToLower(llList2String(lArgs,2));
        if (g_kDebugRcpt == g_kWearer) llOwnerSay("To relay: "+sIdent+","+sMsg);
        else if (g_kDebugRcpt!=NULL_KEY) llRegionSayTo(g_kDebugRcpt,DEBUG_CHANNEL,"To relay: "+sIdent+","+sMsg);
        if (sMsg == "!pong") {
            llMessageLinked(LINK_SET, CMD_RLV_RELAY, "ping,"+(string)g_kWearer+",!pong", kID);
            return;
        }
        lArgs = [];
        if (g_sSourceID != (string)kID && g_sSourceID != "") {
            if ((llGetAgentInfo(g_kWearer) & AGENT_ON_OBJECT) == AGENT_ON_OBJECT) return;
        }
        g_kObjectUser = NULL_KEY;
        integer index = llSubStringIndex(sMsg,"!x-who/");
        if (~index) {
            g_kObjectUser = SanitizeKey(llGetSubString(sMsg,index+7,index+42));
            if (index == 0) sMsg = llGetSubString(sMsg,44,-1);
            else if (index+43 == llStringLength(sMsg)) sMsg = llGetSubString(sMsg,0,index-2);
            else sMsg = llGetSubString(sMsg,0,index-2)+llGetSubString(sMsg,index+43,-1);
        }
        integer iAuth = Auth(kID,g_kObjectUser);
        if (iAuth == -1) return;
        else if (iAuth == 1) HandleCommand(sIdent,kID,sMsg,TRUE);
        else if (g_iBaseMode == 2) {
            if (HandleCommand(sIdent,kID,sMsg,FALSE) != "need auth") return;
            if (llGetListLength(g_lQueue) && llGetTime() < g_fPause) return;
            llResetTime();
            g_lQueue = [sIdent,kID,sMsg];
            string sPrompt = "\n"+ObjectURI(kID)+" wants to control your viewer.";
            if (g_kObjectUser!=NULL_KEY) sPrompt+="\n" + NameURI(g_kObjectUser) + " is currently using this device.";
            sPrompt += "\n\nDo you want to allow this?";
            integer iAuthMenuIndex = llListFindList(g_lMenuIDs,["AuthMenu"]);
            if (~iAuthMenuIndex)
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs,iAuthMenuIndex-2,iAuthMenuIndex-3+g_iMenuStride);
            Dialog(g_kWearer,sPrompt,["Yes","No","Block"],[],0,CMD_WEARER,"AuthMenu");
            sMsg = "";
            sIdent="";
        }
        llSetTimerEvent(g_iGarbageRate);
    }

    timer() {
        if (g_iRecentSafeword) {
            g_iRecentSafeword = FALSE;
            refreshRlvListener();
            llSetTimerEvent(g_iGarbageRate);
        }
        vector vMyPos = llGetRootPosition();
        if (g_sSourceID) {
            vector vObjPos = llList2Vector(llGetObjectDetails(g_sSourceID,[OBJECT_POS]),0);
            if (vObjPos == <0, 0, 0> || llVecDist(vObjPos, vMyPos) > 100)
                llMessageLinked(LINK_RLV,RLV_CMD,"clear",g_sSourceID);
        }
        g_lQueue = [];
        g_sTempTrustObj = "";
        if (g_sSourceID == "")g_sTempTrustUser = "";
        integer iTime = llGetUnixTime();
        integer i = ~llGetListLength(g_lBlockObj) + 1;
        while (i < 0) {
            if (llList2Integer(g_lBlockObj,i+1) <= iTime)
                g_lBlockObj = llDeleteSubList(g_lBlockObj,i,i+1);
            i += 2;
        }
        integer iAuthMenuIndex;
        while (~(iAuthMenuIndex = llListFindList(g_lMenuIDs,["AuthMenu"])))
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs,iAuthMenuIndex-2,iAuthMenuIndex-3+g_iMenuStride);
    }
}



