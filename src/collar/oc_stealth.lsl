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

 This file contains modifications by Lotek Ixtar
 
 */

// This plugin can be used to hide the whole device (and to show it again).

integer CMD_OWNER = 500;
integer CMD_WEARER = 503;
integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_UPDATE = -10;

integer g_iHidden;
list g_lGlowy;

Stealth (string sStr) {
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
            if (fGlow > 0) g_lGlowy += [iCount,fGlow];
        }
        llSetLinkPrimitiveParamsFast(LINK_SET,[PRIM_GLOW,ALL_SIDES,0.0]);
    } else {
        integer i;
        iCount = llGetListLength(g_lGlowy);
        for (;i < iCount;i += 2)
            llSetLinkPrimitiveParamsFast(llList2Integer(g_lGlowy,i),[PRIM_GLOW,ALL_SIDES,llList2Float(g_lGlowy,i+1)]);
        g_lGlowy = [];
    }
}

Failsafe() {
    string sName = llGetScriptName();
    if (osIsUUID(sName)) return;
    if (sName != "oc_stealth") llRemoveInventory(sName);
}

Init() {
    g_iHidden = !(integer)llGetAlpha(ALL_SIDES);
    Failsafe();
}

default {
    state_entry() {
        Init();
    }
    on_rez(integer iStart) {
        Init();
    }
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == LINK_UPDATE &&  sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
        else {
            string sLowerstr = llToLower(sStr);
            if (sLowerstr == "hide" || sLowerstr == "show" || sLowerstr == "stealth") {
                if (iNum == CMD_OWNER || iNum == CMD_WEARER) Stealth(sLowerstr);
                else if (osIsUUID(kID)) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
            } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
        }
    }
    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_INVENTORY) Failsafe();
    }
}
