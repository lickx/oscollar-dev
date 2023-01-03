
//  oc_kidnap.lsl
//
//  Copyright (c) 2014 - 2016 littlemousy, Sumi Perl, Wendy Starfall,
//  Garvin Twine
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

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

key g_kWearer = NULL_KEY;

list g_lMenuIDs;

integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_SAFEWORD = 510;

integer NOTIFY = 1002;
integer SAY = 1004;
integer REBOOT = -1000;
integer LINK_AUTH = 2;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string  g_sTempOwnerID;
integer g_iRiskyOn;
integer g_iKidnapOn;
integer g_iKidnapInfo = TRUE;
string  g_sSettingToken = "kidnap_";

string NameURI(string sID)
{
    return "secondlife:///app/agent/"+sID+"/about";
}

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenu, key kKidnapper)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID,kMenuID,sMenu,kKidnapper], iIndex, iIndex+3);
    else g_lMenuIDs += [kID, kMenuID, sMenu, kKidnapper];
}

KidnapMenu(key kId, integer iAuth)
{
    string sPrompt = "\nKidnap";
    list lMyButtons;
    if (g_sTempOwnerID != "") lMyButtons += "Release";
    else {
        if (g_iKidnapOn) lMyButtons += "OFF";
        else lMyButtons += "ON";
        if (g_iRiskyOn) lMyButtons += "☑ risky";
        else lMyButtons += "☐ risky";
    }
    if (g_sTempOwnerID != "")
        sPrompt += "\n\nKidnapped by: "+NameURI(g_sTempOwnerID);
    Dialog(kId, sPrompt, lMyButtons, ["BACK"], 0, iAuth, "KidnapMenu", "");
}

saveTempOwners()
{
    if (g_sTempOwnerID != "") {
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "auth_tempowner="+g_sTempOwnerID, "");
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner="+g_sTempOwnerID, "");
    } else {
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner=", "");
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, "auth_tempowner", "");
    }
}

doKidnap(string sCaptorID, integer iIsConfirmed)
{
    if (g_sTempOwnerID != "") {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME% is already kidnapped, try another time.", sCaptorID);
        return;
    }
    if (llVecDist(llList2Vector(llGetObjectDetails(sCaptorID,[OBJECT_POS] ),0),llGetPos()) > 10) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You could kidnap %WEARERNAME% if you get a bit closer.", sCaptorID);
        return;
    }
    if (iIsConfirmed == FALSE) {
        Dialog(g_kWearer, "\nsecondlife:///app/agent/"+sCaptorID+"/about wants to kidnap you...", ["Allow","Reject"], ["BACK"], 0, CMD_WEARER, "AllowKidnapMenu", sCaptorID);
    } else {
        llMessageLinked(LINK_SET, CMD_OWNER, "beckon", sCaptorID);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You are at "+NameURI(sCaptorID)+"'s whim.", g_kWearer);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"\n\n%WEARERNAME% is at your mercy.\n\nNOTE: During kidnap RP %WEARERNAME% cannot refuse your teleport offers and you will keep full control. Type \"/%CHANNEL% %PREFIX% grab\" to attach a leash or \"/%CHANNEL% %PREFIX% kidnap release\" to relinquish kidnap access to %WEARERNAME%'s %DEVICETYPE%.\n\nHave fun!.\n", sCaptorID);
        g_sTempOwnerID = sCaptorID;
        saveTempOwners();
        llSetTimerEvent(0.0);
    }
}

