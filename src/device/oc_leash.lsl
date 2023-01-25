
//  oc_leash.lsl
//
//  Copyright (c) 2008 - 2016 Nandana Singh, Lulu Pink, Garvin Twine,
//  Joy Stipe, Cleo Collins, Satomi Ahn, Master Starship, Toy Wylie,
//  Kaori Gray, Sei Lisa, Wendy Starfall, littlemousy, Romka Swallowtail,
//  Sumi Perl, Karo Weirsider, Kurt Burleigh, Marissa Mistwallow,
//  klixi et al.
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

string TOK_LENGTH = "leashlength";
string TOK_DEST = "leashedto";

integer CMD_OWNER = 500;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_SAFEWORD = 510;

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

integer RLV_CMD = 6000;

integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer SENSORDIALOG = -9003;
integer CMD_PARTICLE = 20000;

string BUTTON_UPMENU = "BACK";
string BUTTON_PARENTMENU = "Main";
string BUTTON_SUBMENU = "Leash";

list g_lMenuIDs;
integer g_iMenuStride = 3;

key g_kLeashCmderID = NULL_KEY;

list g_lButtons;

key g_kWearer = NULL_KEY;

integer g_iJustMoved;
integer g_iLength = 3;
integer g_iStay;
integer g_iTargetHandle;
integer g_iLastRank;
integer g_iStayRank;
integer g_iStrictRank;
vector g_vPos = ZERO_VECTOR;
key g_kCmdGiver = NULL_KEY;
key g_kLeashedTo = NULL_KEY;
integer g_bLeashedToAvi;
integer g_bFollowMode;
string g_sSettingToken = "leash_";

integer g_iPassConfirmed;
integer g_iRezAuth;

string g_sCheck;

integer g_iStrictModeOn;
integer g_iTurnModeOn;
integer g_iLeasherInRange;
integer g_iRLVOn;
integer g_iAwayCounter;

vector g_vRegionSize = <256,256,0>;

string g_sLeashHolder = "Leash Holder";

string NameURI(key kID)
{
    if (llGetAgentSize(kID) != ZERO_VECTOR)
        return "secondlife:///app/agent/"+(string)kID+"/about";
    else
        return "secondlife:///app/objectim/"+(string)kID+"/?name="+llEscapeURL(llKey2Name(kID))+"&owner="+(string)llGetOwnerKey(kID);
}

Dialog(key kRCPT, string sPrompt, list lButtons, list lUtilityButtons, integer iPage, integer iAuth, string sMenuID) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lButtons, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT,kMenuID,sMenuID], iIndex, iIndex + g_iMenuStride-1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

SensorDialog(key kRCPT, string sPrompt, string sSearchName, integer iAuth, string sMenuID, integer iSensorType)
{
    key kMenuID = llGenerateKey();
    if (sSearchName != "") sSearchName = "`"+sSearchName+"`1";
    llMessageLinked(LINK_DIALOG, SENSORDIALOG, (string)kRCPT +"|"+sPrompt+"|0|``"+(string)iSensorType+"`10`"+(string)PI+sSearchName+"|"+BUTTON_UPMENU+"|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT,kMenuID,sMenuID], iIndex, iIndex + g_iMenuStride-1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

ConfirmDialog(key kAv, key kCmdGiver, string sType, integer iAuth)
{
    if ((string)kAv == BUTTON_UPMENU) {
        UserCommand(iAuth, "leashmenu", kCmdGiver ,TRUE);
        return;
    }
    string sCmdGiverURI = NameURI(kCmdGiver);
    string sPrompt;
    string sMessage;
    if (kCmdGiver == g_kWearer) sPrompt = "\n%WEARERNAME% wants to ";
    else sPrompt = "\n"+sCmdGiverURI + " wants to ";
    if (sType == "LeashTarget") {
        sMessage = "Asking "+NameURI(kAv)+" to accept %WEARERNAME%'s leash.";
        if (kCmdGiver == g_kWearer) sPrompt += "pass you their leash.";
        else sPrompt += "pass you %WEARERNAME%'s leash.";
        sPrompt += "\n\nAre you OK with this?";
        Dialog(kAv, sPrompt, ["Yes","No"], [], 0, iAuth, "LeashTargetConfirm");
    } else {
        sMessage = "Asking "+NameURI(kAv)+" to accept %WEARERNAME% to follow them.";
        if (kCmdGiver == g_kWearer) sPrompt += "follow you.";
        else sPrompt += " command %WEARERNAME% to follow you.";
        sPrompt += "\n\nAre you OK with this?";
        Dialog(kAv, sPrompt, ["Yes","No"], [], 0, iAuth, "FollowTargetConfirm");
    }
    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sMessage,kCmdGiver);
}

integer CheckCommandAuth(key kCmdGiver, integer iAuth)
{
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return FALSE;
    if (g_kLeashedTo != NULL_KEY && iAuth > g_iLastRank) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kCmdGiver);
        return FALSE;
    }
    return TRUE;
}

