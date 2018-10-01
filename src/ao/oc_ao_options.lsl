
//  Copyright (c) 2008 - 2016 Nandana Singh, Jessenia Mocha, Alexei Maven,
//  Wendy Starfall, littlemousy, Romka Swallowtail, Garvin Twine et al.
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

// -- HUD Message Map
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//Added for the collar auth system:
integer CMD_NOAUTH = 0;
integer CMD_AUTH = 42; //used to send authenticated commands to be executed in the core script
integer CMD_OWNER = 500;
integer OPTIONS = 69; // Hud Options LM

string AOON = "ZHAO_AOON";
string AOOFF = "ZHAO_AOOFF";
string UNLOCK = " UNLOCK";
string LOCK = " LOCK";
string SITANYON = "ZHAO_SITANYWHERE_ON";
string SITANYOFF = "ZHAO_SITANYWHERE_OFF";

string UPMENU = "BACK";
//string g_sParentMenu = "Main";
string g_sHudMenu = "Options";
string g_sOrderMenu = "Order";
//string submenu3 = "Tint";

// Start HUD Options
list g_lAttachPoints = [ATTACH_HUD_TOP_RIGHT,
                    ATTACH_HUD_TOP_CENTER,
                    ATTACH_HUD_TOP_LEFT,
                    ATTACH_HUD_BOTTOM_RIGHT,
                    ATTACH_HUD_BOTTOM,
                    ATTACH_HUD_BOTTOM_LEFT];

float g_fGap = 0.001; // This is the space between buttons
float g_Yoff = 0.002; // space between buttons and screen top/bottom border
float g_Zoff = 0.04; // space between buttons and screen left/right border

list g_lButtons ; // buttons names for Order menu
list g_lPrimOrder = [0,1,2,3,4]; // -- List must always start with '0','1'
// -- 0:Spacer, 1:Root, 2:Power, 3:Sit Anywhere, 4:Menu
// -- Spacer serves to even up the list with actual link numbers

integer g_iLayout = 1;
integer g_iHidden = FALSE;
integer g_iPosition = 69; // Nuff'said =D
integer g_iOldPos;
integer g_iNewPos;

integer g_iAOLock = FALSE;
integer g_iAOPower = TRUE; // -- Power will always be on when scripts are reset as that is the default state of the AO
integer g_iAOSit = FALSE;
vector g_vAOoffcolor = <0.5,0.5,0.5>;
vector g_vAOoncolor = <1,1,1>;
string g_sDarkLock = "389370f3-8ab3-4340-85c5-f3325e40efa9";
string g_sLightLock = "bdb35892-906e-4504-9650-aba8ee907d0d";

list g_lStyles;
string g_sTexture; // current style

list g_lMenuIDs;
integer g_iMenuStride=3;

Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page, string menu)
{
    key id = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page +
 "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);

    integer index = llListFindList(g_lMenuIDs, [rcpt]);
    if (~index) g_lMenuIDs = llListReplaceList(g_lMenuIDs,[rcpt,id,menu],index,index+g_iMenuStride-1);
    else g_lMenuIDs += [rcpt,id,menu];
}

FindButtons() { // collect buttons names & links
    g_lButtons = [" ", "Minimize"] ; // 'Minimize' need for g_sTexture
    g_lPrimOrder = [0, 1];  //  '1' - root prim
    integer i;
    for (i=2; i<llGetNumberOfPrims()+1; ++i) {
        g_lButtons += llGetLinkPrimitiveParams(i, [PRIM_DESC]);
        g_lPrimOrder += i;
    }
}

DoPosition(float yOff, float zOff) {   // Places the buttons
    integer i;
    integer LinkCount=llGetListLength(g_lPrimOrder);
    for (i=2;i<=LinkCount;++i) {
        llSetLinkPrimitiveParamsFast(llList2Integer(g_lPrimOrder,i),[PRIM_POSITION,<0, yOff*(i-1), zOff*(i-1)>]);
    }
}

