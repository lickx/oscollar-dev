
//  oc_update.lsl
//
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

integer BUILD = 2;
integer CMD_WEARER = 503;
integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_UPDATE = -10;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer BUILD_REQUEST = 17760501;

key g_kWearer;
integer g_iUpstream = 1;
key g_kInstallerID;

Update(){
    integer iPin = (integer)llFrand(99999998.0) + 1;
    llSetRemoteScriptAccessPin(iPin);
    integer iChanInstaller = -12345;
    if (g_iUpstream) iChanInstaller = -7483213;
    llRegionSayTo(g_kInstallerID,iChanInstaller,"ready|"+(string)iPin);
}

key g_kMenuID;

default {
    state_entry() {
        g_kWearer = llGetOwner();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (!llSubStringIndex(sStr,".- ... -.-") && kID == g_kWearer) {
            g_kInstallerID = (key)llGetSubString(sStr,-36,-1);
            g_kMenuID = llGenerateKey();
            llMessageLinked(LINK_DIALOG,DIALOG,(string)g_kWearer+"|\nReady to install?|0|Yes`No|Cancel|"+(string)CMD_WEARER,g_kMenuID);
        } else if (iNum == DIALOG_RESPONSE) {
            if (kID == g_kMenuID) {
                list lParams = llParseString2List(sStr,["|"],[]);
                kID = (key)llList2String(lParams,0);
                string sButton = llList2String(lParams,1);
                if (sButton == "Yes") Update();
                else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"cancelled",kID);
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
        } else if (iNum == BUILD_REQUEST)
            llMessageLinked(iSender,iNum+BUILD,llGetScriptName(),"");
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }
    
    on_rez(integer iStart) {
        if (llGetOwner() != g_kWearer) llResetScript();
    }
}