SetLength(integer iIn)
{
    g_iLength = iIn;
    if (g_kLeashedTo != NULL_KEY) {
        llTargetRemove(g_iTargetHandle);
        g_iTargetHandle = llTarget(g_vPos, g_iLength);
    }
}

ApplyRestrictions()
{
    if (g_iLeasherInRange && g_iStrictModeOn) {
        if (g_kLeashedTo != NULL_KEY) {
            if (g_bFollowMode == FALSE) {
                llMessageLinked(LINK_RLV, RLV_CMD, "fly=n,tplm=n,tplure=n,tploc=n,sittp:6=n,tplure:" + (string) g_kLeashedTo + "=add", "realleash");
                return;
            }
        }
    }
    llMessageLinked(LINK_RLV, RLV_CMD, "clear", "realleash");
}

integer LeashTo(key kTarget, key kCmdGiver, integer iAuth, list lPoints, integer iFollowMode)
{
    if (kTarget == g_kWearer) return FALSE;
    if (g_iPassConfirmed == FALSE) {
        g_kLeashCmderID = kCmdGiver;
        if (iFollowMode) {
            ConfirmDialog(kTarget, kCmdGiver, "FollowTarget", iAuth);
        } else {
            ConfirmDialog(kTarget, kCmdGiver, "LeashTarget", iAuth);
        }
        return FALSE;
    }
    if (CheckCommandAuth(kCmdGiver, iAuth) == FALSE) return FALSE;
    if (g_kLeashedTo != NULL_KEY) DoUnleash(TRUE);
    integer bCmdGiverIsAvi = (llGetAgentSize(kCmdGiver) != ZERO_VECTOR);
    integer bTargetIsAvi = (llGetAgentSize(kTarget) != ZERO_VECTOR);
    if (bCmdGiverIsAvi) {
        string sTarget = NameURI(kTarget);
        string sCmdGiver = NameURI(kCmdGiver);
        string sWearMess;
        if (kCmdGiver == g_kWearer) {
            if (iFollowMode) sWearMess = "You begin following " + sTarget + ".";
            else {
                sWearMess = "You take your leash";
                if (bTargetIsAvi) sWearMess += ", and hand it to " + sTarget + ".";
                else sWearMess += ", and tie it to " + sTarget + ".";
            }
        } else {
            string sCmdMess;
            if (iFollowMode){
                if (kCmdGiver != kTarget) {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sCmdGiver+" command %WEARERNAME% to follow you.", kTarget);
                    sCmdMess= "You command %WEARERNAME% to follow " + sTarget + ".";
                    sWearMess = sCmdGiver + " commands you to follow " + sTarget + ".";
                } else {
                    sCmdMess= "You command %WEARERNAME% to follow you.";
                    sWearMess = sCmdGiver + " commands you to follow them.";
                }
            } else {
                sCmdMess= "You grab %WEARERNAME%'s leash";
                sWearMess = sCmdGiver + " grabs your leash";
                if (kCmdGiver != kTarget) {
                    if (bTargetIsAvi) {
                        sCmdMess += ", and hand it to " + sTarget + ".";
                        sWearMess += ", and hands it to " + sTarget + ".";
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sCmdGiver+" hands you %WEARERNAME%'s leash.", kTarget);
                    } else {
                        sCmdMess += ", and tie it to " + sTarget + ".";
                        sWearMess += ", and ties it to " + sTarget + ".";
                    }
                }
            }
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sCmdMess, kCmdGiver);
        }
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sWearMess, g_kWearer);
    }
    g_bFollowMode = iFollowMode;
    if (bTargetIsAvi) g_bLeashedToAvi = TRUE;
    if (llGetOwnerKey(kCmdGiver) == g_kWearer) iAuth = CMD_WEARER;
    DoLeash(kTarget, iAuth, lPoints);
    g_iPassConfirmed = FALSE;
    if (g_bLeashedToAvi && kCmdGiver != kTarget && llGetOwnerKey(kCmdGiver) != kTarget) {
        if (iFollowMode){
            llMessageLinked(LINK_DIALOG,NOTIFY, "0"+"%WEARERNAME% has been commanded to follow you. Say \"/%CHANNEL% %PREFIX% unfollow\" to relase them.", g_kLeashedTo);
        } else {
            llMessageLinked(LINK_DIALOG,NOTIFY, "0"+"%WEARERNAME% has been leashed to you. Say \"/%CHANNEL% %PREFIX% unleash\" to unleash them.", g_kLeashedTo);
        }
    }
    return TRUE;
}

