
//  oc_timer.lsl
//
//  Copyright (c) 2008 - 2017 Satomi Ahn, Nandana Singh, Joy Stipe,
//  Wendy Starfall, Master Starship, Medea Destiny, littlemousy,
//  Romka Swallowtail, Sumi Perl, Keiyra Aeon, Garvin Twine et al.
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

string g_sAppVersion = "2023.01.04";

string g_sSubMenu = "Timer";
string g_sParentMenu = "Apps";

//MESSAGE MAP
integer CMD_OWNER = 500;
integer CMD_WEARER = 503;

integer ATTACHMENT_FORWARD = 610;

integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_AUTH = 2;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;

integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer TIMER_EVENT = -10000;

string UPMENU = "BACK";
list g_lTimeButtons = ["RESET","+00:01","+00:05","+00:30","+03:00","+24:00","-00:01","-00:05","-00:30","-03:00","-24:00"];

integer MAX_TIME=0x7FFFFFFF;

list g_lTimes;
integer g_iTimesLength;
integer g_iCurrentTime;
integer g_iOnTime;
integer g_iLastTime;
integer g_iFirstOnTime;
integer g_iFirstRealTime;
integer g_iLastRez;
integer n;
string g_sMessage;

integer REAL_TIME = 1;
integer REAL_TIME_EXACT = 5;
integer ON_TIME = 3;
integer ON_TIME_EXACT = 7;

integer g_iInterfaceChannel;

integer g_iOnRunning;
integer g_iOnSetTime;
integer g_iOnTimeUpAt;
integer g_iRealRunning;
integer g_iRealSetTime;
integer g_iRealTimeUpAt;

integer g_iCollarLocked;
integer g_iUnlockCollar = 0;
integer g_iClearRLVRestions = 0;
integer g_iUnleash = 0;
integer g_iBoth = 0;
integer g_iWhoCanChangeTime = 504;
integer g_iWhoCanChangeLeash = 504;

integer g_iTimeChange;

list g_lLocalMenu;

key g_kWearer = NULL_KEY;

list g_lMenuIDs;
integer g_iMenuStride = 3;

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth, string sName)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);
    integer i = llListFindList(g_lMenuIDs, [kID]);
    if (i != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], i, i+g_iMenuStride-1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

DoMenu(key keyID, integer iAuth)
{
    string sPrompt = "\nTimer\t"+g_sAppVersion+"\n\nA frozen pizza takes ~12 min to bake.\n";
    list lMyButtons = ["Real Timer","Online Timer"];
    sPrompt += "\n Online Timer: "+Int2Time(g_iOnSetTime);
    if (g_iOnRunning==1) sPrompt += "\n Online Timer: "+Int2Time(g_iOnTimeUpAt-g_iOnTime)+" left\n";
    else sPrompt += "\n Online Timer: not running\n";
    sPrompt += "\n RL Timer: "+Int2Time(g_iRealSetTime);
    if (g_iRealRunning==1) sPrompt += "\n RL Timer: "+Int2Time(g_iRealTimeUpAt-g_iCurrentTime)+" left";
    else sPrompt += "\n RL Timer: not running";
    if (g_iBoth) lMyButtons += ["☒ combined"];
    else lMyButtons += ["☐ combined"];
    if (g_iUnlockCollar) lMyButtons += ["☑ unlock"];
    else lMyButtons += ["☐ unlock"];
    if (g_iUnleash) lMyButtons += ["☑ unleash"];
    else lMyButtons += ["☐ unleash"];
    if (g_iClearRLVRestions) lMyButtons += ["☑ clear RLV"];
    else lMyButtons += ["☐ clear RLV"];
    if (g_iRealRunning || g_iOnRunning) lMyButtons += ["STOP","RESET"];
    else if (g_iRealSetTime || g_iOnSetTime) lMyButtons += ["START","RESET"];
    Dialog(keyID, sPrompt, lMyButtons + g_lLocalMenu, [UPMENU], 0, iAuth, "menu");
}

DoOnMenu(key keyID, integer iAuth)
{
    string sPrompt = "\n Online Time Settings\n";
    sPrompt += "\n Online Timer: "+Int2Time(g_iOnSetTime);
    if (g_iOnRunning) sPrompt += "\n Online Timer: "+Int2Time(g_iOnTimeUpAt-g_iOnTime)+" left";
    else sPrompt += "\n Online Timer: not running";
    Dialog(keyID, sPrompt, g_lTimeButtons, [UPMENU], 0, iAuth, "online");
}

