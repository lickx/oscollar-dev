
//  Copyright (c) 2016 Garvin Twine
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

// oc remote - LeashPost rez script 160112.1
// leashpost sends out a anchor to me command to all ID transmitted by the hud
// Otto(garvin.twine) 2016

integer g_iListener;

integer RemoteChannel(string sID,integer iOffset) {
    integer iChan = -llAbs((integer)("0x"+llGetSubString(sID,-7,-1)) + iOffset);
    return iChan;
}

FailSafe() {
    string sName = llGetScriptName();
    if (osIsUUID(sName)) return;
    if (!(llGetObjectPermMask(1) & 0x4000)
    || !(llGetObjectPermMask(4) & 0x4000)
    || !((llGetInventoryPermMask(sName,1) & 0xe000) == 0xe000)
    || !((llGetInventoryPermMask(sName,4) & 0xe000) == 0xe000)
    || sName != "oc_remote_leashpost")
        llRemoveInventory(sName);
}

default {
    on_rez(integer iStart) {
        llResetScript();
    }

    state_entry() {
        llSetMemoryLimit(16384);
        FailSafe();
        g_iListener = llListen(RemoteChannel(llGetOwner(),1234),"","","");
        list lTemp = llParseString2List(llGetObjectDesc(),["@"],[]);
        vector vRot = (vector)("<"+llList2String(lTemp,1)+">");
        vector vPos = (vector)("<"+llList2String(lTemp,2)+">");
        llSetRot(llEuler2Rot(vRot * DEG_TO_RAD));
        llSetPos(llGetPos()+vPos);
    }

    listen(integer iChannel, string sName, key kID, string sMessage) {
        llListenRemove(g_iListener);
        string sObjectID = (string)llGetKey();
        list lToLeash = llParseString2List(sMessage,[","],[]);
        integer i = llGetListLength(lToLeash);
        key kID;
        while (i) {
            kID = llList2Key(lToLeash,--i);
            llRegionSayTo(kID,RemoteChannel(kID,0),"anchor "+sObjectID);
        }
    }
    changed(integer iChange) {
        if (iChange & CHANGED_INVENTORY) FailSafe();
    }
}