DoTextures(string style) {

    list lTextures = [
    "[ Dark ]",
    "Minimize~c2f13a8f-fe38-4129-874b-9e79e011cc3a",
    "Power~3ff1f3dd-abcf-413d-9e19-6c1a9dc50209",
    "SitAny~b90745b1-3d4e-4ee3-8a8d-5bf8014c8be3",
    "Menu~cdcd94ca-e432-4ded-9da2-e52e31f70e22",
    "[ Light ]",
    "Minimize~42a5d4ed-98d0-4d75-9b36-d06ab3df225a",
    "Power~0b504c91-efb1-4a69-b833-42b780897b59",
    "SitAny~2dc164d8-9f85-4247-951b-1c9e124e7f00",
    "Menu~83779c3b-5028-4a43-87d4-60b924afaebb"
    ];

    integer i;
    while (i < llGetListLength(lTextures)) {
        string sData = llStringTrim(llList2String(lTextures,i),STRING_TRIM);
        if (sData!="" && llSubStringIndex(sData,"#") != 0) {
            if (llGetSubString(sData,0,0) == "[") {
                sData = llGetSubString(sData,llSubStringIndex(sData,"[")+1,llSubStringIndex(sData,"]")-1);
                sData = llStringTrim(sData,STRING_TRIM);
                if (style=="initialize") {  //reading list to determine style names
                    g_lStyles += sData;
                } else if (sData==style) {  //we just found our section
                    style="processing";
                    g_sTexture = sData;
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
                        llSetLinkPrimitiveParamsFast(link,[PRIM_TEXTURE, ALL_SIDES, sData, <1,1,0>, ZERO_VECTOR, 0]);
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
    if (iPosition != g_iPosition && iPosition != -1) { //do this only when attached to the hud
        vector offset = <0, size.y/2+g_Yoff, size.z/2+g_Zoff>;
        if (iPosition==0||iPosition==1||iPosition==2) offset.z = -offset.z;
        if (iPosition==2||iPosition==5) offset.y = -offset.y;
        llSetPos(offset); // Position the Root Prim on screen
        g_iPosition = iPosition;
    }
    if (g_iHidden) llSetLinkPrimitiveParamsFast(LINK_ALL_OTHERS, [PRIM_POSITION,<1,0,0>]);
    else {
        float fYoff = size.y + g_fGap;
        float fZoff = size.z + g_fGap;
        if (iPosition == 0 || iPosition == 1 || iPosition == 2) fZoff = -fZoff;
        if (iPosition == 1 || iPosition == 2 || iPosition == 4 || iPosition == 5) fYoff = -fYoff;
        if (iPosition == 1 || iPosition == 4) g_iLayout = 0;
        if (g_iLayout) fYoff = 0;
        else fZoff = 0;
        DoPosition(fYoff, fZoff);
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

DetermineColors() {
    g_vAOoncolor = llGetColor(0);
    g_vAOoffcolor.x = g_vAOoncolor.x/2;
    g_vAOoffcolor.y = g_vAOoncolor.y/2;
    g_vAOoffcolor.z = g_vAOoncolor.z/2;
    DoStatus();
}

DoStatus() {
    vector color;
    if (g_iAOPower) color = g_vAOoncolor;
    else color = g_vAOoffcolor;
    llSetLinkPrimitiveParamsFast(llListFindList(g_lButtons,["Power"]),
[PRIM_COLOR, ALL_SIDES, vColor, 1]);
    if (g_iAOSit) color = g_vAOoncolor;
    else color = g_vAOoffcolor;
    llSetLinkPrimitiveParamsFast(llListFindList(g_lButtons,["SitAny"]),
[PRIM_COLOR, ALL_SIDES, vColor, 1]);
}

MainMenu(key id) {
    string text = "\nCustomize your AO!";
    list buttons = ["Horizontal","Vertical","Order"];
    buttons += g_lStyles;
    Dialog(id, text, buttons, [UPMENU], 0, g_sHudMenu);
}

OrderMenu(key id) {
    string text = "This is the order menu, simply select the\n";
    text += "button which you want to re-order.\n\n";
    integer i;
    list buttons;
    for (i=2;i<llGetListLength(g_lPrimOrder);++i) {
        integer pos = llList2Integer(g_lPrimOrder,i);
        buttons += llList2List(g_lButtons,pos,pos);
    }
    Dialog(id, text, buttons, ["Reset",UPMENU], 0, g_sOrderMenu);
}


default {
    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        else if (change & CHANGED_LINK) llResetScript();
        else if (change & CHANGED_COLOR) {
            if (llGetColor(0) != g_vAOoncolor) { //If we change color because of tint, we need to set the new g_vAOoffcolor!
                DetermineColors();
            }
        }
    }

    attach(key attached) {
        if (attached == NULL_KEY) return;
        else if (llGetAttached() <= 30) {
            llOwnerSay("Sorry, this device can only be placed on the HUD.");
            llRequestPermissions(attached, PERMISSION_ATTACH);
            llDetachFromAvatar();
            return;
        } else DefinePosition();
    }

    state_entry() {
        FindButtons(); // collect buttons names
        DefinePosition();
        DoTextures("initialize");
        DoTextures(llList2String(g_lStyles, 0));
        DetermineColors();
        //llSleep(1.0);
        //llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sHudMenu, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == SUBMENU && str == g_sHudMenu) MainMenu(id);
        else if (num == CMD_AUTH && str == "ZHAO_RESET") llResetScript();
        else if (num == OPTIONS) {
            // llOwnerSay("We hit the HUD Options, Options LM: "+str);
            if (str == LOCK && !g_iHidden) {
                // Collapse the HUD and set AOLOCK so clicking the hide button dosnt do anyhting
                g_iHidden = TRUE;
                g_iAOLock = TRUE;
                DefinePosition();
                integer iLink = llListFindList(g_lButtons,["Minimize"]);
                if (g_sTexture == "Dark")
                    llSetLinkPrimitiveParamsFast(iLink,[PRIM_TEXTURE, ALL_SIDES, g_sDarkLock, <1,1,0>, ZERO_VECTOR, 0]);
                else if (g_sTexture == "Light")
                    llSetLinkPrimitiveParamsFast(iLink,[PRIM_TEXTURE, ALL_SIDES, g_sLightLock, <1,1,0>, ZERO_VECTOR, 0]);
            } else if (str == UNLOCK) {
                // Un-Collapse the HUD and set AOLOCK so the button works again
                g_iHidden = FALSE;
                g_iAOLock = FALSE;
                DefinePosition();
                DoTextures(g_sTexture);
            } else if (str == SITANYON) g_iAOSit = TRUE;
            else if (str == SITANYOFF) g_iAOSit = FALSE;
            else if (str == AOOFF) g_iAOPower = FALSE;
            else if (str == AOON) g_iAOPower = TRUE;
            DoStatus();
        } else if (num == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [id]);
            if (index == -1) return;

            list menuparams = llParseString2List(str, ["|"], []);
            id = (key)llList2String(menuparams, 0);
            string response = llList2String(menuparams, 1);
            //integer page = (integer)llList2String(menuparams, 2);
            
            string sMenu = llList2String(g_lMenuIDs,index+1);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs,index-1,index-2+g_iMenuStride);

            if (sMenu == g_sHudMenu) {
                if (response == UPMENU) {
                    //llMessageLinked(LINK_THIS, CMD_OWNER, "ZHAO_MENU", id);
                    llMessageLinked(LINK_THIS, CMD_OWNER, "OCAO_MENU", id);
                    return;
                } else if (response == "Horizontal") {
                    g_iLayout = 0;
                    DefinePosition();
                } else if (response == "Vertical") {
                    g_iLayout = 1;
                    DefinePosition();
                } else if (response == g_sOrderMenu) {
                    OrderMenu(id);
                    return;
                } else if (~llListFindList(g_lStyles,[response])) DoTextures(response);
                MainMenu(id);
            } else if (sMenu == g_sOrderMenu) {
                if (response == UPMENU) MainMenu(id);
                else if (response == "Reset") {
                    FindButtons();
                    llRegionSayTo(id,0,"Order position reset to default.");
                    DefinePosition();
                    OrderMenu(id);
                } else if (llSubStringIndex(response,":") >= 0) {
                    g_iNewPos = llList2Integer(llParseString2List(response,[":"],[]),1);
                    DoButtonOrder();
                    OrderMenu(id);
                } else {
                    list lButtons;
                    string sPrompt;
                    integer iTemp = llListFindList(g_lButtons,[response]);
                    g_iOldPos = llListFindList(g_lPrimOrder, [iTemp]);
                    sPrompt = "\nSelect the new position for swap with "+response+"\n\n";
                    integer i;
                    for (i=2;i<llGetListLength(g_lPrimOrder);++i) {
                        if (g_iOldPos != i) {
                            iTemp = llList2Integer(g_lPrimOrder,i);
                            lButtons +=[llList2String(g_lButtons,iTemp)+":"+(string)i];
                        }
                    }
                    Dialog(id, sPrompt, lButtons, [UPMENU], 0, g_sOrderMenu);
                }
            }
        } else if (num == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [id]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs,index-1,index-2+g_iMenuStride);
        }
        else if (str == "hide" && !g_iAOLock) {
            // This disables the hide button when locked
            g_iHidden = !g_iHidden;
            DefinePosition();
        }
    }
}