DoLeash(key kTarget, integer iAuth, list lPoints)
{
    g_iLastRank = iAuth;
    g_kLeashedTo = kTarget;
    if (g_bFollowMode)
        llMessageLinked(LINK_THIS, CMD_PARTICLE, "unleash", g_kLeashedTo);
    else {
        integer iPointCount = llGetListLength(lPoints);
        g_sCheck = "";
        if (iPointCount > 0) {
            if (iPointCount == 1) g_sCheck = (string)llGetOwnerKey(kTarget) + llList2String(lPoints, 0) + " ok";
        }
        llMessageLinked(LINK_THIS, CMD_PARTICLE, "leash" + g_sCheck + "|" + (string)g_bLeashedToAvi, g_kLeashedTo);
        llSetTimerEvent(3.0);
    }
    g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo, [OBJECT_POS]), 0);
    llTargetRemove(g_iTargetHandle);
    llReleaseControls();
    llStopMoveToTarget();
    g_iTargetHandle = llTarget(g_vPos, (float)g_iLength);
    if (g_vPos != ZERO_VECTOR) {
        llMoveToTarget(g_vPos, 0.7);
    }
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + TOK_DEST + "=" + (string)kTarget + "," + (string)iAuth + "," + (string)g_bLeashedToAvi + "," + (string)g_bFollowMode, "");
    g_iLeasherInRange = TRUE;
    ApplyRestrictions();
}

Unleash(key kCmdGiver)
{
    string sTarget = NameURI(g_kLeashedTo);
    if (g_kLeashedTo != NULL_KEY) {
        string sCmdGiver = NameURI(kCmdGiver);
        string sWearMess;
        string sCmdMess;
        string sTargetMess;
        integer bCmdGiverIsAvi = (llGetAgentSize(kCmdGiver) != ZERO_VECTOR);
        if (bCmdGiverIsAvi) {
            g_bLeashedToAvi = (llGetAgentSize(g_kLeashedTo) != ZERO_VECTOR);
            if (kCmdGiver == g_kWearer) {
                if (g_bFollowMode) {
                    sWearMess = "You stop following " + sTarget + ".";
                    sTargetMess = "%WEARERNAME% stops following you.";
                } else {
                    sWearMess = "You unleash yourself from " + sTarget + ".";
                    sTargetMess = "%WEARERNAME% unleashes from you.";
                }
                if (g_bLeashedToAvi) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sTargetMess, g_kLeashedTo);
            } else {
                if (kCmdGiver == g_kLeashedTo) {
                    if (g_bFollowMode) {
                        sCmdMess = "You release %WEARERNAME% from following you.";
                        sWearMess = sCmdGiver + " releases you from following.";
                    } else {
                        sCmdMess = "You unleash %WEARERNAME%.";
                        sWearMess = sCmdGiver + " unleashes you.";
                    }
                } else {
                    if (g_bFollowMode) {
                        sCmdMess = "You release %WEARERNAME% from following " + sTarget + ".";
                        sWearMess = sCmdGiver + " releases you from following " + sTarget + ".";
                        sTargetMess = "%WEARERNAME% stops following you.";
                    } else {
                        sCmdMess = "You unleash %WEARERNAME% from " + sTarget + ".";
                        sWearMess = sCmdGiver + " unleashes you from " + sTarget + ".";
                        sTargetMess = sCmdGiver + " unleashes %WEARERNAME% from you.";
                    }
                    if (g_bLeashedToAvi) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sTargetMess, g_kLeashedTo);
                }
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sCmdMess, kCmdGiver);
            }
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sWearMess,g_kWearer);
        }
        DoUnleash(TRUE);
    }
}

