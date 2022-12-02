
//  oc_anim.lsl
//
//  Copyright (c) 2008 - 2017 Nandana Singh, Garvin Twine, Cleo Collins,
//  Master Starship, Satomi Ahn, Joy Stipe, Wendy Starfall, Medea Destiny,
//  Sumi Perl, Romka Swallowtail, littlemousy, North Glenwalker et al.
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

list g_lAnims;
list g_lPoseList;
list g_lOtherAnims;
integer g_iNumberOfAnims;

integer g_iCrawl = 1;
string g_sCrawlWalk = "~crawl";
string g_sCrawlPose = "crawl";
float g_fPoseMoveHover = 0.0;
string g_sPoseMoveRun = "~run";

string g_sCurrentPose;
integer g_iLastRank;
integer g_iLastPostureRank = 504;
integer g_iLastPoselockRank = 504;
list g_lAnimButtons;

integer g_iAnimLock;
integer g_iPosture;
list g_lHeightAdjustments;
integer g_iRLV_ON;
integer g_iHoverOn = TRUE;
float g_fHoverIncrement = 0.02;
string g_sPose2Remove;
integer g_iAgentStanding = 1;

integer CMD_OWNER = 500;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_SAFEWORD = 510;

integer EXT_CMD_COLLAR = 499;
integer ATTACHMENT_RESPONSE = 601;

integer NOTIFY = 1002;
integer LOADPIN = -1904;
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
integer RLV_CMD = 6000;
integer RLV_OFF = 6100;
integer RLV_VERSION = 6003;
integer RLV_SHOES = 6108;
integer RLV_NOSHOES = 6109;
integer ANIM_START = 7000;
integer ANIM_STOP = 7001;
integer ANIM_LIST_REQUEST = 7002;
integer ANIM_LIST_RESPONSE =7003;
float g_fStandHover = 0.0;
integer g_iShoesWorn = FALSE;

integer REGION_TELEPORT = 10051;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer g_iAOChannel = -782690;

string g_sSettingToken = "anim_";
key g_kWearer;

list g_lMenuIDs;
integer g_iMenuStride = 3;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

AnimMenu(key kID, integer iAuth) {
    string sPrompt = "\nAnimations\n\n%WEARERNAME%";
    list lButtons;

    if (g_iAnimLock) {
        sPrompt += " is forbidden to change or stop poses on their own";
        lButtons = ["☑ AnimLock"];
    } else {
        sPrompt += " is allowed to change or stop poses on their own";
        lButtons = ["☐ AnimLock"];
    }
    if (llGetInventoryType("~stiff")==INVENTORY_ANIMATION) {
        if (g_iPosture) {
            sPrompt +=" and has their neck forced stiff.";
            lButtons += ["☑ Posture"];
        } else {
            sPrompt +=" and can relax their neck.";
            lButtons += ["☐ Posture"];
        }
    }
    if (g_iCrawl) lButtons += ["☑ Crawl"];
    else lButtons += ["☐ Crawl"];
    lButtons += ["AO Menu", "AO ON", "AO OFF", "Pose"];
    if (~llSubStringIndex(llGetInventoryName(INVENTORY_SCRIPT,1),"couples")) lButtons += "Couples";
    else if (llGetInventoryType("oc_pet") == INVENTORY_SCRIPT) lButtons +=  "Pet me!";
    Dialog(kID, sPrompt, lButtons+g_lAnimButtons, ["BACK"], 0, iAuth, "Anim");
}