UserCommand(integer iNum, string sStr, key kID, integer remenu)
{
    string sStrLower = llToLower(sStr);
    if (llSubStringIndex(sStr,"kidnap TempOwner") == 0){
        string sCaptorID = llGetSubString(sStr, llSubStringIndex(sStr, "~")+1, -1);
        if (iNum==CMD_OWNER || iNum==CMD_TRUSTED || iNum==CMD_GROUP) { }
        else Dialog(kID, "\nYou can try to kidnap %WEARERNAME%.\n\nReady for that?", ["Yes","No"], [], 0, iNum, "ConfirmKidnapMenu", sCaptorID);
    }
    else if (sStrLower == "kidnap" || sStrLower == "menu kidnap") {
        if  (iNum != CMD_OWNER && iNum != CMD_WEARER) {
            if (g_iKidnapOn) Dialog(kID, "\nYou can try to kidnap %WEARERNAME%.\n\nReady for that?", ["Yes","No"], [], 0, iNum, "ConfirmKidnapMenu", kID);
            else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else KidnapMenu(kID, iNum);
    }
    else if (iNum != CMD_OWNER && iNum != CMD_WEARER) { }
    else if (llSubStringIndex(sStrLower, "kidnap") == 0) {
        if (g_sTempOwnerID != "" && kID==g_kWearer) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", g_kWearer);
            return;
        } else if (sStrLower == "kidnap on") {
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Kidnap Mode activated", kID);
            if (g_iRiskyOn && g_iKidnapInfo) {
                llMessageLinked(LINK_DIALOG, SAY, "1"+"%WEARERNAME%: You can kidnap me if you touch my %DEVICETYPE%...", "");
                llSetTimerEvent(900.0);
            }
            g_iKidnapOn=TRUE;
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"kidnap=1", "");
        } else if (sStrLower == "kidnap off") {
            if(g_iKidnapOn) llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Kidnap Mode deactivated", kID);
            g_iKidnapOn = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"kidnap", "");
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
        } else if (sStrLower == "kidnap release") {
            llMessageLinked(LINK_SET, CMD_OWNER, "unleash", kID);
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+NameURI(kID)+" has released you.", g_kWearer);
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You have released %WEARERNAME%.", kID);
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
            return;
        } else if (sStrLower == "kidnap risky on") {
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"risky=1", "");
            g_iRiskyOn = TRUE;
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Capturing won't require %WEARERNAME%'s consent. \"/%CHANNEL% %PREFIX% kidnap info off\" will deactivate \"kidnap me\" announcements.", kID);
            if (g_iKidnapOn && g_iKidnapInfo) {
                llSetTimerEvent(900.0);
                llMessageLinked(LINK_DIALOG, SAY, "1"+"%WEARERNAME%: You can kidnap me if you touch my %DEVICETYPE%...", "");
            }
        } else if (sStrLower == "kidnap risky off") {
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"risky", "");
            g_iRiskyOn = FALSE;
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Capturing will require %WEARERNAME%'s consent first.", kID);
            llSetTimerEvent(0.0);
        } else if (sStrLower == "kidnap info on") {
            g_iKidnapInfo = TRUE;
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"\"Kidnap me\" announcements during risky mode are now enabled.", kID);
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"info", "");
            if (g_iRiskyOn && g_iKidnapOn) {
                llSetTimerEvent(900.0);
                llMessageLinked(LINK_DIALOG, SAY, "1"+"%WEARERNAME%: You can kidnap me if you touch my %DEVICETYPE%...", "");
            }
        } else if (sStrLower == "kidnap info off") {
            g_iKidnapInfo = FALSE;
            if (g_iRiskyOn && g_iKidnapOn) llSetTimerEvent(0.0);
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"\"Kidnap me\" announcements during risky mode are now disabled.", kID);
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"info=0", "");
        }
        if (remenu) KidnapMenu(kID, iNum);
    }
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
    }

    on_rez(integer iParam)
    {
        if (llGetOwner() != g_kWearer) llResetScript();
    }

    touch_start(integer num_detected)
    {
        key kToucher = llDetectedKey(0);
        if (kToucher == g_kWearer) return;
        if (g_sTempOwnerID == kToucher) return;
        if (g_sTempOwnerID != "") return;
        if (g_iKidnapOn == FALSE) return;
        if (llVecDist(llDetectedPos(0), llGetPos()) > 10 ) llMessageLinked(LINK_SET, NOTIFY, "0"+"You could kidnap %WEARERNAME% if you get a bit closer.", kToucher);
        else llMessageLinked(LINK_AUTH, CMD_ZERO, "kidnap TempOwner~"+(string)kToucher, kToucher);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == "Main") llMessageLinked(iSender, MENUNAME_RESPONSE, "Main|Kidnap", "");
        else if (iNum == CMD_SAFEWORD || (sStr == "runaway" && iNum == CMD_OWNER)) {
            if (iNum == CMD_SAFEWORD && g_iKidnapOn) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Kidnap Mode deactivated.", g_kWearer);
            if (llGetAgentSize(g_sTempOwnerID) != ZERO_VECTOR) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Your kidnap role play with %WEARERNAME% is over.", g_sTempOwnerID);
            g_iKidnapOn = FALSE;
            g_iRiskyOn = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"kidnap", "");
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"risky", "");
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sSettingToken+"kidnap") {
                g_iKidnapOn = (integer)sValue;
                if (g_iKidnapOn && g_iKidnapInfo) llSetTimerEvent(900.0);
            } else if (sToken == g_sSettingToken+"risky") {
                g_iRiskyOn = (integer)sValue;
                if (g_iKidnapOn && g_iKidnapInfo) llSetTimerEvent(900.0);
            } else if (sToken == "auth_tempowner") g_sTempOwnerID = sValue;
            else if (sToken == g_sSettingToken+"info") {
                g_iKidnapInfo = (integer)sValue;
                if (g_iKidnapOn && g_iKidnapInfo) llSetTimerEvent(900.0);
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID, FALSE);
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                key kKidnapper = llList2Key(g_lMenuIDs, iMenuIndex+2);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex+2);
                if (sMenu == "KidnapMenu") {
                    if (sMessage == "BACK") llMessageLinked(LINK_ROOT, iAuth, "menu Main", kAv);
                    else if (sMessage == "☑ risky") UserCommand(iAuth, "kidnap risky off", kAv, TRUE);
                    else if (sMessage == "☐ risky") UserCommand(iAuth,"kidnap risky on", kAv, TRUE);
                    else UserCommand(iAuth, "kidnap " + sMessage, kAv, TRUE);
                } else if (sMenu == "AllowKidnapMenu") {
                    if (sMessage == "BACK") UserCommand(iNum, "menu kidnap", kID, FALSE);
                    else if (sMessage == "Allow") doKidnap(kKidnapper, TRUE);
                    else if (sMessage == "Reject") {
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+NameURI(kKidnapper)+" didn't pass your face control. Sucks for them!", kAv);
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Looks like %WEARERNAME% didn't want to be kidnapped after all. C'est la vie!", kKidnapper);
                    }
                } else if (sMenu=="ConfirmKidnapMenu") {
                    if (sMessage == "BACK") UserCommand(iNum, "menu kidnap", kID, FALSE);
                    else if (g_iKidnapOn) {
                        if (sMessage == "Yes") doKidnap(kKidnapper, g_iRiskyOn);
                        else if (sMessage == "No") llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You let %WEARERNAME% be.", kAv);
                    } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME% can no longer be kidnapped", kAv);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex+2);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_AUTH") LINK_AUTH = iSender;
            else if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    timer()
    {
        if(g_iKidnapInfo) llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can kidnap me if you touch my %DEVICETYPE%...","");
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_TELEPORT) {
            if (g_sTempOwnerID == "") {
                if (g_iRiskyOn && g_iKidnapOn && g_iKidnapInfo) {
                    llMessageLinked(LINK_DIALOG, SAY, "1"+"%WEARERNAME%: You can kidnap me if you touch my %DEVICETYPE%...", "");
                    llSetTimerEvent(900.0);
                }
            }
        }
    }
}