DoUnleash(integer iDelSettings)
{
    llTargetRemove(g_iTargetHandle);
    llReleaseControls();
    llStopMoveToTarget();
    llMessageLinked(LINK_THIS, CMD_PARTICLE, "unleash", g_kLeashedTo);
    g_kLeashedTo = NULL_KEY;
    g_iLastRank = CMD_EVERYONE;
    if (iDelSettings) llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + TOK_DEST, "");
    llSetTimerEvent(0.0);
    g_iLeasherInRange = FALSE;
    ApplyRestrictions();
}

YankTo(key kIn)
{
    llMoveToTarget(llList2Vector(llGetObjectDetails(kIn, [OBJECT_POS]), 0), 0.5);
    if (llGetAgentInfo(g_kWearer) & AGENT_SITTING) llMessageLinked(LINK_RLV, RLV_CMD, "unsit=force", "");
    llSleep(2.0);
    llReleaseControls();
    llStopMoveToTarget();
}

FindLeashHolder()
{
    g_sLeashHolder = "";
    integer i = 0;
    while (i < llGetInventoryNumber(INVENTORY_OBJECT) && g_sLeashHolder == "") {
        string sItemName = llGetInventoryName(INVENTORY_OBJECT, i);
        if (llSubStringIndex(llToLower(sItemName), "holder") != -1) {
            g_sLeashHolder = sItemName;
        }
        i++;
    }
}