PoseMenu(key kID, integer iPage, integer iAuth) {
    string sPrompt = "\nPose\n\nCurrently playing: ";
    if (g_sCurrentPose == "")sPrompt += "-\n";
    else {
        string sActivePose = g_sCurrentPose;
        if (g_iRLV_ON && g_iHoverOn) {
            integer index = llListFindList(g_lHeightAdjustments,[g_sCurrentPose]);
            if (~index) {
                string sAdjustment = llList2String(g_lHeightAdjustments,index+1);
                if ((float)sAdjustment>0.0) sAdjustment = " (+"+llGetSubString(sAdjustment,0,3)+")";
                else if ((float)sAdjustment<0.0) sAdjustment = " ("+llGetSubString(sAdjustment,0,4)+")";
                else sAdjustment = "";
                sActivePose = g_sCurrentPose+sAdjustment;
            }
        }
        sPrompt += sActivePose +"\n";
    }
    if (g_fStandHover!=0.0 && g_iRLV_ON && g_iHoverOn) {
        string sAdjustment;
        if (g_fStandHover>0.0) sAdjustment = "+"+llGetSubString((string)g_fStandHover,0,3);
        else if (g_fStandHover<0.0) sAdjustment = llGetSubString((string)g_fStandHover,0,4);
        sPrompt += "Default Hover = "+(string)sAdjustment;
    }
    list lStaticButtons;
    if (g_iRLV_ON && g_iHoverOn && (llGetListLength(g_lPoseList) <= 8)) lStaticButtons = ["STOP","↑", "↓","BACK"];
    else if (g_iRLV_ON && g_iHoverOn) lStaticButtons = ["↑", "↓","STOP","BACK"];
    else lStaticButtons = ["STOP", "BACK"];
    Dialog(kID, sPrompt, g_lPoseList, lStaticButtons, iPage, iAuth, "Pose");
}

AOMenu(key kID, integer iAuth) {
    llMessageLinked(LINK_ROOT, ATTACHMENT_RESPONSE,"CollarCommand|"+(string)iAuth+"|ZHAO_MENU|"+(string)kID, g_kWearer);
    llRegionSayTo(g_kWearer,g_iAOChannel, "ZHAO_MENU|" + (string)kID);
}

integer SetPosture(integer iOn, key kCommander) {
    if (llGetInventoryType("~stiff")!=INVENTORY_ANIMATION) return FALSE;
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
        if (iOn && !g_iPosture) {
            llStartAnimation("~stiff");
            if (kCommander != NULL_KEY) llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Posture override active.", kCommander);
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"posture=1","");
        } else if (!iOn) {
            llStopAnimation("~stiff");
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"posture", "");
        }
        g_iPosture=iOn;
        return TRUE;
    }
    return FALSE;
}

SetHover(string sStr) {
    float fNewHover = g_fHoverIncrement;
    if (sStr == "↓" || sStr == "hoverdown") fNewHover = -fNewHover;
    else if (sStr != "↑" && sStr != "hoverup") return;
    if (g_sCurrentPose == "") {
        g_fStandHover += fNewHover;
        fNewHover = g_fStandHover;
        if (g_fStandHover)
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"offset_standhover="+(string)g_fStandHover,"");
        else
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"offset_standhover","");
        jump next;
    }
    integer index = llListFindList(g_lHeightAdjustments,[g_sCurrentPose]);
    if (~index) {
        fNewHover = fNewHover + llList2Float(g_lHeightAdjustments,index+1);
        if (fNewHover)
            g_lHeightAdjustments = llListReplaceList(g_lHeightAdjustments,[fNewHover],index+1,index+1);
        else
            g_lHeightAdjustments = llDeleteSubList(g_lHeightAdjustments,index,index+1);
    } else g_lHeightAdjustments += [g_sCurrentPose,fNewHover];
    @next;
    if (g_sCurrentPose == g_sCrawlPose) g_fPoseMoveHover = fNewHover;
    if (g_iShoesWorn)
        llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)(fNewHover+0.1)+"=force",g_kWearer);
    else
        llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fNewHover+"=force",g_kWearer);
    llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,"offset_hovers="+llDumpList2String(g_lHeightAdjustments,","),"");
}

MessageAOs(string sONOFF, string sWhat) {
    llMessageLinked(LINK_ROOT, ATTACHMENT_RESPONSE,"CollarCommand|" + (string)EXT_CMD_COLLAR + "|ZHAO_"+sWhat+sONOFF, g_kWearer);
    llRegionSayTo(g_kWearer,g_iAOChannel, "ZHAO_"+sWhat+sONOFF);
    llRegionSayTo(g_kWearer,-8888,(string)g_kWearer+"boot"+llToLower(sONOFF));
}