DoRealMenu(key keyID, integer iAuth)
{
    string sPrompt = "\n RL Time Settings\n";
    sPrompt += "\n RL timer: " + Int2Time(g_iRealSetTime);
    if (g_iRealRunning) sPrompt += "\n RL Timer: "+Int2Time(g_iRealTimeUpAt-g_iCurrentTime)+" left";
    else sPrompt += "\n RL Timer: not running";
    Dialog(keyID, sPrompt, g_lTimeButtons, [UPMENU], 0, iAuth, "real");
}

string Int2Time(integer sTime)
{
    if (sTime < 0) sTime = 0;
    integer iSecs = sTime % 60;
    sTime = (sTime-iSecs) / 60;
    integer iMins = sTime % 60;
    sTime = (sTime-iMins) / 60;
    integer iHours = sTime % 24;
    integer iDays = (sTime-iHours) / 24;
    return ( (string)iDays+" days "+
        llGetSubString("0"+(string)iHours, -2, -1) + ":"+
        llGetSubString("0"+(string)iMins, -2, -1) + ":"+
        llGetSubString("0"+(string)iSecs, -2, -1) );
}

TimerFinish()
{
    if (g_iBoth && (g_iOnRunning == 1 || g_iRealRunning == 1)) return;
    if (g_iUnlockCollar) llMessageLinked(LINK_SET, CMD_OWNER, "unlock", g_kWearer);
    if (g_iClearRLVRestions) {
        llMessageLinked(LINK_SET, CMD_OWNER, "clear", g_kWearer);
        if (g_iUnlockCollar == FALSE && g_iCollarLocked) {
            llSleep(2);
            llMessageLinked(LINK_SET, CMD_OWNER, "lock", g_kWearer);
        }
    }
    if (g_iUnleash && g_iWhoCanChangeTime <= g_iWhoCanChangeLeash)
        llMessageLinked(LINK_SET, CMD_OWNER, "unleash", g_kWearer);
    g_iUnlockCollar = g_iClearRLVRestions = g_iUnleash = 0;
    g_iOnSetTime = g_iRealSetTime = 0;
    g_iOnRunning = g_iRealRunning = 0;
    g_iOnTimeUpAt = g_iRealTimeUpAt = 0;
    g_iWhoCanChangeTime = 504;
    llMessageLinked(LINK_AUTH, CMD_OWNER, "lockout false", "");
    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Yay! Timer expired!", g_kWearer);
    llMessageLinked(LINK_SET, TIMER_EVENT, "end", "");
}

TimerStart(integer perm)
{
    g_iWhoCanChangeTime = perm;
    if (g_iRealSetTime) {
        g_iRealTimeUpAt = g_iCurrentTime + g_iRealSetTime;
        llMessageLinked(LINK_AUTH, CMD_OWNER, "lockout true", "");
        llMessageLinked(LINK_SET, TIMER_EVENT, "START", "RL");
        g_iRealRunning=1;
    } else g_iRealRunning=3;

    if (g_iOnSetTime) {
        g_iOnTimeUpAt = g_iOnTime + g_iOnSetTime;
        llMessageLinked(LINK_AUTH, CMD_OWNER, "lockout true", "");
        llMessageLinked(LINK_SET, TIMER_EVENT, "START", "Online Timer");
        g_iOnRunning = 1;
    } else g_iOnRunning = 3;
}

