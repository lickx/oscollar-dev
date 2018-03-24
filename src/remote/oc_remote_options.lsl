
//  Copyright (c) 2014 - 2016 Nandana Singh, Jessenia Mocha, Alexei Maven,
//  Master Starship, Wendy Starfall, North Glenwalker, Ray Zopf, Sumi Perl,
//  Kire Faulkes, Zinn Ixtar, Builder's Brewery, Romka Swallowtail et al.
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

//Adjusted to OpenCollar name convention und format standards June 2015 Otto (garvin.twine)
//Updated Romka(romka.swallowtail)

// MESSAGE MAPS
integer CMD_TOUCH         = 100;
integer MENUNAME_REQUEST  = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU           = 3002;
integer DIALOG            = -9000;
integer DIALOG_RESPONSE   = -9001;
integer DIALOG_TIMEOUT    = -9002;

// Constants
string UPMENU         = "BACK";
string g_sParentMenu  = "Main";
string g_sHudMenu     = "HUD Style";
string g_sTextureMenu = "Theme";
string g_sOrderMenu   = "Order";

list g_lAttachPoints = [
    ATTACH_HUD_TOP_RIGHT,
    ATTACH_HUD_TOP_CENTER,
    ATTACH_HUD_TOP_LEFT,
    ATTACH_HUD_BOTTOM_RIGHT,
    ATTACH_HUD_BOTTOM,
    ATTACH_HUD_BOTTOM_LEFT,
    ATTACH_HUD_CENTER_1,
    ATTACH_HUD_CENTER_2
    ];

float g_fGap = 0.001; // This is the space between buttons
float g_Yoff = 0.002; // space between buttons and screen top/bottom border
float g_Zoff = 0.04; // space between buttons and screen left/right border

// Variables

vector g_vColor = <1,1,1>;
key g_kMenuID;
string g_sCurrentMenu;
string g_sCurrentTheme;
list g_lStyles;
list g_lButtons ; // buttons names for Order menu
list g_lPrimOrder ;
//  List must always start with '0','1'
//  0:Spacer, 1:Root, 2:Menu, 3:Couples, 4:Bookmarks, 5:Leash, 6:Beckon
//  Spacer serves to even up the list with actual link numbers

integer g_iVertical = TRUE;  // can be vertical?
integer g_iLayout = 1; // 0 - Horisontal, 1 - Vertical
integer g_iHidden = FALSE;
integer g_iSPosition = 69; // Nuff'said =D
integer g_iOldPos;
integer g_iNewPos;
integer g_iColumn = 1;  // 0 - Column, 1 - Alternate
integer g_iRows = 3;  // nummer of Rows: 1,2,3,4... up to g_iMaxRows
integer g_iMaxRows = 4; // maximal Rows in Columns

//**************************