UserCommand(integer iAuth, string sMessage, key kMessageID, integer bFromMenu) {
    if (iAuth == CMD_EVERYONE) {
        if (kMessageID == g_kLeashedTo) {
            sMessage = llToLower(sMessage);
            if (sMessage == "unleash" || sMessage == "unfollow" || (sMessage == "toggleleash" && NULL_KEY != g_kLeashedTo)) Unleash(kMessageID);
            else if (sMessage == "yank") YankTo(kMessageID);
        }
    } else {
        g_kCmdGiver = kMessageID;
        list lParam = llParseString2List(sMessage, [" "], []);
        string sComm = llToLower(llList2String(lParam, 0));
        string sVal = llToLower(llList2String(lParam, 1));
        sMessage = llToLower(sMessage);
        if (sMessage=="leashmenu" || sMessage == "menu leash"){
            list lButtons;
            if (kMessageID != g_kWearer) lButtons += "Grab";
            else lButtons += ["-"];
            if (g_kLeashedTo != NULL_KEY) {
                if (g_bFollowMode) lButtons += ["Unfollow"];
                else lButtons += ["Unleash"];
            }
            else lButtons += ["-"];
            if (kMessageID == g_kLeashedTo) lButtons += "Yank";
            else {
                if (iAuth < CMD_WEARER && llGetInventoryType(g_sLeashHolder)==INVENTORY_OBJECT) lButtons += ["Give Holder"];
                else lButtons += ["-"];
            }
            lButtons += ["Follow"];
            lButtons += ["Anchor","Pass"];
            lButtons += ["Length"];
            lButtons += g_lButtons;
            string sPrompt = "\nLeash\n";
            if (g_kLeashedTo != NULL_KEY) {
                if (g_bFollowMode) sPrompt += "\nFollowing: ";
                else sPrompt += "\nLeashed to: ";
                sPrompt += NameURI(g_kLeashedTo);
            } else if (g_iStay == FALSE) sPrompt += "\n%WEARERNAME% can move freely.";
            if (g_iStay) sPrompt += "\n%WEARERNAME% can't move on their own.";
            Dialog(kMessageID, sPrompt, lButtons, [BUTTON_UPMENU], 0, iAuth, "MainDialog");
        } else  if (sComm == "post") {
            if (sVal == llToLower(BUTTON_UPMENU)) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
        } else  if (sMessage == "grab" || sMessage == "leash" || (sMessage == "toggleleash" && NULL_KEY == g_kLeashedTo)) {
            g_iPassConfirmed = TRUE;
            LeashTo(kMessageID, kMessageID, iAuth, ["handle"], FALSE);
            if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
        } else if(sComm == "follow" || sComm == "followtarget") {
            if (CheckCommandAuth(kMessageID, iAuth) == FALSE) return;
            if (sVal==llToLower(BUTTON_UPMENU))
                UserCommand(iAuth, "leash", kMessageID, bFromMenu);
            else if (sVal == "me") {
                g_iPassConfirmed = TRUE;
                LeashTo(kMessageID, kMessageID, iAuth, [], TRUE);
            } else if ((key)sVal) {
                g_iPassConfirmed = TRUE;
                LeashTo((key)sVal, kMessageID, iAuth, [], TRUE);
            } else
                SensorDialog(g_kCmdGiver, "\nWho shall be followed?\n", sVal, iAuth, "FollowTarget",AGENT);
        } else if (sMessage == "runaway" && iAuth == CMD_OWNER) {
            Unleash(kMessageID);
        } else if (sMessage == "unleash" || sMessage == "unfollow" || (sMessage == "toggleleash" && NULL_KEY != g_kLeashedTo)) {
            if (CheckCommandAuth(kMessageID, iAuth)) Unleash(kMessageID);
            if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
        } else if (sMessage == "park") {
            if (llGetInventoryType("Pretty Balloon") == INVENTORY_OBJECT) {
                g_iRezAuth=iAuth;
                llRezObject("Pretty Balloon", llGetPos() + (<0.2, 0.0, 1.2> * llGetRot()), ZERO_VECTOR, llEuler2Rot(<0, 0, 0> * DEG_TO_RAD), 0);
            }
        } else if (sMessage == "yank" && kMessageID == g_kLeashedTo) {
            if(llGetAgentInfo(g_kWearer) & AGENT_SITTING) llMessageLinked(LINK_RLV, RLV_CMD, "unsit=force", "realleash");
            if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
            YankTo(kMessageID);
        } else if (sMessage == "give holder") {
            if (iAuth < CMD_WEARER && llGetInventoryType(g_sLeashHolder) == INVENTORY_OBJECT) {
                llGiveInventory(kMessageID, g_sLeashHolder);
            }
        } else if (sMessage == "beckon" && iAuth == CMD_OWNER) YankTo(kMessageID);
        else if (sMessage == "stay") {
            if (iAuth <= CMD_GROUP) {
                g_iStayRank = iAuth;
                g_iStay = TRUE;
                string sCmdGiver = NameURI(kMessageID);
                llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sCmdGiver + " commands you to stay in place. You can't move on your own now!", g_kWearer);
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Yay! %WEARERNAME% can't move on their own now! Cast a leash to pull them along or type \"/%CHANNEL% %PREFIX% move\" if you change your mind.", kMessageID);
                if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
            }
        } else if ((sMessage == "unstay" || sMessage == "move") && g_iStay) {
            if (iAuth <= g_iStayRank) {
                g_iStay = FALSE;
                llReleaseControls();
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You are free to move again.", g_kWearer);
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You allowed %WEARERNAME% to move freely again.", kMessageID);
                if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
            }
        } else if (sMessage == "strict on") {
            if (g_iStrictModeOn) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Strict leashing is already enabled.", kMessageID);
            else {
                g_iStrictRank = iAuth;
                g_iStrictModeOn = TRUE;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "strict=1,"+ (string)iAuth, "");
                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, g_sSettingToken + "strict=1,"+ (string)iAuth, kMessageID);
                llMessageLinked(LINK_SAVE, LM_SETTING_REQUEST, TOK_DEST, "");
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Strict leashing enabled.", kMessageID);
                ApplyRestrictions();
            }
        } else if (sMessage == "strict off") {
            if (iAuth <= g_iStrictRank) {
                g_iStrictModeOn = FALSE;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "strict", "");
                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, g_sSettingToken + "strict=0,"+ (string)iAuth,kMessageID);
                ApplyRestrictions();
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Strict leashing disabled.", kMessageID);
            } else {
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kMessageID);
            }
        } else if (sMessage == "turn on") {
            g_iTurnModeOn = TRUE;
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "turn=1", "");
            llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, g_sSettingToken + "turn=1", "");
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Turning towards leasher enabled.", kMessageID);
        } else if (sMessage == "turn off") {
            g_iTurnModeOn = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "turn", "");
            llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, g_sSettingToken + "turn=0,"+ (string)iAuth,kMessageID);
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Turning towards leasher disabled.", kMessageID);
        } else if (sComm == "pass") {
            if (CheckCommandAuth(kMessageID, iAuth) == FALSE) return;
            if (sVal==llToLower(BUTTON_UPMENU))
                UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
            else if((key)sVal) {
                list lPoints;
                if (llGetListLength(lParam) > 2) lPoints = llList2List(lParam, 2, -1);
                LeashTo((key)sVal, kMessageID, iAuth, lPoints, FALSE);
            } else
                SensorDialog(g_kCmdGiver, "\nWho shall we pass the leash?\n", sVal,iAuth,"LeashTarget", AGENT);
        } else if (sComm == "length") {
            integer iNewLength = (integer)sVal;
            if (sVal == llToLower(BUTTON_UPMENU)){
                UserCommand(iAuth, "leash", kMessageID, bFromMenu);
            } else if(iNewLength > 0 && iNewLength <= 20){
                if (kMessageID == g_kLeashedTo || CheckCommandAuth(kMessageID, iAuth)) {
                    SetLength(iNewLength);
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Leash length set to " + (string)g_iLength+"m.", kMessageID);
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + TOK_LENGTH + "=" + sVal, "");
                }
                if (bFromMenu) UserCommand(iAuth, "leashmenu", kMessageID, bFromMenu);
            } else {
                if (sVal != "")
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Oops! The leash can only reach 20 meters at most.", kMessageID);
                Dialog(kMessageID, "\nCurrently the leash reaches " + (string)g_iLength + "m.", ["1", "2", "3", "4", "5", "6", "8", "10", "12", "15", "20"], [BUTTON_UPMENU], 0, iAuth,"SetLength");
            }
        } else if (sComm == "anchor") {
            if (CheckCommandAuth(kMessageID, iAuth) == FALSE) {
                if (bFromMenu) UserCommand(iAuth, "post", kMessageID, bFromMenu);
            }
            if (sVal == llToLower(BUTTON_UPMENU)) UserCommand(iAuth, "menu leash", kMessageID ,bFromMenu);
            else if((key)sVal) {
                list lPoints;
                if (llGetListLength(lParam) > 2) lPoints = llList2List(lParam, 2, -1);
                if (llGetAgentSize((key)sVal) != ZERO_VECTOR) g_iPassConfirmed = FALSE;
                else g_iPassConfirmed = TRUE;
                LeashTo((key)sVal, kMessageID, iAuth, lPoints, FALSE);
            } else
                SensorDialog(g_kCmdGiver, "\n\nWhat's going to serve us as a post? If the desired object isn't on the list, please try moving closer.\n", "",iAuth,"PostTarget", PASSIVE|ACTIVE);
        }
    }
}