RefreshAnim() {
    if (llGetListLength(g_lAnims)) {
        if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
            if (g_iPosture) llStartAnimation("~stiff");
            if (!g_iCrawl) llSetTimerEvent(0.0);
            StartAnim(llList2String(g_lAnims,0));
        }
    }
}

StartAnim(string sAnim) {
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
        if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION) {
            if (llGetListLength(g_lAnims)) UnPlayAnim(llList2String(g_lAnims, 0));
            g_lAnims = [sAnim] + g_lAnims;
            PlayAnim(sAnim);
            MessageAOs("OFF","STAND");
        }
    }
}

PlayAnim(string sAnim) {
    if (g_iRLV_ON && g_iHoverOn) {
        integer index = llListFindList(g_lHeightAdjustments,[sAnim]);
        float fOffset = 0.0;
        if (g_iShoesWorn) fOffset -= 0.1;
        if (~index) {
            fOffset += llList2Float(g_lHeightAdjustments,index+1);
            llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fOffset+"=force",g_kWearer);
        } else if (g_fStandHover)
            llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fOffset+"=force",g_kWearer);
    }
    llStartAnimation(sAnim);
    if (g_iCrawl && g_sCurrentPose != "") llSetTimerEvent(0.5);
}

StopAnim(string sAnim, integer isPoseChange) {
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
        if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION) {
            integer n;
            while(~(n=llListFindList(g_lAnims,[sAnim])))
                g_lAnims = llDeleteSubList(g_lAnims,n,n);
            if (sAnim != "") UnPlayAnim(sAnim);
            if (llGetListLength(g_lAnims)) PlayAnim(llList2String(g_lAnims, 0));
            else if (!isPoseChange) MessageAOs("ON","STAND");
        }
    }
}

UnPlayAnim(string sAnim) {
    if (g_iCrawl) {
        llSetTimerEvent(0.0);
        llStopAnimation(g_sPoseMoveRun);
        llStopAnimation(g_sCrawlWalk);
    }
    if (g_iRLV_ON && g_iHoverOn)
        llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)g_fStandHover+"=force",g_kWearer);
    llStopAnimation(sAnim);
}

checkCrawl() {
    if (llGetInventoryType(g_sCrawlWalk) != INVENTORY_ANIMATION) {
        g_iCrawl = 0;
        llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,g_sSettingToken+"crawl","");
    }
}