UserCommand(integer iAuth, string sStr, key kID, integer iMenu)
{
    if ((g_iOnRunning || g_iRealRunning) && kID == g_kWearer) {
        if (llSubStringIndex(llToLower(sStr), "timer") == 0) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You can't access here until the timer went off.", kID);
            return;
        }
    }
    if (llToLower(sStr) == "rm timer" && (iAuth == CMD_OWNER || kID ==  g_kWearer))
        Dialog(kID, "\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes","No","Cancel"], [], 0, iAuth, "rmtimer");
    if (llToLower(sStr) == "timer" || sStr == "menu "+g_sSubMenu) DoMenu(kID, iAuth);
    else if (llGetSubString(sStr, 0, 5) == "timer ") {
        string sMsg = llGetSubString(sStr, 6, -1);
        if (sMsg == "START") {
            TimerStart(iAuth);
            if (kID == g_kWearer) iMenu = FALSE;
        } else if (sMsg == "STOP") TimerFinish();
        else if (sMsg == "RESET") {
            g_iRealSetTime = g_iRealTimeUpAt = 0;
            g_iOnSetTime = g_iOnTimeUpAt = 0;
            if (g_iRealRunning == 1 || g_iOnRunning == 1) {
                g_iRealRunning = 0;
                g_iOnRunning = 0;
                TimerFinish();
            }
        } else if (sMsg == "☒ combined") g_iBoth = FALSE;
        else if (sMsg == "☐ combined") g_iBoth = TRUE;
        else if (sMsg == "☑ unlock") {
            if (iAuth == CMD_OWNER) g_iUnlockCollar = 0;
            else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if (sMsg == "☐ unlock") {
            if (iAuth == CMD_OWNER) g_iUnlockCollar = 1;
            else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if (sMsg == "☑ clear RLV") {
            if (iAuth == CMD_WEARER) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
            else g_iClearRLVRestions = 0;
        } else if (sMsg == "☐ clear RLV") {
            if (iAuth == CMD_WEARER) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
            else g_iClearRLVRestions = 1;
        } else if (sMsg == "☑ unleash") {
            if (iAuth <= g_iWhoCanChangeLeash) g_iUnleash = 0;
            else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if (sMsg == "☐ unleash") {
            if (iAuth <= g_iWhoCanChangeLeash) g_iUnleash = 1;
            else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if (llGetSubString(sMsg, 0, 11) == "Online Timer")
            sMsg = "online" + llStringTrim(llGetSubString(sMsg, 12, -1), STRING_TRIM_HEAD);
        else if (llGetSubString(sMsg, 0, 9) == "Real Timer")
            sMsg = "real" + llStringTrim(llGetSubString(sMsg, 10, -1), STRING_TRIM_HEAD);

        if (llGetSubString(sMsg, 0, 5) == "online") {
            sMsg = llStringTrim(llGetSubString(sMsg, 6, -1), STRING_TRIM_HEAD);
            if (iAuth <= g_iWhoCanChangeTime) {
                list lTimes = llParseString2List(llGetSubString(sMsg, 1, -1), [":"], []);
                if (sMsg == "RESET") {
                    g_iOnSetTime = g_iOnTimeUpAt = 0;
                    if (g_iOnRunning == 1) {   //unlock
                        g_iOnRunning = 0;
                        TimerFinish();
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "+") {
                    g_iTimeChange=llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60;
                    g_iOnSetTime += g_iTimeChange;
                    if (g_iOnRunning == 1) g_iOnTimeUpAt += g_iTimeChange;
                    else if (g_iOnRunning == 3) {
                        g_iOnTimeUpAt = g_iOnTime + g_iOnSetTime;
                        g_iOnRunning = 1;
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "-") {
                    g_iTimeChange=-(llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60);
                    g_iOnSetTime += g_iTimeChange;
                    if (g_iOnSetTime < 0) g_iOnSetTime = 0;
                    if (g_iOnRunning == 1) {
                        g_iOnTimeUpAt += g_iTimeChange;
                        if (g_iOnTimeUpAt <= g_iOnTime) {
                            g_iOnRunning = g_iOnSetTime = g_iOnTimeUpAt = 0;
                            TimerFinish();
                        }
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "=") {
                    g_iTimeChange=llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60;
                    if (g_iTimeChange <= 0) return;
                    g_iOnSetTime = g_iTimeChange;
                    if (g_iOnRunning == 1) g_iOnTimeUpAt = g_iOnTime + g_iTimeChange;
                    else if (g_iOnRunning == 3) {
                        g_iOnTimeUpAt = g_iOnTime + g_iTimeChange;
                        g_iOnRunning = 1;
                    }
                } else return;
            }
            if (iMenu) DoOnMenu(kID, iAuth);
            return;
        } else if (llGetSubString(sMsg, 0, 3) == "real") {
            sMsg = llStringTrim(llGetSubString(sMsg, 4, -1), STRING_TRIM_HEAD);
            list lTimes = llParseString2List(llGetSubString(sMsg, 1, -1), [":"], []);
            if (iAuth <= g_iWhoCanChangeTime) {
                if (sMsg == "RESET") {
                    g_iRealSetTime=g_iRealTimeUpAt=0;
                    if (g_iRealRunning == 1) {   //unlock
                        g_iRealRunning = 0;
                        TimerFinish();
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "+") {
                    g_iTimeChange = llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60;
                    g_iRealSetTime += g_iTimeChange;
                    if (g_iRealRunning == 1) g_iRealTimeUpAt += g_iTimeChange;
                    else if (g_iRealRunning == 3) {
                        g_iRealTimeUpAt=g_iCurrentTime+g_iRealSetTime;
                        g_iRealRunning=1;
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "-") {
                    g_iTimeChange = -(llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60);
                    g_iRealSetTime += g_iTimeChange;
                    if (g_iRealSetTime < 0) g_iRealSetTime = 0;
                    if (g_iRealRunning == 1) {
                        g_iRealTimeUpAt += g_iTimeChange;
                        if (g_iRealTimeUpAt <= g_iCurrentTime) {
                            g_iRealRunning = g_iRealSetTime = g_iRealTimeUpAt = 0;
                            TimerFinish();
                        }
                    }
                } else if (llGetSubString(sMsg, 0, 0) == "=") {
                    g_iTimeChange = llList2Integer(lTimes,0) * 60 * 60 + llList2Integer(lTimes, 1) * 60;
                    if (g_iTimeChange <= 0) return;
                    g_iRealSetTime = g_iTimeChange;
                    if (g_iRealRunning == 1) g_iRealTimeUpAt = g_iCurrentTime + g_iRealSetTime;
                    else if (g_iRealRunning == 3) {
                        g_iRealTimeUpAt = g_iCurrentTime + g_iRealSetTime;
                        g_iRealRunning = 1;
                    }
                } else return ;
            }
            if (iMenu) DoRealMenu(kID, iAuth);
            return;
        }
        if (iMenu) DoMenu(kID, iAuth);
    }
}

default
{
    on_rez(integer iParam)
    {
        if (g_kWearer != llGetOwner()) llResetScript();
        g_iLastTime = g_iLastRez = llGetUnixTime();
        llRegionSayTo(g_kWearer, g_iInterfaceChannel, "timer|sendtimers");
    }

    state_entry()
    {
        g_iLastTime = llGetUnixTime();
        llSetTimerEvent(1);
        g_kWearer = llGetOwner();
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        g_iFirstOnTime = MAX_TIME;
        g_iFirstRealTime = MAX_TIME;
        llRegionSayTo(g_kWearer, g_iInterfaceChannel, "timer|sendtimers");
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID, FALSE);
        else if (iNum == ATTACHMENT_FORWARD) {
            list info = llParseString2List (sStr, ["|"], []);
            if (llList2String(info, 0) != "timer") return;
            string sCommand = llList2String(info, 1);
            integer type = llList2Integer(info, 2);
            if (sCommand == "settimer") {
                if (type == REAL_TIME) {
                    integer newtime = llList2Integer(info, 3) + g_iCurrentTime;
                    g_lTimes = g_lTimes + [REAL_TIME, newtime];
                    if (g_iFirstRealTime > newtime) g_iFirstRealTime = newtime;
                    g_sMessage = "timer|timeis|" + (string)REAL_TIME+"|"+(string)g_iCurrentTime;
                } else if (type == REAL_TIME_EXACT) {
                    integer newtime = llList2Integer(info, 3);
                    g_lTimes = g_lTimes + [REAL_TIME, newtime];
                    if (g_iFirstRealTime > newtime) g_iFirstRealTime = newtime;
                } else if (type == ON_TIME) {
                    integer newtime = llList2Integer(info, 3) + g_iOnTime;
                    g_lTimes = g_lTimes + [ON_TIME, newtime];
                    if (g_iFirstOnTime > newtime) g_iFirstOnTime = newtime;
                    g_sMessage = "timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
                } else if (type == ON_TIME_EXACT) {
                    integer newtime = llList2Integer(info, 3) + g_iOnTime;
                    g_lTimes = g_lTimes + [ON_TIME, newtime];
                    if (g_iFirstOnTime > newtime) g_iFirstOnTime = newtime;
                }
            } else if (sCommand=="gettime") {
                if (type == REAL_TIME) g_sMessage = "timer|timeis|"+(string)REAL_TIME+"|"+(string)g_iCurrentTime;
                else if (type == ON_TIME) g_sMessage = "timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
            } else return;
            llRegionSayTo(g_kWearer, g_iInterfaceChannel, g_sMessage);
        } else if (iNum == LM_SETTING_EMPTY) {
            if (sStr == "leash_leashedto") g_iWhoCanChangeLeash=504;
            if (sStr == "global_locked") g_iCollarLocked=0;
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "global_locked") g_iCollarLocked = (integer)sValue;
            else if (sToken == "leash_leashedto") {
                g_iWhoCanChangeLeash = llList2Integer(llParseString2List(sValue, [","], []), 1);
            }
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
            g_lLocalMenu = [];
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
        } else if (iNum == MENUNAME_RESPONSE) {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu) {
                string sButton = llList2String(lParts, 1);
                if (llListFindList(g_lLocalMenu, [sButton]) == -1)
                    g_lLocalMenu = llListSort(g_lLocalMenu+[sButton],1,TRUE);
            }
        } else if (iNum == MENUNAME_REMOVE) {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu) {
                string sButton = llList2String(lParts, 1);
                integer iIndex = llListFindList(g_lLocalMenu, [sButton]);
                if (iIndex != -1) g_lLocalMenu = llDeleteSubList(g_lLocalMenu, iIndex, iIndex);
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex == -1) return;
            string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = llList2Key(lMenuParams, 0);
            string sMsg = llList2String(lMenuParams, 1);
            integer iAuth = llList2Integer(lMenuParams, 3);
            if (sMenu == "menu") {
                if (sMsg == UPMENU) llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                else if (sMsg == "Real Timer") DoRealMenu(kAv, iAuth);
                else if (sMsg == "Online Timer") DoOnMenu(kAv, iAuth);
                else if (llListFindList(g_lLocalMenu, [sMsg]) != -1) llMessageLinked(LINK_SET, iAuth, "menu "+sMsg, kAv);
                else UserCommand(iAuth, "timer " + sMsg, kAv, TRUE);
            } else if (sMenu == "real") {
                if (sMsg == UPMENU) DoMenu(kAv, iAuth);
                else UserCommand(iAuth, "timer real"+sMsg, kAv, TRUE);
            } else if (sMenu == "online") {
                if (sMsg == UPMENU) DoMenu(kAv, iAuth);
                else UserCommand(iAuth, "timer online"+sMsg, kAv, TRUE);
            } else if (sMenu == "rmtimer") {
                if (sMsg == "Yes") {
                    llMessageLinked(LINK_ROOT, MENUNAME_REMOVE, g_sParentMenu+"|"+g_sSubMenu, "");
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kAv);
                    llRemoveInventory(llGetScriptName());
                } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kAv);
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_AUTH") LINK_AUTH = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    timer()
    {
        g_iCurrentTime = llGetUnixTime();
        if (g_iCurrentTime < (g_iLastRez+60)) return;
        if ((g_iCurrentTime-g_iLastTime) < 60) g_iOnTime += g_iCurrentTime-g_iLastTime;
        if (g_iOnTime >= g_iFirstOnTime) {
            g_sMessage = "timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
            llRegionSayTo(g_kWearer, g_iInterfaceChannel, g_sMessage);
            g_iFirstOnTime = MAX_TIME;
            g_iTimesLength = llGetListLength(g_lTimes);
            for(n = 0; n < g_iTimesLength; n += 2) {
                if (llList2Integer(g_lTimes, n) == ON_TIME) {
                    while(llList2Integer(g_lTimes, n+1) <= g_iOnTime && llList2Integer(g_lTimes, n) == ON_TIME && llGetListLength(g_lTimes) > 0) {
                        g_lTimes=llDeleteSubList(g_lTimes, n, n+1);
                        g_iTimesLength=llGetListLength(g_lTimes);
                    }
                    if (llList2Integer(g_lTimes, n) == ON_TIME && llList2Integer(g_lTimes, n+1) < g_iFirstOnTime)
                        g_iFirstOnTime=llList2Integer(g_lTimes, n+1);
                }
            }
        }
        if (g_iCurrentTime >= g_iFirstRealTime) {
            g_sMessage = "timer|timeis|"+(string)REAL_TIME+"|"+(string)g_iCurrentTime;
            llRegionSayTo(g_kWearer, g_iInterfaceChannel, g_sMessage);
            g_iFirstRealTime = MAX_TIME;
            g_iTimesLength = llGetListLength(g_lTimes);
            for(n = 0; n < g_iTimesLength; n += 2) {
                if (llList2Integer(g_lTimes, n) == REAL_TIME) {
                    while(llList2Integer(g_lTimes, n+1) <= g_iCurrentTime && llList2Integer(g_lTimes, n) == REAL_TIME) {
                        g_lTimes = llDeleteSubList(g_lTimes, n, n+1);
                        g_iTimesLength = llGetListLength(g_lTimes);
                    }
                    if (llList2Integer(g_lTimes, n) == REAL_TIME && llList2Integer(g_lTimes, n+1) < g_iFirstRealTime) {
                        g_iFirstRealTime = llList2Integer(g_lTimes, n+1);
                    }
                }
            }
        }
        if (g_iOnRunning == 1 && g_iOnTimeUpAt <= g_iOnTime) {
            g_iOnRunning = 0;
            TimerFinish();
        }
        if (g_iRealRunning == 1 && g_iRealTimeUpAt <= g_iCurrentTime) {
            g_iRealRunning = 0;
            TimerFinish();
        }
        g_iLastTime=g_iCurrentTime;
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER) llResetScript();
    }
}