default
{
    on_rez(integer start_param)
    {
        if (llGetOwner() != g_kWearer) llResetScript();
        g_vRegionSize = osGetRegionSize();
        DoUnleash(FALSE);
    }

    state_entry() {
        g_kWearer = llGetOwner();
        g_vRegionSize = osGetRegionSize();
        DoUnleash(FALSE);
        FindLeashHolder();
    }

    timer()
    {
        vector vLeashedToPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
        integer iIsInSimOrJustOutside = TRUE;
        if(vLeashedToPos == ZERO_VECTOR || vLeashedToPos.x < -25 || vLeashedToPos.x > (g_vRegionSize.x+25) || vLeashedToPos.y < -25 || vLeashedToPos.y > (g_vRegionSize.y+25)) iIsInSimOrJustOutside=FALSE;

        if (iIsInSimOrJustOutside && llVecDist(llGetPos(), vLeashedToPos) < 60) {
            if(g_iLeasherInRange == FALSE) {
                if (g_iAwayCounter) {
                    g_iAwayCounter = 0;
                    llSetTimerEvent(3.0);
                }
                llMessageLinked(LINK_THIS, CMD_PARTICLE, "leash" + g_sCheck + "|" + (string)g_bLeashedToAvi, g_kLeashedTo);
                g_iLeasherInRange = TRUE;
                llTargetRemove(g_iTargetHandle);
                g_vPos = vLeashedToPos;
                g_iTargetHandle = llTarget(g_vPos, (float)g_iLength);
                if (g_vPos != ZERO_VECTOR) llMoveToTarget(g_vPos, 0.8);
                ApplyRestrictions();
            }
        } else {
            if (g_iLeasherInRange) {
                if (g_iAwayCounter > 3) {
                    llTargetRemove(g_iTargetHandle);
                    llReleaseControls();
                    llStopMoveToTarget();
                    llMessageLinked(LINK_THIS, CMD_PARTICLE, "unleash", g_kLeashedTo);
                    g_iLeasherInRange = FALSE;
                    ApplyRestrictions();
                }
            }
            g_iAwayCounter++;
            if (g_iAwayCounter > 200) {
                g_iAwayCounter = 1;
                llSetTimerEvent(11.0);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sMessage, key kMessageID)
    {
        if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sMessage, kMessageID, FALSE);
        else if (iNum == MENUNAME_REQUEST  && sMessage == BUTTON_PARENTMENU) {
            g_lButtons = [];
            llMessageLinked(iSender, MENUNAME_REQUEST, BUTTON_SUBMENU, "");
        } else if (iNum == MENUNAME_RESPONSE) {
            list lParts = llParseString2List(sMessage, ["|"], []);
            if (llList2String(lParts, 0) == BUTTON_SUBMENU) {
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
        } else if (iNum == CMD_SAFEWORD) {
            g_iStay = FALSE;
            llReleaseControls();
            DoUnleash(TRUE);
        } else if (iNum == LM_SETTING_RESPONSE) {
            integer iInd = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, iInd -1);
            string sValue = llGetSubString(sMessage, iInd + 1, -1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == TOK_DEST) {
                    list lParam = llParseString2List(llGetSubString(sMessage, iInd + 1, -1), [","], []);
                    key kTarget = llList2Key(lParam, 0);
                    g_bLeashedToAvi = llList2Integer(lParam, 2);
                    g_bFollowMode = llList2Integer(lParam, 3);
                    list lPoints;
                    if (g_bLeashedToAvi) lPoints = ["collar", "handle"];
                    if (llGetObjectPrimCount(kTarget) == 0 && g_bLeashedToAvi == FALSE) DoUnleash(TRUE);
                    else DoLeash(kTarget, llList2Integer(lParam, 1), lPoints);
                } else if (sToken == TOK_LENGTH) SetLength((integer)sValue);
                else if (sToken == "strict"){
                    list lParam = llParseString2List(llGetSubString(sMessage, iInd+1, -1), [","], []);
                    g_iStrictModeOn = (integer)sValue;
                    g_iStrictRank = llList2Integer(lParam, 1);
                    ApplyRestrictions();
                } else if (sToken == "turn") g_iTurnModeOn = (integer)sValue;
            }
        } else if (iNum == RLV_ON) {
            g_iRLVOn = TRUE;
            ApplyRestrictions();
        } else if (iNum == RLV_OFF) {
            g_iRLVOn = FALSE;
            ApplyRestrictions();
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAV = llList2Key(lMenuParams, 0);
                string sButton = llList2String(lMenuParams, 1);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);
                if (sMenu == "MainDialog"){
                    if (sButton == BUTTON_UPMENU)
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+BUTTON_PARENTMENU, kAV);
                    else if (llListFindList(g_lButtons, [sButton]) != -1)
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+sButton, kAV);
                    else UserCommand(iAuth, llToLower(sButton), kAV, TRUE);
                }
                else if (sMenu == "PostTarget") UserCommand(iAuth, "anchor " + sButton, kAV, TRUE);
                else if (sMenu == "SetLength") UserCommand(iAuth, "length " + sButton, kAV, TRUE);
                else if (sMenu == "Give Holder") UserCommand(iAuth, "give holder", kAV, TRUE);
                else if (sMenu == "LeashTarget") {
                    g_kLeashCmderID = kAV;
                    ConfirmDialog((key)sButton, kAV, "LeashTarget", iAuth);
                } else if (sMenu == "LeashTargetConfirm") {
                    if (sButton == "Yes") {
                        g_iPassConfirmed = TRUE;
                        if (g_kLeashCmderID == g_kWearer) iAuth = CMD_WEARER;
                        UserCommand(iAuth, "pass " + (string)kAV, g_kLeashCmderID, TRUE);
                    } else {
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+NameURI(kAV)+" did not accept %WEARERNAME%'s leash.", g_kLeashCmderID);
                        g_iPassConfirmed = FALSE;
                    }
                    g_kLeashCmderID = NULL_KEY;
                } else if (sMenu == "FollowTarget") {
                    if (kAV == (key)sButton) UserCommand(iAuth, "follow " + (string)kAV, kAV, TRUE);
                    else {
                        g_kLeashCmderID = kAV;
                        ConfirmDialog((key)sButton, kAV, "FollowTarget", iAuth);
                    }
                } else if (sMenu == "FollowTargetConfirm") {
                    if (sButton == "Yes") {
                        g_iPassConfirmed = TRUE;
                        if (g_kLeashCmderID == g_kWearer) iAuth = CMD_WEARER;
                        UserCommand(iAuth, "follow " + (string)kAV, g_kLeashCmderID, TRUE);
                    } else {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+NameURI(kAV)+" denied %WEARERNAME% to follow them.", g_kLeashCmderID);
                    g_iPassConfirmed = FALSE;
                    }
                    g_kLeashCmderID = NULL_KEY;
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sMessage == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sMessage == "LINK_RLV") LINK_RLV = iSender;
            else if (sMessage == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sMessage == "reboot") llResetScript();
    }

    at_target(integer iNum, vector vTarget, vector vMe)
    {
        if (g_iTargetHandle == 0) return;
        llReleaseControls();
        llStopMoveToTarget();
        llTargetRemove(g_iTargetHandle);
        g_iTargetHandle = 0;
        g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
        g_iTargetHandle = llTarget(g_vPos, (float)g_iLength);
        if(g_iJustMoved) {
            vector pointTo = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0) - llGetPos();
            float  turnAngle = llAtan2(pointTo.x, pointTo.y);
            if (g_iTurnModeOn) llMessageLinked(LINK_RLV, RLV_CMD, "setrot:" + (string)(turnAngle) + "=force", NULL_KEY);
            g_iJustMoved = 0;
        }
    }

    not_at_target() {
        if (g_iTargetHandle == 0) return;
        g_iJustMoved = 1;
        if(g_kLeashedTo != NULL_KEY) {
            vector vNewPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
            if (g_vPos != vNewPos) {
                llTargetRemove(g_iTargetHandle);
                g_vPos = vNewPos;
                g_iTargetHandle = llTarget(g_vPos, (float)g_iLength);
            }
            if (g_vPos != ZERO_VECTOR) {
                llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
                llMoveToTarget(g_vPos,1.0);
            } else {
                llReleaseControls();
                llStopMoveToTarget();
            }
        } else {
            llReleaseControls();
            DoUnleash(FALSE);
        }
    }

    run_time_permissions(integer iPerm)
    {
        if (iPerm & PERMISSION_TAKE_CONTROLS)
            llTakeControls(CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON | CONTROL_LEFT | CONTROL_RIGHT | CONTROL_FWD | CONTROL_BACK | CONTROL_UP | CONTROL_DOWN, TRUE, FALSE);
    }
    
    object_rez(key id)
    {
        g_iLength=3;
        DoLeash(id, g_iRezAuth, []);
    }

    changed (integer iChange)
    {
        if (iChange & CHANGED_OWNER) g_kWearer = llGetOwner();
        if (iChange & CHANGED_REGION) g_vRegionSize = osGetRegionSize();
        if (iChange & CHANGED_INVENTORY) FindLeashHolder();
    }
}