CreateAnimList() {
    g_lPoseList=[];
    g_lOtherAnims =[];
    g_iNumberOfAnims = llGetInventoryNumber(INVENTORY_ANIMATION);
    string sName;
    integer i;
    do { sName = llGetInventoryName(INVENTORY_ANIMATION, i);
        if (sName != "" && llSubStringIndex(sName,"~")) {
            if (llListFindList(["-1","-2","+1","+2"],[llGetSubString(sName,-2,-1)]) == -1)
                g_lPoseList+=[sName];
        } else if (!llSubStringIndex(sName,"~")) g_lOtherAnims+=sName;
    } while (g_iNumberOfAnims > ++i);
    llMessageLinked(LINK_SET,ANIM_LIST_RESPONSE,llDumpList2String(g_lPoseList+g_lOtherAnims,"|"),"");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (iNum == CMD_EVERYONE) return;
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    string sValue = llToLower(llList2String(lParams, 1));
    if (sCommand == "menu") {
        if (sValue == "pose") PoseMenu(kID, 0, iNum);
        else if (sValue == "ao") AOMenu(kID, iNum);
        else if (sValue == "animations") AnimMenu(kID, iNum);
    } else if (sStr == "release" || sStr == "stop") {
        if (iNum <= g_iLastRank || !g_iAnimLock) {
            g_iLastRank = 0;
            StopAnim(g_sCurrentPose,FALSE);
            g_sCurrentPose = "";
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"currentpose", "");
        }
    } else if (sStr == "animations") AnimMenu(kID, iNum);
    else if (sStr == "pose") PoseMenu(kID, 0, iNum);
    else if (!llSubStringIndex(sCommand,"hover")) {
        if (llToLower(sStr) == "hover reset") {
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"The default hover was reset.",kID);
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,"offset_standhover","");
            g_fStandHover = 0.0;
            if (g_iRLV_ON && g_iHoverOn && llGetListLength(g_lAnims) == 0)
                llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;0.0=force",g_kWearer);
        } else SetHover(sCommand);
    } else if (sStr == "runaway" && (iNum == CMD_OWNER || iNum == CMD_WEARER)) {
        if (g_sCurrentPose != "") StopAnim(g_sCurrentPose,FALSE);
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"currentpose", "");
    } else if (sCommand == "posture") {
        if ( sValue == "on") {
            if (iNum <= CMD_WEARER) {
                g_iLastPostureRank = iNum;
                SetPosture(TRUE,kID);
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"PostureRank="+(string)g_iLastPostureRank,"");
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Your neck is locked in place.",g_kWearer);
                if (kID != g_kWearer) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME%'s neck is locked in place.", kID);
            } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if ( sValue == "off") {
            if (iNum <= g_iLastPostureRank) {
                g_iLastPostureRank = CMD_WEARER;
                SetPosture(FALSE,kID);
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"PostureRank", "");
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You can move your neck again.",g_kWearer);
                if (kID != g_kWearer) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME% is free to move their neck.", kID);
            }
                else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%",kID);
        }
    } else if (sCommand == "rm" && sValue == "pose") {
        if (kID != g_kWearer || g_iAnimLock) {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
            return;
        }
        g_sPose2Remove = llGetSubString(sStr,8,-1);
        if (llGetInventoryType(g_sPose2Remove) == INVENTORY_ANIMATION) {
            string sPrompt = "\nATTENTION: The pose that you are about to delete is not copyable! It will be removed from the %DEVICETYPE% and sent to you. Please make sure to accept the inventory.\n\nDo you really want to remove the \""+g_sPose2Remove+"\" pose?";
            if (llGetInventoryPermMask(g_sPose2Remove,MASK_OWNER) & PERM_COPY)
                sPrompt = "\nDo you really want to remove the \""+g_sPose2Remove+"\" pose?";
            Dialog(g_kWearer,sPrompt,["Yes","No"],["CANCEL"],0,CMD_WEARER,"RmPose");
        } else
            Dialog(g_kWearer, "\nWhich pose do you want to remove?\n", g_lPoseList,["CANCEL"],0,CMD_WEARER,"RmPoseSelect");
    } else if (sCommand == "animlock") {
        if (sValue=="on") {
            if (iNum<=CMD_WEARER) {
                g_iLastPoselockRank = iNum;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"PoselockRank="+(string)g_iLastPoselockRank,"");
                g_iAnimLock = TRUE;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"animlock=1", "");
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Only owners can change or stop your poses now.",g_kWearer);
                if (kID != g_kWearer) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME% can have their poses changed or stopped only by owners.", kID);
            } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        } else if (sValue == "off") {
            if (iNum<=g_iLastPoselockRank) {
                g_iAnimLock = FALSE;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"animlock", "");
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"PoselockRank", "");
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You are now free to change or stop poses on your own.",g_kWearer);
                if (kID != g_kWearer) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%WEARERNAME% is free to change or stop poses on their own.", kID);
            } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        }
    } else if (sCommand == "ao") {
        if (sValue == "" || sValue == "menu") AOMenu(kID, iNum);
        else if (sValue == "off" || sValue == "on")
            MessageAOs(llToUpper(sValue),"AO");
        else
            llMessageLinked(LINK_ROOT, ATTACHMENT_RESPONSE,"CollarCommand|" + (string)EXT_CMD_COLLAR + "|ZHAO_"+sStr+"|"+(string)kID, kID);
    } else if (sCommand == "crawl" && sValue != "") {
        if ((iNum == CMD_OWNER) || (kID == g_kWearer)) {
            if (sValue == "on") {
                if (llGetInventoryType(g_sCrawlWalk) != INVENTORY_ANIMATION) {
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"This feature is currently not installed.",kID);
                    return;
                }
                g_iCrawl = 1;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"crawl=1" , "");
                RefreshAnim();
                llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Crawl mode activated! \n\n%WEARERNAME% will now crawl while moving when a pose is played through the %DEVICETYPE%. If %WEARERNAME% is sinking into the ground, or hovering above the ground, please play the \"crawl\" stance through the Pose menu and use the [↑] and [↓] buttons to adjust the height offset.\n", kID);
            } else if (sValue == "off") {
                g_iCrawl = 0;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"crawl", "");
                RefreshAnim();
                if (llList2String(lParams,2) == "") llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Crawl mode deactivated.", kID);
            }
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Only owners or the wearer can change crawl settings.",g_kWearer);
    } else if (llGetInventoryType(sStr) == INVENTORY_ANIMATION) {
        if (iNum <= g_iLastRank || !g_iAnimLock || g_sCurrentPose == "") {
            StopAnim(g_sCurrentPose,(g_sCurrentPose != ""));
            g_sCurrentPose = sStr;
            g_iLastRank = iNum;
            StartAnim(g_sCurrentPose);
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"currentpose=" + g_sCurrentPose + "," + (string)g_iLastRank, "");
        } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
    } else if ((sStr == "show animator")&&(iNum == CMD_OWNER || kID == g_kWearer)){
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE,ALL_SIDES,TEXTURE_BLANK,<1,1,0>,ZERO_VECTOR,0.0,PRIM_FULLBRIGHT,ALL_SIDES,TRUE]);
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\nTo hide the animator prim again type:\n\n/%CHANNEL% %PREFIX% hide animator\n",kID);
    } else if ((sStr == "hide animator")&&(iNum == CMD_OWNER || kID == g_kWearer))
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE,ALL_SIDES,TEXTURE_TRANSPARENT,<1,1,0>,ZERO_VECTOR,0.0,PRIM_FULLBRIGHT,ALL_SIDES,FALSE]);
}

