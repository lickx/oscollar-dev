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

// This plugin is the tiny steam-engine behind the LOCK/UNLOCK button
// that lives in the oc_root. It can play different noises depending on
// lock/unlock action and reveal or hide a lock element on the device.
 
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
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;

key g_kWearer;
string g_sGlobalToken = "global_";
integer g_iLocked;
integer g_iHidden;

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
        if (!~iIndex) llSetLinkPrimitiveParamsFast(iLink,[PRIM_GLOW,ALL_SIDES,llList2Float(lGlows,iIndex+1)]);
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

Failsafe() {
    string sName = llGetScriptName();
    if (osIsUUID(sName)) return;
    if(sName != "oc_lock") llRemoveInventory(sName);
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

default {
    state_entry() {
        //llSetMemoryLimit(20480);
        g_kWearer = llGetOwner();
        GetLocks();
        Failsafe();
    }
    on_rez(integer iStart) {
        g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
        Failsafe();
    }
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            sStr = llToLower(sStr);
            if (sStr == "lock") {
                if (iNum == CMD_OWNER || kID == g_kWearer ) {
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
                if (iNum == CMD_OWNER)  {
                    g_iLocked = FALSE;
                    llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,g_sGlobalToken+"locked","");
                    llMessageLinked(LINK_ROOT,LM_SETTING_RESPONSE,g_sGlobalToken+"locked=0","");
                    llOwnerSay("@detach=y");
                    llMessageLinked(LINK_RLV,RLV_CMD,"detach=y","main");
                    llPlaySound("d64c3566-cf76-44b5-ae76-9aabf60efab8",1.0);
                    ShowHideLock();
                    llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"/me is unlocked.",kID);
                } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
            } else if (sStr == "show") g_iHidden = FALSE;
            else if (sStr == "hide") g_iHidden = TRUE;
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr,["="],[]);
            string sToken = llList2String(lParams,0);
            string sValue = llList2String(lParams,1);
            if (sToken == g_sGlobalToken+"locked") {
                g_iLocked = (integer)sValue;
                if (g_iLocked) llOwnerSay("@detach=n");
                ShowHideLock();
            }
        } else if (iNum == RLV_REFRESH || iNum == RLV_CLEAR) {
            if (g_iLocked) llMessageLinked(LINK_RLV, RLV_CMD,"detach=n","main");
            else llMessageLinked(LINK_RLV,RLV_CMD,"detach=y","main");
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }
    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_LINK) GetLocks();
        if (change & CHANGED_COLOR) {
            integer iNewHide = !(integer)llGetAlpha(ALL_SIDES);
            if (g_iHidden != iNewHide) {
                g_iHidden = iNewHide;
                ShowHideLock();
            }
        }
    }
}

