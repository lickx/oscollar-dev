
//  oc_oh_options.lsl
//
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

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

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
float g_Zoff = 0.15; // space between buttons and screen left/right border

// Variables

key g_kOwner = NULL_KEY;
vector g_vColor = <1,1,1>;
key g_kMenuID = NULL_KEY;
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
integer g_iRows = 2;  // nummer of Rows: 1,2,3,4... up to g_iMaxRows
integer g_iMaxRows = 4; // maximal Rows in Columns

//**************************

key Dialog(key kRcpt, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRcpt + "|" + sPrompt + "|" + (string)iPage +
 "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

// collect buttons names & links
FindButtons()
{
    g_lButtons = [" ", "Minimize"] ; // 'Minimize' need for texture
    g_lPrimOrder = [0, 1];  //  '1' - root prim
    integer i;
    for (i = 2; i < llGetNumberOfPrims()+1; ++i) {
        g_lButtons += llGetLinkName(i);
        g_lPrimOrder += i;
    }
    g_iMaxRows = llFloor(llSqrt(llGetListLength(g_lButtons)-1));
}

PlaceTheButton(float fYoff, float fZoff)
{
    list lPrimOrder = llDeleteSubList(g_lPrimOrder, 0, 0);
    integer n = llGetListLength(lPrimOrder);
    vector pos ;
    integer i;
    float fXoff = 0.01; // small X offset
    for (i = 1; i < n; ++i) {
        if (g_iColumn == 0) { // Column
            if (g_iLayout == 0) pos = <fXoff, fYoff*(i-(i/(n/g_iRows))*(n/g_iRows)), fZoff*(i/(n/g_iRows))>;
            else pos = <fXoff, fYoff*(i/(n/g_iRows)), fZoff*(i-(i/(n/g_iRows))*(n/g_iRows))>;
        } else if (g_iColumn == 1) { // Alternate
            if (g_iLayout == 0) pos = <fXoff, fYoff*(i/g_iRows), fZoff*(i-(i/g_iRows)*g_iRows)>;
            else  pos = <fXoff, fYoff*(i-(i/g_iRows)*g_iRows), fZoff*(i/g_iRows)>;
        }
        llSetLinkPrimitiveParamsFast(llList2Integer(lPrimOrder, i), [PRIM_POSITION, pos]);
    }
}


DoStyle(string style)
{
    list lTextures = [
    "[ Dark ]",
    "Minimize~button_dark_opensim",
    "Picture~button_dark_partners",
    "Menu~button_dark_menu",
    "Couples~button_dark_couples",
    "Favorite~button_dark_favorite",
    "Anchor~button_dark_anchor",
    "Restrictions~button_dark_restrictions",
    "Outfits~button_dark_outfits",
    "Folders~button_dark_folders",
    "Leash~button_dark_leash",
    "Unleash~button_dark_unleash",
    "Yank~button_dark_beckon",
    "Sit~button_dark_sit",
    "Stand~button_dark_stand",
    "Rez~button_dark_rez",
    "Pose~button_dark_pose",
    "Stop~button_dark_stop",
    "Hudmenu~button_dark_options",
    "[ Light ]",
    "Minimize~button_light_opensim",
    "Picture~button_light_partners",
    "Menu~button_light_menu",
    "Couples~button_light_couples",
    "Favorite~button_light_favorite",
    "Anchor~button_light_anchor",
    "Restrictions~button_light_restrictions",
    "Outfits~button_light_outfits",
    "Folders~button_light_folders",
    "Leash~button_light_leash",
    "Unleash~button_light_unleash",
    "Yank~button_light_beckon",
    "Sit~button_light_sit",
    "Stand~button_light_sit",
    "Rez~button_light_rez",
    "Pose~button_light_pose",
    "Stop~button_light_stop",
    "Hudmenu~button_light_options"
    ];

    integer i;
    while (i < llGetListLength(lTextures)) {
        string sData = llStringTrim(llList2String(lTextures, i), STRING_TRIM);
        if (sData != "" && llSubStringIndex(sData, "#") != 0) {
            if (llGetSubString(sData, 0, 0) == "[") {
                sData = llGetSubString(sData,llSubStringIndex(sData, "[")+1, llSubStringIndex(sData, "]")-1);
                sData = llStringTrim(sData, STRING_TRIM);
                if (style == "initialize") {  //reading notecard to determine style names
                    g_lStyles += sData;
                } else if (sData == style) {  //we just found our section
                    style = "processing";
                    g_sCurrentTheme = sData;
                    llMessageLinked(LINK_SET, 112, g_sCurrentTheme, "");
                } else if (style == "processing") {  //we just found the start of the next section, we're
                    return;
                }
            } else if (style == "processing") {
                list lParams = llParseStringKeepNulls(sData, ["~"], []);
                string sButton = llStringTrim(llList2String(lParams, 0),STRING_TRIM);
                integer link = llListFindList(g_lButtons, [sButton]);
                if (link > 0) {
                    sData = llStringTrim(llList2String(lParams, 1), STRING_TRIM);
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

DefinePosition()
{
    integer iPosition = llListFindList(g_lAttachPoints, [llGetAttached()]);
    vector size = llGetScale();
//  Allows manual repositioning, without resetting it, if needed
    if (iPosition != g_iSPosition && iPosition != -1) { //do this only when attached to the hud
        vector offset = <0, size.y/2+g_Yoff, size.z/2+g_Zoff>;
        if (iPosition==0 || iPosition==1 || iPosition==2) offset.z = -offset.z;
        if (iPosition==2 || iPosition==5) offset.y = -offset.y;
        if (iPosition==1 || iPosition==4) {
            g_iLayout = 0;
            g_iVertical = FALSE;
        } else {
            g_iLayout = 1;
            g_iVertical = TRUE;
        }
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

// -- Set the button order and reset display
DoButtonOrder()
{
    integer iOldPos = llList2Integer(g_lPrimOrder,g_iOldPos);
    integer iNewPos = llList2Integer(g_lPrimOrder,g_iNewPos);
    integer i = 2;
    list lTemp = [0,1];
    for(i = 2; i < llGetListLength(g_lPrimOrder); ++i) {
        integer iTempPos = llList2Integer(g_lPrimOrder, i);
        if (iTempPos == iOldPos) lTemp += [iNewPos];
        else if (iTempPos == iNewPos) lTemp += [iOldPos];
        else lTemp += [iTempPos];
    }
    g_lPrimOrder = lTemp;
    g_iOldPos = -1;
    g_iNewPos = -1;
    DefinePosition();
}


DoMenu(string sMenu)
{
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
        for (i = 2; i < llGetListLength(g_lPrimOrder); ++i) {
            integer pos = llList2Integer(g_lPrimOrder, i);
            lButtons += llList2List(g_lButtons, pos, pos);
        }
        lUtils = ["Reset", UPMENU];
    }
    if (sMenu == g_sHudMenu) { // Main
        sPrompt = "\nCustomize your Owner HUD!";
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

StoreSettings()
{
    string sSettings;
    string sOldSettings;
    sSettings += "v="+(string)g_iVertical;  // can be vertical?
    sSettings += "~l="+(string)g_iLayout; // 0 - Horisontal, 1 - Vertical
    sSettings += "~h="+(string)g_iHidden;
    sSettings += "~spos="+(string)g_iSPosition; // Nuff'said =D
    sSettings += "~iop="+(string)g_iOldPos;
    sSettings += "~inp="+(string)g_iNewPos;
    sSettings += "~th="+g_sCurrentTheme;
    sOldSettings = llList2String(llGetLinkPrimitiveParams(LINK_THIS, [PRIM_DESC]), 0);
    if (sOldSettings != sSettings)
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_DESC, sSettings]);
    // Store button order:
    integer idx = llListFindList(g_lButtons, "Hudmenu");
    if (idx != -1) {
        string sOrder = osReplaceString(llList2CSV(g_lPrimOrder), " ", "", -1, 0);
        sOldSettings = llList2String(llGetLinkPrimitiveParams(idx, [PRIM_DESC]), 0);
        if (sOldSettings != sOrder) llSetLinkPrimitiveParamsFast(idx, [PRIM_DESC, sOrder]);
    }
}

RestoreSettings()
{
    string sSettings = llList2String(llGetLinkPrimitiveParams(LINK_THIS, [PRIM_DESC]), 0);
    list lSettings = llParseString2List(sSettings, ["~","="], []);
    integer i;
    for (i = 0; i < llGetListLength(lSettings); i+=2) {
        string sKey = llList2String(lSettings, i);
        string sValue = llList2String(lSettings, i+1);
        if (sKey == "v") g_iVertical = (integer)sValue;
        else if (sKey == "l") g_iLayout = (integer)sValue;
        else if (sKey == "h") g_iHidden = (integer)sValue;
        else if (sKey == "spos") g_iSPosition = (integer)sValue;
        else if (sKey == "iop") g_iOldPos = (integer)sValue;
        else if (sKey == "inp") g_iNewPos = (integer)sValue;
        else if (sKey == "th") g_sCurrentTheme = sValue;
    }
    // Restore button order:
    integer idx = llListFindList(g_lButtons, "Hudmenu");
    if (idx != -1) {
        string sDesc = llList2String(llGetLinkPrimitiveParams(idx, [PRIM_DESC]), 0);
        if (sDesc == "Primitive" || sDesc == "(No Description)" || sDesc == "" || llToLower(sDesc) == "hudmenu") return;
        g_lPrimOrder = llParseString2List(sDesc, [","], []);
    }
}

default
{
    state_entry()
    {
        if (llGetInventoryType("oc_installer_sys")==INVENTORY_SCRIPT) return;
        g_kOwner = llGetOwner();
        //llSleep(1.0);
        FindButtons(); // collect buttons names
        RestoreSettings();
        DefinePosition();
        DoStyle("initialize");
        DoStyle(llList2String(g_lStyles, 0));
       // llOwnerSay("Finalizing HUD Reset... please wait a few seconds so all menus have time to initialize.");
    }

    on_rez(integer i)
    {
        if (g_kOwner != llGetOwner()) llResetScript();
    }

    attach(key kAttached)
    {
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

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == SUBMENU && sStr == g_sHudMenu) DoMenu(g_sHudMenu);
        else if (iNum == DIALOG_RESPONSE && kID == g_kMenuID) {
            list lParams = llParseString2List(sStr, ["|"], []);
            //kID = llList2Key(lParams, 0);
            string sButton = llList2String(lParams, 1);
            //integer iPage = llList2Integer(lParams, 2);
            if (g_sCurrentMenu == g_sHudMenu) {   // -- Inside the 'Options' menu, or 'submenu'
                // If we press the 'Back' and we are inside the Options menu, go back to OwnerHUD menu
                if (sButton == UPMENU) {
                    llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);
                    return;
                } else if (sButton == "Reset") {
                    llOwnerSay("Resetting the HUD-Style to the default.");
                    // Reset generic settings:
                    llSetObjectDesc("");
                    // Reset button order:
                    integer idx = llListFindList(g_lButtons, "Hudmenu");
                    if (idx != -1) {
                        string sOrder = "hudmenu";
                        llSetLinkPrimitiveParamsFast(idx, [PRIM_DESC, sOrder]);
                    }
                    llResetScript();
                } else if (sButton == "Cancel") g_sCurrentMenu = g_sHudMenu;
                else g_sCurrentMenu = sButton;
            } else if (g_sCurrentMenu == g_sTextureMenu) {// -- Inside the 'Texture' menu, or 'submenu1'
                if (sButton == UPMENU) g_sCurrentMenu = g_sHudMenu;
                else {
                    DoStyle(sButton);
                    StoreSettings();
                }
            } else if (g_sCurrentMenu == g_sOrderMenu) {
                if (sButton == UPMENU) g_sCurrentMenu = g_sHudMenu;
                else if (sButton == "Reset") {
                    FindButtons();
                    llOwnerSay("Order position reset to default.");
                    DefinePosition();
                    StoreSettings();
                } else if (llSubStringIndex(sButton,":") >= 0) { // Jess's nifty parsing trick for the menus
                    g_iNewPos = llList2Integer(llParseString2List(sButton,[":"],[]),1);
                    DoButtonOrder();
                    StoreSettings();
                } else {
                    OrderButton(sButton);
                    StoreSettings();
                    return;
                }
            }
            DoMenu(g_sCurrentMenu);
        } else if (iNum == CMD_TOUCH) {
            if (sStr == "hide") {
                g_iHidden = !g_iHidden;
                DefinePosition();
                StoreSettings();
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_LINK) llResetScript();
    }
}