PieSlice()
{
    if (llGetAttached()) {
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, ZERO_VECTOR, PRIM_SIZE, <0.05, 0.05, 0.01>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.80, 1.00, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <1.000, 0.753, 1.000>, 0.0
        ]);
    } else { // rezzed on ground
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_POS_LOCAL, <0,0,0.1>, PRIM_SIZE, <0.1, 0.1, 0.02>, PRIM_ROT_LOCAL, ZERO_ROTATION,
            PRIM_TYPE, PRIM_TYPE_CYLINDER, 0, <0.80, 1.00, 0>, 0.05, ZERO_VECTOR, <1,1,0>, ZERO_VECTOR,
            PRIM_COLOR, ALL_SIDES, <1.000, 0.753, 1.000>, 1
        ]);
    }
}

default {
    on_rez(integer iNum) {
        if (iNum == 825) llSetRemoteScriptAccessPin(0);
        if (llGetOwner() != g_kWearer) llResetScript();
        g_iRLV_ON = FALSE;
        checkCrawl();
        PieSlice();
    }

    state_entry() {
        if (llGetStartParameter()==825) llSetRemoteScriptAccessPin(0);
        g_kWearer = llGetOwner();
        checkCrawl();
        if (llGetAttached()) llRequestPermissions(g_kWearer, PERMISSION_TRIGGER_ANIMATION);
        CreateAnimList();
        PieSlice();
    }

    run_time_permissions(integer iPerm) {
        if (iPerm & PERMISSION_TRIGGER_ANIMATION) {
            if (g_iPosture) llStartAnimation("~stiff");
        }
    }

    attach(key kID) {
        if (kID == NULL_KEY) g_lAnims = [];
        else llRequestPermissions(g_kWearer, PERMISSION_TRIGGER_ANIMATION);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum <= CMD_EVERYONE && iNum >= CMD_OWNER) UserCommand(iNum, sStr, kID);
        else if (iNum == ANIM_START) StartAnim(sStr);
        else if (iNum == ANIM_STOP) StopAnim(sStr,FALSE);
        else if (iNum == MENUNAME_REQUEST && sStr == "Main") {
            llMessageLinked(iSender, MENUNAME_RESPONSE, "Main|Animations", "");
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Animations", "");
        } else if (iNum == MENUNAME_RESPONSE) {
            if (llSubStringIndex(sStr, "Animations|") == 0) {
                string child = llList2String(llParseString2List(sStr, ["|"], []), 1);
                if (llListFindList(g_lAnimButtons, [child]) == -1) g_lAnimButtons += [child];
            }
        } else if (iNum == CMD_SAFEWORD) {
            if (llGetInventoryType(g_sCurrentPose) == INVENTORY_ANIMATION) {
                g_iLastRank = 0;
                StopAnim(g_sCurrentPose,FALSE);
                g_iAnimLock = FALSE;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"currentpose", "");
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"animlock", "");
                g_sCurrentPose = "";
            }
        } else if (iNum == ANIM_LIST_REQUEST) {
            CreateAnimList();
            llMessageLinked(iSender,ANIM_LIST_RESPONSE,llDumpList2String(g_lPoseList+g_lOtherAnims,"|"),"");
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "currentpose") {
                    list lAnimParams = llParseString2List(sValue, [","], []);
                    g_sCurrentPose = llList2String(lAnimParams, 0);
                    g_iLastRank = (integer)llList2String(lAnimParams, 1);
                    StartAnim(g_sCurrentPose);
                } else if (sToken == "animlock") g_iAnimLock = (integer)sValue;
                else if (sToken =="posture") SetPosture((integer)sValue,NULL_KEY);
                else if (sToken == "PostureRank") g_iLastPostureRank= (integer)sValue;
                else if (sToken == "PoselockRank") g_iLastPoselockRank= (integer)sValue;
                else if (sToken == "crawl") {
                    g_iCrawl = (integer)sValue;
                    checkCrawl();
                }
            } else if (llGetSubString(sToken,0,i) == "offset_") {
                sToken = llGetSubString(sToken,i+1,-1);
                if (sToken == "AllowHover") {
                    g_iHoverOn = (integer)llGetSubString(sValue,0,0);
                    g_fHoverIncrement = (float)llGetSubString(sValue,2,-1);
                    if (g_fHoverIncrement == 0.0) g_fHoverIncrement = 0.02;
                } else if (sToken == "hovers") {
                    g_lHeightAdjustments = llParseString2List(sValue,[","],[]);
                    integer index = llListFindList(g_lHeightAdjustments,[g_sCrawlPose]);
                    if (~index)
                        g_fPoseMoveHover = (float)llList2String(g_lHeightAdjustments,index+1);
                } else if (sToken == "standhover") g_fStandHover = (float)sValue;
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenuType == "Anim") {
                    if (sMessage == "BACK")
                        llMessageLinked(LINK_ALL_OTHERS, iAuth, "menu Main", kAv);
                    else if (sMessage == "Pose") PoseMenu(kAv, 0, iAuth);
                    else if (sMessage == "Couples") llMessageLinked(LINK_THIS,iAuth,"menu Couples",kAv);
                    else if (sMessage == "Pet me!") llMessageLinked(LINK_THIS,iAuth,"menu pet",kAv);
                    else if (sMessage == "AO Menu") {
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"\n\nAttempting to trigger the AO menu. This will only work if %WEARERNAME% is using an OsCollar AO or an AO Link script in their AO HUD.\n\nhttps://github.com/lickx/oscollar/wiki/OsCollar-AO\n", kAv);
                        AOMenu(kAv, iAuth);
                    } else {
                        string sOnOff;
                        if (!llSubStringIndex(sMessage,"☐")) sOnOff = " on";
                        else if (!llSubStringIndex(sMessage,"☑")) sOnOff = " off";
                        if (sOnOff != "")
                            UserCommand(iAuth,llGetSubString(sMessage,2,-1)+sOnOff,kAv);
                        else UserCommand(iAuth, sMessage, kAv);
                        AnimMenu(kAv, iAuth);
                    }
                } else if (sMenuType == "Pose") {
                    if (sMessage == "BACK") AnimMenu(kAv, iAuth);
                    else if (sMessage == "↑" || sMessage == "↓") {
                        SetHover(sMessage);
                        PoseMenu(kAv, iPage, iAuth);
                    } else {
                        if (sMessage == "STOP") UserCommand(iAuth, "release", kAv);
                        else UserCommand(iAuth, sMessage, kAv);
                        PoseMenu(kAv, iPage, iAuth);
                    }
                } else if (sMenuType == "RmPoseSelect") {
                    if (sMessage != "CANCEL") UserCommand(iAuth, "rm pose "+sMessage,kAv);
                } else if (sMenuType == "RmPose") {
                    if (sMessage == "Yes") {
                        if (llGetInventoryType(g_sPose2Remove) == INVENTORY_ANIMATION) {
                            if (llGetInventoryPermMask(g_sPose2Remove,MASK_OWNER) & PERM_COPY) {
                                llRemoveInventory(g_sPose2Remove);
                                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\nThe \""+g_sPose2Remove+"\" pose has been removed from your %DEVICETYPE%.\n",g_kWearer);
                            } else {
                                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"\n\nThe \""+g_sPose2Remove+"\" pose has been removed from your %DEVICETYPE% and is now being delivered to you from an object called \""+llGetObjectName()+"\". This particular pose is not copyable. If you want to keep it, please make sure to accept the inventory.\n",g_kWearer);
                                llGiveInventory(g_kWearer,g_sPose2Remove);
                            }
                        }
                        CreateAnimList();
                    }
                    g_sPose2Remove = "";
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);
        } else if (iNum == LOADPIN && ~llSubStringIndex(llGetScriptName(),sStr)) {
            integer iPin = (integer)llFrand(99999.0)+1;
            llSetRemoteScriptAccessPin(iPin);
            llMessageLinked(iSender, LOADPIN, (string)iPin+"@"+llGetScriptName(),llGetKey());
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
            else if (sStr == "LINK_REQUEST") llMessageLinked(LINK_ALL_OTHERS,LINK_UPDATE,"LINK_ANIM","");
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
        else if (iNum == RLV_VERSION) g_iRLV_ON = TRUE;
        else if (iNum == RLV_SHOES) g_iShoesWorn = TRUE;
        else if (iNum == RLV_NOSHOES) g_iShoesWorn = FALSE;
        else if (iNum == RLV_OFF) g_iRLV_ON = FALSE;
        else if (iNum == REGION_TELEPORT) RefreshAnim();
    }

    timer() {
        integer iAgentState = llGetAgentInfo(g_kWearer);
        float fHover;
        if ((iAgentState & AGENT_ALWAYS_RUN) == AGENT_ALWAYS_RUN) {
            if (g_iAgentStanding != 2) {
                g_iAgentStanding = 2;
                llStopAnimation(g_sCurrentPose);
                llStopAnimation(g_sCrawlWalk);
                if (g_iRLV_ON && g_iHoverOn) {
                    fHover = g_fStandHover;
                    llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fHover+"=force",g_kWearer);
                }
                llStartAnimation(g_sPoseMoveRun);
            }
        } else if ((iAgentState & AGENT_WALKING) == AGENT_WALKING) {
            if (g_iAgentStanding) {
                g_iAgentStanding = 0;
                llStopAnimation(g_sCurrentPose);
                if (g_iRLV_ON && g_iHoverOn) {
                    fHover = g_fPoseMoveHover;
                    llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fHover+"=force",g_kWearer);
                }
                llStartAnimation(g_sCrawlWalk);
            }
        } else if (g_iAgentStanding != 1) {
            llStopAnimation(g_sPoseMoveRun);
            llStopAnimation(g_sCrawlWalk);
            g_iAgentStanding = 1;
            if (g_iRLV_ON && g_iHoverOn) {
                fHover = 0.0;
                integer index = llListFindList(g_lHeightAdjustments,[g_sCurrentPose]);
                if (~index) fHover = (float)llList2String(g_lHeightAdjustments,index+1);
                llMessageLinked(LINK_RLV,RLV_CMD,"adjustheight:1;0;"+(string)fHover+"=force",g_kWearer);
            }
            StartAnim(llList2String(g_lAnims,0));
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_INVENTORY) {
            if (g_iNumberOfAnims != llGetInventoryNumber(INVENTORY_ANIMATION)) CreateAnimList();
            checkCrawl();
        }
    }
}