key Dialog(key kRcpt, string sPrompt, list lChoices, list lUtilityButtons, integer iPage) {
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRcpt + "|" + sPrompt + "|" + (string)iPage +
 "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

FindButtons() { // collect buttons names & links
    g_lButtons = [" ", "Minimize"] ; // 'Minimize' need for texture
    g_lPrimOrder = [0, 1];  //  '1' - root prim
    integer i;
    for (i=2; i<llGetNumberOfPrims()+1; ++i) {
        g_lButtons += llGetLinkPrimitiveParams(i, [PRIM_NAME]);
        g_lPrimOrder += i;
    }
    g_iMaxRows = llFloor(llSqrt(llGetListLength(g_lButtons)-1));
}

PlaceTheButton(float fYoff, float fZoff) {
    list lPrimOrder = llDeleteSubList(g_lPrimOrder, 0, 0);
    integer n = llGetListLength(lPrimOrder);
    vector pos ;
    integer i;
    float fXoff = 0.01; // small X offset
    for (i=1; i < n; ++i) {
        if (g_iColumn == 0) { // Column
            if (!g_iLayout) pos = <fXoff, fYoff*(i-(i/(n/g_iRows))*(n/g_iRows)), fZoff*(i/(n/g_iRows))>;
            else pos = <fXoff, fYoff*(i/(n/g_iRows)), fZoff*(i-(i/(n/g_iRows))*(n/g_iRows))>;
        } else if (g_iColumn == 1) { // Alternate
            if (!g_iLayout) pos = <fXoff, fYoff*(i/g_iRows), fZoff*(i-(i/g_iRows)*g_iRows)>;
            else  pos = <fXoff, fYoff*(i-(i/g_iRows)*g_iRows), fZoff*(i/g_iRows)>;
        }
        llSetLinkPrimitiveParamsFast(llList2Integer(lPrimOrder,i),[PRIM_POSITION,pos]);
    }
}


DoStyle(string style) {

    list lTextures = [
    "[ Dark ]",
    "Minimize~857cda3b-5a50-463f-9e3e-3d289b85c5df",
    "Picture~57701142-dac0-49f5-9d1c-005bdf10277b",
    "Menu~cdcd94ca-e432-4ded-9da2-e52e31f70e22",
    "Couples~8ea5b5c6-1746-4368-b414-dd3f6703a915",
    "Favorite~8991b60a-d6e7-42cb-9743-c4000fce1708",
    "Bookmarks~571822a1-2da4-4544-96ff-2bb6eb915e00",
    "Restrictions~8c6db70d-0774-4522-923a-c2ae74615001",
    "Outfits~aeadf0dd-08ca-418b-a79e-9b1ed24f2177",
    "Folders~9b4a0473-3dcf-478f-8f62-8e83225047ea",
    "Leash~0c8f9077-6709-4cf8-a631-3482dab8b83a",
    "Unleash~814eeb41-7b23-4c4e-9bb9-1bf3e91747d5",
    "Yank~1d6d4244-a3d8-432d-b4c5-400bc7518bd2",
    "Sit~4ad0b607-24be-4da7-999b-afb771c4b392",
    "Stand~81df8bd8-7f5a-4daa-9e7f-e5e8b854913f",
    "Rez~983068ba-10ff-4e1a-8fbf-595fbee4bdbe",
    "Pose~0e2789c2-2185-4aee-94d0-c99e6598af20",
    "Stop~01f439dd-dccf-4fc5-9bf2-49ab05716190",
    "Hudmenu~3b6ae950-9b47-42ad-8542-e3d05dca45d9",
    "Acc-Gag~101286a6-0420-94a5-913b-60a027c3988e",
    "Acc-Blindfold~a9ae5c9a-f865-87b6-2ebf-c254c7cacb22",
    "Acc-Cuffs~1ad97509-88c3-a829-dfac-d3fc54422954",
    "[ Light ]",
    "Minimize~a9d26a81-e5b6-4eff-aa4f-625e03e04f15",
    "Picture~442fd720-8d12-4529-8dea-3fdfa60d5eec",
    "Menu~83779c3b-5028-4a43-87d4-60b924afaebb",
    "Couples~548ff8ec-8dbd-4191-a7bd-c6cfd14972d7",
    "Favorite~8df68683-da35-4f7a-a82b-c240668ba4b1",
    "Bookmarks~fd00eaf4-4849-4f1a-af9a-28d0d61f9b7a",
    "Restrictions~0af359e0-09d4-40f6-a997-725f479c56ce",
    "Outfits~619c4651-157e-46dd-9ffd-c762266c0f89",
    "Folders~c7bc8d21-7aed-4d5e-b829-45db2085bea5",
    "Leash~f059819e-4fa7-4585-8639-0fc46cd7c005",
    "Unleash~29b1aca7-f017-4b8e-be72-5fd313a9640e",
    "Yank~8d47a648-05d1-496e-9862-7fc43a06841d",
    "Sit~2d71a6f7-48d9-4b4f-a15a-b212e62d7f4d",
    "Stand~9be7d80a-6516-4580-93a4-0ba3e89f1987",
    "Rez~22dc5eac-fdf2-4648-8fb2-31bb69a2d232",
    "Pose~7d33dd7b-7b35-4c05-b183-f46e0024a248",
    "Stop~2df92ed5-a32f-4052-a95f-4b30cfddfa14",
    "Hudmenu~2690e879-4d41-4fee-a6e6-1b2a8ffe83ab",
    "Acc-Gag~b2719596-e1db-e3f9-bbbf-03c4c7f6d633",
    "Acc-Blindfold~51b8d911-9a46-b89d-c3e6-41903825837b",
    "Acc-Cuffs~6dce2821-9cbd-f6a3-fc3a-fcdef6e2ff0d"
    ];

    integer i;
    while (i < llGetListLength(lTextures)) {
        string sData = llStringTrim(llList2String(lTextures,i),STRING_TRIM);
        if (sData!="" && llSubStringIndex(sData,"#") != 0) {
            if (llGetSubString(sData,0,0) == "[") {
                sData = llGetSubString(sData,llSubStringIndex(sData,"[")+1,llSubStringIndex(sData,"]")-1);
                sData = llStringTrim(sData,STRING_TRIM);
                if (style=="initialize") {  //reading notecard to determine style names
                    g_lStyles += sData;
                } else if (sData==style) {  //we just found our section
                    style="processing";
                    g_sCurrentTheme = sData;
                } else if (style=="processing") {  //we just found the start of the next section, we're
                    return;
                }
            } else if (style=="processing") {
                list lParams = llParseStringKeepNulls(sData,["~"],[]);
                string sButton = llStringTrim(llList2String(lParams,0),STRING_TRIM);
                integer link = llListFindList(g_lButtons,[sButton]);
                if (link > 0) {
                    sData = llStringTrim(llList2String(lParams,1),STRING_TRIM);
                    if (sData != "" && sData != ",") {
                        if (sButton == "Picture") llMessageLinked(LINK_SET, 111, sData, "");
                        else llSetLinkPrimitiveParamsFast(link,[PRIM_TEXTURE, ALL_SIDES, sData , <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, g_vColor, 1.0]);
                    }
                }
            }
        }
        i++;
    }
}

DefinePosition() {
    integer iPosition = llListFindList(g_lAttachPoints, [llGetAttached()]);
    vector size = llGetScale();
//  Allows manual repositioning, without resetting it, if needed
    if (iPosition != g_iSPosition && iPosition != -1) { //do this only when attached to the hud
        vector offset = <0, size.y/2+g_Yoff, size.z/2+g_Zoff>;
        if (iPosition==0||iPosition==1||iPosition==2) offset.z = -offset.z;
        if (iPosition==2||iPosition==5) offset.y = -offset.y;
        if (iPosition==1||iPosition==4) { g_iLayout = 0; g_iVertical = FALSE;}
        else { g_iLayout = 1; g_iVertical = TRUE; }
        llSetPos(offset); // Position the Root Prim on screen
        g_iSPosition = iPosition;
    }
    if (g_iHidden)  // -- Fixes Issue 615: HUD forgets hide setting on relog.
        llSetLinkPrimitiveParamsFast(LINK_ALL_OTHERS, [PRIM_POSITION, <1.0, 0.0, 0.0>]);
    else {
        float fYoff = size.y + g_fGap; float fZoff = size.z + g_fGap; // This is the space between buttons
        if (iPosition == 0 || iPosition == 1 || iPosition == 2) fZoff = -fZoff;
        if (iPosition == 1 || iPosition == 2 || iPosition == 4 || iPosition == 5) fYoff = -fYoff;
        PlaceTheButton(fYoff, fZoff); // Does the actual placement
    }
}

DoButtonOrder() {   // -- Set the button order and reset display
    integer iOldPos = llList2Integer(g_lPrimOrder,g_iOldPos);
    integer iNewPos = llList2Integer(g_lPrimOrder,g_iNewPos);
    integer i = 2;
    list lTemp = [0,1];
    for(;i<llGetListLength(g_lPrimOrder);++i) {
        integer iTempPos = llList2Integer(g_lPrimOrder,i);
        if (iTempPos == iOldPos) lTemp += [iNewPos];
        else if (iTempPos == iNewPos) lTemp += [iOldPos];
        else lTemp += [iTempPos];
    }
    g_lPrimOrder = lTemp;
    g_iOldPos = -1;
    g_iNewPos = -1;
    DefinePosition();
}


DoMenu(string sMenu) {

    string sPrompt;
    list lButtons;
    list lUtils = [UPMENU];

    if (sMenu == "Horizontal >" || sMenu == "Vertical >") {
        g_iLayout = !g_iLayout;
        DefinePosition();
        sMenu = g_sHudMenu;
    }
    else if (sMenu == "Columns >" || sMenu == "Alternate >") {
        g_iColumn = !g_iColumn;
        DefinePosition();
        sMenu = g_sHudMenu;
    }
    else if (llSubStringIndex(sMenu,"Rows")==0) {
        // this feature is not mandatory, it just passes uneven rows.
        // for the simple can use only g_iRows++;
        integer n = llGetListLength(g_lPrimOrder)-1;
        do {
            g_iRows++;
        } while ((n/g_iRows)*(n/(n/g_iRows)) != n);
        //
        if (g_iRows > g_iMaxRows) g_iRows = 1;
        DefinePosition();
        sMenu = g_sHudMenu;
    }
    else if (sMenu == g_sTextureMenu) { // textures
        sPrompt = "\nCurrent button theme: " + g_sCurrentTheme;
        lButtons = g_lStyles;
    }
    else if (sMenu == g_sOrderMenu) { // Order
        sPrompt = "\nThis is the order menu, simply select the\n";
        sPrompt += "button which you want to re-order.\n\n";
        integer i;
        for (i=2;i<llGetListLength(g_lPrimOrder);++i) {
            integer pos = llList2Integer(g_lPrimOrder,i);
            lButtons += llList2List(g_lButtons,pos,pos);
        }
        lUtils = ["Reset",UPMENU];
    }
    if (sMenu == g_sHudMenu) { // Main
        sPrompt = "\nCustomize your Remote!";
        lButtons = ["Rows: "+(string)g_iRows] ;
        if (g_iRows > 1) lButtons += llList2List(["Columns >","Alternate >"], g_iColumn, g_iColumn) ;
        else lButtons += [" - "] ;
        if (g_iVertical) lButtons += llList2List(["Horizontal >","Vertical >"], g_iLayout,g_iLayout) ;
        else lButtons += [" - "] ;
        lButtons += [g_sOrderMenu,g_sTextureMenu,"Reset"];
    }
    g_sCurrentMenu = sMenu;
    g_kMenuID = Dialog(llGetOwner(), sPrompt, lButtons, lUtils, 0);
}

OrderButton(string sButton)
{
    g_sCurrentMenu = g_sOrderMenu;
    list lButtons;
    string sPrompt;
    integer iTemp = llListFindList(g_lButtons,[sButton]);
    g_iOldPos = llListFindList(g_lPrimOrder, [iTemp]);

    sPrompt = "\nSelect the new position for swap with "+sButton+"\n\n";
    integer i;
    for(i=2;i<llGetListLength(g_lPrimOrder);++i) {
        if (g_iOldPos != i) {
            iTemp = llList2Integer(g_lPrimOrder,i);
            lButtons +=[llList2String(g_lButtons,iTemp)+":"+(string)i];
        }
    }
    g_kMenuID = Dialog(llGetOwner(), sPrompt, lButtons, [UPMENU], 0);
}

FailSafe() {
    string sName = llGetScriptName();
    if (osIsUUID(sName)) return;
    if (!(llGetObjectPermMask(1) & 0x4000)
    || !(llGetObjectPermMask(4) & 0x4000)
    || !((llGetInventoryPermMask(sName,1) & 0xe000) == 0xe000)
    || !((llGetInventoryPermMask(sName,4) & 0xe000) == 0xe000)
    || sName != "oc_remote_options")
        llRemoveInventory(sName);
}

default
{
    state_entry() {
        //llSleep(1.0);
        FailSafe();
        FindButtons(); // collect buttons names
        DefinePosition();
        DoStyle("initialize");
        DoStyle(llList2String(g_lStyles, 0));
       // llOwnerSay("Finalizing HUD Reset... please wait a few seconds so all menus have time to initialize.");
    }

    attach(key kAttached) {
        integer iAttachPoint = llGetAttached();
//      if being detached
        if (kAttached == NULL_KEY)
            return;
        else if (iAttachPoint < 31 || iAttachPoint > 38) {//http://wiki.secondlife.com/wiki/LlAttachToAvatar attach point integer values - 31-38 are hud placements
            llOwnerSay("Sorry, this device can only be placed on the HUD. Attach code: " + (string)iAttachPoint);
            llRequestPermissions(kAttached, PERMISSION_ATTACH);
            llDetachFromAvatar();
            return;
        }
        else // It's being attached and the attachment point is a HUD position, DefinePosition()
            DefinePosition();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == SUBMENU && sStr == g_sHudMenu) DoMenu(g_sHudMenu);
        else if (iNum == DIALOG_RESPONSE && kID == g_kMenuID) {
            list lParams = llParseString2List(sStr, ["|"], []);
            //kID = (key)llList2String(lParams, 0);
            string sButton = llList2String(lParams, 1);
            //integer iPage = (integer)llList2String(lParams, 2);
            if (g_sCurrentMenu == g_sHudMenu) {   // -- Inside the 'Options' menu, or 'submenu'
                // If we press the 'Back' and we are inside the Options menu, go back to OwnerHUD menu
                if (sButton == UPMENU) {
                    llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);
                    return;
                } else if (sButton == "Reset") {
                    llOwnerSay("Resetting the HUD-Style to the default.");
                    llResetScript();
                } else if (sButton == "Cancel") g_sCurrentMenu = g_sHudMenu;
                else g_sCurrentMenu = sButton;
            } else if (g_sCurrentMenu == g_sTextureMenu) {// -- Inside the 'Texture' menu, or 'submenu1'
                if (sButton == UPMENU) g_sCurrentMenu = g_sHudMenu;
                else DoStyle(sButton);
            } else if (g_sCurrentMenu == g_sOrderMenu) {
                if (sButton == UPMENU) g_sCurrentMenu = g_sHudMenu;
                else if (sButton == "Reset") {
                    FindButtons();
                    llOwnerSay("Order position reset to default.");
                    DefinePosition();
                } else if (llSubStringIndex(sButton,":") >= 0) { // Jess's nifty parsing trick for the menus
                    g_iNewPos = llList2Integer(llParseString2List(sButton,[":"],[]),1);
                    DoButtonOrder();
                } else {
                    OrderButton(sButton);
                    return;
                }
            }
            DoMenu(g_sCurrentMenu);
        } else if (iNum == CMD_TOUCH) {
            if (sStr == "hide") {
                g_iHidden = !g_iHidden;
                DefinePosition();
            }
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_LINK) llResetScript();
        if (iChange & CHANGED_INVENTORY) FailSafe();
    }
}
