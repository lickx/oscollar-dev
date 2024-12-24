
//  oc_ao.lsl
//
//  Copyright (c) 2008 - 2017 Nandana Singh, Jessenia Mocha, Alexei Maven,
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

string g_sVersion = "2024.12.24";

integer g_iInterfaceChannel = -12587429;
integer g_iHUDChannel = -1812221819;
string g_sPendingCmd;

key g_kWearer = NULL_KEY;
string g_sCard = "Default";
integer g_iCardLine;
key g_kCard = NULL_KEY;
integer g_iReady;

list g_lAnimStates = [ //http://wiki.secondlife.com/wiki/LlSetAnimationOverride
        "Crouching","CrouchWalking","Falling Down","Flying","FlyingSlow",
        "Hovering","Hovering Down","Hovering Up","Jumping","Landing",
        "PreJumping","Running","Standing","Sitting","Sitting on Ground","Standing Up",
        "Striding","Soft Landing","Taking Off","Turning Left","Turning Right","Walking"
        ];

string g_sJson_Anims = "{}";
integer g_iAO_ON;
integer g_iSitAnimOn = FALSE; // http://opensimulator.org/mantis/view.php?id=9042
string g_sSitAnim;
integer g_iSitAnywhereOn;
string g_sSitAnywhereAnim;
string g_sWalkAnim;
integer g_iChangeInterval = 45;
integer g_iLocked;
integer g_iShuffle;
integer g_iStandPause;
float g_fSitOffset;

list g_lMenuIDs;
list g_lAnims2Choose;
list g_lCustomCards;
integer g_iPage;
integer g_iNumberOfPages;

//options

float g_fGap = 0.001; // This is the space between buttons
float g_Yoff = 0.002; // space between buttons and screen top/bottom border
float g_Zoff = 0.06; // space between buttons and screen left/right border

list g_lButtons ; // buttons names for Order menu
list g_lPrimOrder = [0,1,2,3,4]; // -- List must always start with '0','1'
// -- 0:Spacer, 1:Root, 2:Power, 3:Sit Anywhere, 4:Menu, 5:Device
// -- Spacer serves to even up the list with actual link numbers

integer g_iLayout = 1;
integer g_iHidden = FALSE;
integer g_iPosition = 69;
integer g_iOldPos;

vector g_vAOoffcolor = <0.5,0.5,0.5>;
vector g_vAOoncolor = <1,1,1>;

string g_sTexture = "Dark"; // current style

integer g_iRlvChecks;
integer g_iRlvListener;
integer RLV_MAX_CHECKS = 5;
integer g_iRLVOn = FALSE;

integer g_iTimerRlvDetect;
integer g_iTimerChangeStand;
integer g_iTimerDialogTimeout;

string g_sStyle = "Dark";

integer JsonValid(string sTest)
{
    if (llSubStringIndex(JSON_FALSE+JSON_INVALID+JSON_NULL,sTest) >= 0)
        return FALSE;
    return TRUE;
}

// collect buttons names & links
FindButtons()
{
    g_lButtons = [" ", "Minimize"] ; // 'Minimize' need for g_sTexture
    g_lPrimOrder = [0, LINK_ROOT];  //  '1' - root prim
    integer i;
    for (i = 2; i <= llGetNumberOfPrims(); ++i) {
        g_lButtons += [llGetLinkName(i)];
        g_lPrimOrder += i;
    }
}

DoTextures(string style)
{
    list lTextures = [
    "Dark",
    "Minimize~button_dark_opensim",
    "Power~button_dark_io",
    "SitAny~button_dark_groundsit",
    "Menu~button_dark_menu",
    "Device~button_dark_device",
    "Light",
    "Minimize~button_light_opensim",
    "Power~button_light_io",
    "SitAny~button_light_groundsit",
    "Menu~button_light_menu",
    "Device~button_light_device"
    ];
    integer i = llListFindList(lTextures, [style]);
    integer iEnd = i + (llGetListLength(lTextures)/2) - 1;
    while (++i <= iEnd) {
        string sData = llStringTrim(llList2String(lTextures, i), STRING_TRIM);
        list lParams = llParseStringKeepNulls(sData, ["~"], []);
        string sButton = llStringTrim(llList2String(lParams ,0), STRING_TRIM);
        integer link = llListFindList(g_lButtons, [sButton]);
        if (link > 0) {
            sData = llStringTrim(llList2String(lParams, 1), STRING_TRIM);
            if (sData != "" && sData != ",") {
                llSetLinkPrimitiveParamsFast(link, [PRIM_TEXTURE, ALL_SIDES, sData, <1,1,0>, ZERO_VECTOR, 0]);
            }
        }
    }
    g_sStyle = style;
}

DefinePosition()
{
    integer iPosition = llGetAttached();
    vector vSize = llGetScale();
//  Allows manual repositioning, without resetting it, if needed
    if (iPosition != g_iPosition && iPosition > 30) { //do this only when attached to the hud
        vector vOffset = <0, vSize.y/2+g_Yoff, vSize.z/2+g_Zoff>;
        if (iPosition == ATTACH_HUD_TOP_RIGHT || iPosition == ATTACH_HUD_TOP_CENTER || iPosition == ATTACH_HUD_TOP_LEFT) vOffset.z = -vOffset.z;
        if (iPosition == ATTACH_HUD_TOP_LEFT || iPosition == ATTACH_HUD_BOTTOM_LEFT) vOffset.y = -vOffset.y;
        llSetPos(vOffset); // Position the Root Prim on screen
        g_iPosition = iPosition;
    }
    if (g_iHidden) llSetLinkPrimitiveParamsFast(LINK_ALL_OTHERS, [PRIM_POSITION,<1,0,0>]);
    else {
        float fYoff = vSize.y + g_fGap;
        float fZoff = vSize.z + g_fGap;
        if (iPosition == ATTACH_HUD_TOP_LEFT || iPosition == ATTACH_HUD_TOP_CENTER || iPosition == ATTACH_HUD_TOP_RIGHT)
            fZoff = -fZoff;
        if (iPosition == ATTACH_HUD_TOP_CENTER || iPosition == ATTACH_HUD_TOP_LEFT || iPosition == ATTACH_HUD_BOTTOM || iPosition == ATTACH_HUD_BOTTOM_LEFT)
            fYoff = -fYoff;
        if (iPosition == ATTACH_HUD_TOP_CENTER || iPosition == ATTACH_HUD_BOTTOM) g_iLayout = 0;
        if (g_iLayout) fYoff = 0;
        else fZoff = 0;
        integer i;
        integer LinkCount=llGetListLength(g_lPrimOrder);
        for (i = 2; i < LinkCount; ++i) {
            llSetLinkPrimitiveParamsFast(llList2Integer(g_lPrimOrder, i),[PRIM_POSITION, <0,fYoff*(i-1),fZoff*(i-1)>]);
        }
    }
}

// -- Set the button order and reset display
DoButtonOrder(integer iNewPos)
{
    integer iOldPos = llList2Integer(g_lPrimOrder, g_iOldPos);
    iNewPos = llList2Integer(g_lPrimOrder, iNewPos);
    integer i = 2;
    list lTemp = [0, 1];
    for(i = 2; i < llGetListLength(g_lPrimOrder); ++i) {
        integer iTempPos = llList2Integer(g_lPrimOrder, i);
        if (iTempPos == iOldPos) lTemp += [iNewPos];
        else if (iTempPos == iNewPos) lTemp += [iOldPos];
        else lTemp += [iTempPos];
    }
    g_lPrimOrder = lTemp;
    g_iOldPos = -1;
    DefinePosition();
}

DetermineColors()
{
    g_vAOoncolor = llGetColor(0);
    g_vAOoffcolor = g_vAOoncolor/2;
    DoStatus();
}

DoStatus()
{
    vector vColor = g_vAOoffcolor;
    if (g_iAO_ON) vColor = g_vAOoncolor;
    llSetLinkPrimitiveParamsFast(llListFindList(g_lButtons,["Power"]),
        [PRIM_COLOR, ALL_SIDES, vColor, 1]);
    if (g_iSitAnywhereOn) vColor = g_vAOoncolor;
    else vColor = g_vAOoffcolor;
    llSetLinkPrimitiveParamsFast(llListFindList(g_lButtons,["SitAny"]),
        [PRIM_COLOR, ALL_SIDES, vColor, 1]);
}

//ao functions

SetAnimOverride()
{
    if (llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS) {
        llResetAnimationOverride("ALL");
        integer i = llGetListLength(g_lAnimStates); // 22
        string sAnim;
        string sAnimState;
        do {
            sAnimState = llList2String(g_lAnimStates, i);
            if (llSubStringIndex(g_sJson_Anims, sAnimState) >= 0) {
                sAnim = llJsonGetValue(g_sJson_Anims, [sAnimState]);
                if (JsonValid(sAnim)) {
                    if (sAnimState == "Walking" && g_sWalkAnim != "")
                        sAnim = g_sWalkAnim;
                    else if (sAnimState == "Sitting" && g_iSitAnimOn == FALSE) jump next;
                    else if (sAnimState == "Sitting" && g_sSitAnim != "" && g_iSitAnimOn)
                        sAnim = g_sSitAnim;
                    else if (sAnimState == "Sitting on Ground" && g_sSitAnywhereAnim != "")
                        sAnim = g_sSitAnywhereAnim;
                    else if (sAnimState == "Standing")
                        sAnim = llList2String(llParseString2List(sAnim, ["|"], []), 0);
                    if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION)
                        llSetAnimationOverride(sAnimState, sAnim);
                    else llOwnerSay(sAnim+" could not be found.");
                    @next;
                }
            }
        } while (i--);

        if (g_iChangeInterval) g_iTimerChangeStand = llGetUnixTime() + g_iChangeInterval;
        else g_iTimerChangeStand = 0;

        if (g_iStandPause == FALSE) llRegionSayTo(g_kWearer, g_iHUDChannel, (string)g_kWearer+":antislide off ao");
        //llOwnerSay("AO ready ("+(string)llGetFreeMemory()+" bytes free memory)");
    }
}

SwitchStand()
{
    if (g_iStandPause) return;
    if (llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS) {
        string sCurAnim = llGetAnimationOverride("Standing");
        list lAnims = llParseString2List(llJsonGetValue(g_sJson_Anims, ["Standing"]), ["|"], []);
        integer index;
        if (g_iShuffle) index = (integer)llFrand(llGetListLength(lAnims));
        else {
            index = llListFindList(lAnims, [sCurAnim]);
            if (index == llGetListLength(lAnims)-1) index = 0;
            else index += 1;
        }
        if (g_iReady) llSetAnimationOverride("Standing",llList2String(lAnims,index));
    }
}

ToggleSitAnywhere()
{
    if (g_iAO_ON == FALSE) llOwnerSay("SitAnywhere is not possible while the AO is turned off.");
    else if (g_iStandPause)
        llOwnerSay("SitAnywhere is not possible while you are in a collar pose.");
    else {
        if (g_iSitAnywhereOn) {
            if (g_iChangeInterval) g_iTimerChangeStand = llGetUnixTime() + g_iChangeInterval;
            SwitchStand();
            if (g_iRLVOn) llOwnerSay("@adjustheight:1;0;0.0=force");
        } else {
            g_iTimerChangeStand = 0;
            llSetAnimationOverride("Standing",g_sSitAnywhereAnim);
            if (g_iRLVOn) AdjustSitOffset();
        }
        g_iSitAnywhereOn = !g_iSitAnywhereOn;
        DoStatus();
    }
}

AdjustSitOffset()
{
    llOwnerSay("@adjustheight:1;0;"+(string)g_fSitOffset+"=force");
}

Notify(key kID, string sStr, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer) llOwnerSay(sStr);
    else {
        llRegionSayTo(kID, 0, sStr);
        if (iAlsoNotifyWearer) llOwnerSay(sStr);
    }
}

//menus

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, string sName)
{
    integer iChannel = llRound(llFrand(10000000)) + 100000;
    while (llListFindList(g_lMenuIDs, [iChannel]) != -1)
        iChannel = llRound(llFrand(10000000)) + 100000;
    integer iListener = llListen(iChannel, "", kID, "");
    integer iTime = llGetUnixTime() + 180;
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, iChannel, iListener, iTime, sName], iIndex, iIndex+4);
    else g_lMenuIDs += [kID, iChannel, iListener, iTime, sName];
    g_iTimerDialogTimeout = llGetUnixTime() + 20;
    llDialog(kID, sPrompt, SortButtons(lChoices,lUtilityButtons), iChannel);
}

list SortButtons(list lButtons, list lStaticButtons)
{
    list lSpacers;
    list lAllButtons = lButtons + lStaticButtons;
    //cutting off too many buttons, no multi page menus as of now
    while (llGetListLength(lAllButtons) > 12) {
        lButtons = llDeleteSubList(lButtons, 0, 0);
        lAllButtons = lButtons + lStaticButtons;
    }
    while (llGetListLength(lAllButtons) % 3 != 0 && llGetListLength(lAllButtons) < 12) {
        lSpacers += ["-"];
        lAllButtons = lButtons + lSpacers + lStaticButtons;
    }
    integer i = llListFindList(lAllButtons, ["BACK"]);
    if (i != -1) lAllButtons = llDeleteSubList(lAllButtons, i, i);
    list lOut = llList2List(lAllButtons, 9, 11);
    lOut += llList2List(lAllButtons, 6, 8);
    lOut += llList2List(lAllButtons, 3, 5);
    lOut += llList2List(lAllButtons, 0, 2);
    if (i != -1) lOut = llListInsertList(lOut, ["BACK"], 2);
    return lOut;
}

MenuAO(key kID)
{
    string sPrompt = "\n𝐎 𝐒 𝐂 𝐨 𝐥 𝐥 𝐚 𝐫  AO\t"+g_sVersion;
    list lButtons = ["LOCK"];
    if (g_iLocked) lButtons = ["UNLOCK"];
    if (kID == g_kWearer) lButtons += ["Collar Menu"];
    else lButtons += ["-"];
    lButtons += ["Load","Sits","Ground Sits","Walks"];
    if (g_iSitAnimOn) lButtons += ["Sits ☑"];
    else lButtons += ["Sits ☐"];
    if (g_iShuffle) lButtons += ["Shuffle ☑"];
    else lButtons += ["Shuffle ☐"];
    lButtons += ["Stand Time","Next Stand"];
    if (kID == g_kWearer) lButtons += ["HUD Style"];
    Dialog(kID, sPrompt, lButtons, ["Close"], "AO");
}

MenuLoad(key kID, integer iPage)
{
    if (iPage == FALSE) g_iPage = 0;
    string sPrompt = "\nLoad an animation set!";
    list lButtons;
    g_lCustomCards = [];
    integer iEnd = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer iCountCustomCards;
    string sNotecardName;
    integer i = 0;
    while (i < iEnd) {
        sNotecardName = llGetInventoryName(INVENTORY_NOTECARD, i++);
        if (llSubStringIndex(sNotecardName,".") != 0 && sNotecardName != "OsCollar Help" &&
            sNotecardName != "OsCollar License" && sNotecardName != "") {
            if (llSubStringIndex(sNotecardName,"SET") == 0)
                g_lCustomCards += [sNotecardName,"Wildcard "+(string)(++iCountCustomCards)];// + g_lCustomCards;
            else if(llStringLength(sNotecardName) < 24) lButtons += [sNotecardName];
            else llOwnerSay(sNotecardName+"'s name is too long to be displayed in menus and cannot be used.");
        }
    }
    i = 1;
    while (i <= 2*iCountCustomCards) {
        lButtons += llList2List(g_lCustomCards, i, i);
        i += 2;
    }
    list lStaticButtons = ["BACK"];
    if (llGetListLength(lButtons) > 11) {
        lStaticButtons = ["◄","►","BACK"];
        g_iNumberOfPages = llGetListLength(lButtons) / 9;
        lButtons = llList2List(lButtons, iPage*9, iPage*9+8);
    }
    if (lButtons == []) llOwnerSay("There aren't any animation sets installed!");
    Dialog(kID, sPrompt, lButtons, lStaticButtons,"Load");
}

MenuInterval(key kID)
{
    string sInterval = "won't change automatically.";
    if (g_iChangeInterval) sInterval = "change every "+(string)g_iChangeInterval+" seconds.";
    Dialog(kID, "\nStands " +sInterval, ["Never","20","30","45","60","90","120","180"], ["BACK"],"Interval");
}

MenuChooseAnim(key kID, string sAnimState, integer iUpDown)
{
    string sAnim = g_sSitAnywhereAnim;
    if (sAnimState == "Walking") sAnim = g_sWalkAnim;
    else if (sAnimState == "Sitting") sAnim = g_sSitAnim;
    string sPrompt = "\n"+sAnimState+": \""+sAnim+"\"\n";
    if (sAnimState == "Sitting on Ground") {
        if (llGetAnimation(g_kWearer) == "Standing" && g_iSitAnywhereOn == FALSE) {
            ToggleSitAnywhere();
            DoStatus();
        }
        sPrompt += "Offset: "+llGetSubString((string)g_fSitOffset, 0, 4) + "\n";
    }
    g_lAnims2Choose = [] + llListSort(llParseString2List(llJsonGetValue(g_sJson_Anims, [sAnimState]), ["|"], []), 1, TRUE);
    list lButtons;
    integer iEnd = llGetListLength(g_lAnims2Choose);
    integer i = 0;
    while (++i <= iEnd) {
        lButtons += [(string)i];
        sPrompt += "\n"+(string)i+": "+llList2String(g_lAnims2Choose, i-1);
    }
    if (iUpDown) Dialog(kID, sPrompt, lButtons, ["▲", "▼", "BACK"], sAnimState);
    else Dialog(kID, sPrompt, lButtons, ["BACK"], sAnimState);
}

MenuOptions(key kID)
{
    Dialog(kID,"\nCustomize your AO!",["Horizontal","Vertical","Order","Dark","Light"],["BACK"], "options");
}

OrderMenu(key kID)
{
    string sPrompt = "\nWhich button do you want to re-order?";
    integer i;
    list lButtons;
    integer iPos;
    for (i = 2; i < llGetListLength(g_lPrimOrder); ++i) {
        iPos = llList2Integer(g_lPrimOrder, i);
        lButtons += llList2List(g_lButtons, iPos, iPos);
    }
    Dialog(kID, sPrompt, lButtons, ["Reset","BACK"], "ordermenu");
}

//command handling

TranslateCollarCMD(string sCommand, key kID)
{
    if (llSubStringIndex(sCommand,"ZHAO_") == 0) {
        sCommand = llGetSubString(sCommand,5,-1);
        if (llSubStringIndex(sCommand, "load") == -1)
            sCommand = llToLower(sCommand);
    } else return;
    if (llSubStringIndex(sCommand,"stand") == 0) {
        if (llSubStringIndex(sCommand, "off") != -1) {
            g_iStandPause = TRUE;
            if (llGetAnimationOverride("Standing"))
                llResetAnimationOverride("Standing");
            llResetAnimationOverride("Turning Left");
            llResetAnimationOverride("Turning Right");
            if (g_iSitAnywhereOn) {
                g_iSitAnywhereOn = FALSE;
                DoStatus();
            }
        } else if (llSubStringIndex(sCommand,"on") != -1) {
            if (g_iAO_ON) SetAnimOverride();
            g_iStandPause = FALSE;
        }
    } else if (llSubStringIndex(sCommand,"menu") != -1) {
            if (g_iReady) MenuAO(kID);
            else {
                Notify(kID, "Please load an animation set first.", TRUE);
                MenuLoad(kID, 0);
            }
    } else if (llSubStringIndex(sCommand,"ao") == 0)
        Command(kID, llGetSubString(sCommand, 2, -1));
}

Command(key kID, string sCommand)
{
    list lParams = llParseString2List(sCommand, [" "], []);
    sCommand = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    if (g_iReady == FALSE) {
        Notify(kID,"Please load an animation set first.", TRUE);
        MenuLoad(kID,0);
        return;
    } else if (sCommand == "on") {
        if ((llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS) == 0) llRequestPermissions(g_kWearer, PERMISSION_OVERRIDE_ANIMATIONS);
        SetAnimOverride();
        g_iAO_ON = TRUE;
        if (g_iChangeInterval) g_iTimerChangeStand = llGetUnixTime() + g_iChangeInterval;
        DoStatus();
    } else if (sCommand == "off") {
        if ((llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS) == 0) llRequestPermissions(g_kWearer, PERMISSION_OVERRIDE_ANIMATIONS);
        llResetAnimationOverride("ALL");
        g_iAO_ON = FALSE;
        g_iTimerChangeStand = 0;
        DoStatus();
    } else if (sCommand == "unlock") {
        g_iLocked = FALSE;
        llOwnerSay("@detach=y");
        llPlaySound("sound_unlock", 1.0);
        Notify(kID,"The AO has been unlocked.", TRUE);
    } else if (sCommand == "lock") {
        g_iLocked = TRUE;
        llOwnerSay("@detach=n");
        llPlaySound("sound_lock", 1.0);
        Notify(kID,"The AO has been locked.", TRUE);
    } else if (sCommand == "menu") MenuAO(kID);
    else if (sCommand == "load") {
        if (llGetInventoryType(sValue) == INVENTORY_NOTECARD) {
            g_sCard = sValue;
            g_iCardLine = 0;
            g_sJson_Anims = "{}";
            Notify(kID,"Loading animation set \""+g_sCard+"\".", TRUE);
            g_kCard = llGetNotecardLine(g_sCard, g_iCardLine);
        } else if (sValue == "") MenuLoad(kID, 0);
        else if (kID == llGetOwner() && g_sCard != "Default" && llGetInventoryType("Default") == INVENTORY_NOTECARD) {
            // Card does not exist, fall back to default if not already loaded
            g_sCard = "Default";
            g_iCardLine = 0;
            g_sJson_Anims = "{}";
            Notify(kID,"Loading animation set \""+g_sCard+"\".", TRUE);
            g_kCard = llGetNotecardLine(g_sCard, g_iCardLine);
        }
    }
}

StartUpdate(key kID)
{
    integer iPin = (integer)llFrand(99999998.0) + 1;
    llSetRemoteScriptAccessPin(iPin);
    llRegionSayTo(kID, -7483220, "ready|" + (string)iPin);
}

default
{
    state_entry()
    {
        if (llGetInventoryType("oc_installer_sys") == INVENTORY_SCRIPT) return;
        g_kWearer = llGetOwner();
        g_iInterfaceChannel = -llAbs((integer)("0x" + llGetSubString(g_kWearer,30,-1)));
        llListen(g_iInterfaceChannel, "", "", "");
        g_iHUDChannel = -llAbs((integer)("0x"+llGetSubString((string)llGetOwner(),-7,-1)));
        FindButtons();
        DefinePosition();
        DoTextures(g_sStyle);
        DetermineColors();
        if (llGetInventoryType(g_sCard) == INVENTORY_NOTECARD) {
            g_iCardLine = 0;
            g_sJson_Anims = "{}";
            g_kCard = llGetNotecardLine(g_sCard, g_iCardLine);
        } else MenuLoad(g_kWearer,0);
        g_iTimerRlvDetect = llGetUnixTime() + 120;
        g_iRLVOn = FALSE;
        g_iTimerRlvDetect = llGetUnixTime() + 120;
        g_iRlvListener = llListen(519274, "", (string)g_kWearer, "");
        g_iRlvChecks = 0;
        llOwnerSay("@versionnew=519274");
        llSetTimerEvent(5.0);
    }

    on_rez(integer iStart)
    {
        if (g_kWearer != llGetOwner()) llResetScript();
        g_iReady = FALSE;
        if (llGetAttached()) {
            if (g_iLocked) llOwnerSay("@detach=n");
            llRequestPermissions(g_kWearer, PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TAKE_CONTROLS);
            g_iRLVOn = FALSE;
            g_iRlvListener = llListen(519274, "", (string)g_kWearer, "");
            g_iRlvChecks = 0;
            llOwnerSay("@versionnew=519274");
        }
    }

    attach(key kID)
    {
        if (kID == NULL_KEY) llResetAnimationOverride("ALL");
        else if (llGetAttached() <= 30) {
            llOwnerSay("Sorry, this device can only be attached to the HUD.");
            llRequestPermissions(kID, PERMISSION_ATTACH);
            llDetachFromAvatar();
        } else DefinePosition();
    }

    touch_end(integer total_number)
    {
        if(llGetAttached()) {
            if (g_iReady == FALSE) {
                MenuLoad(g_kWearer, 0);
                llOwnerSay("Please load an animation set first.");
                return;
            }
            string sButton = llGetLinkName(llDetectedLinkNumber(0));
            string sMessage = "";
            if (sButton == "Menu")
                MenuAO(g_kWearer);
            else if (sButton == "SitAny") {
                if (g_sSitAnywhereAnim != "") ToggleSitAnywhere();
            } else if (llSubStringIndex(llToLower(sButton), "ao") >= 0) {
                g_iHidden = !g_iHidden;
                DefinePosition();
            } else if (sButton == "Power") {
                if (g_iAO_ON) Command(g_kWearer, "off");
                else if (g_iReady) Command(g_kWearer, "on");
            } else if (sButton == "Device") {
                llRegionSayTo(llGetOwner(), g_iHUDChannel, "menu");
            }
        } else if (llDetectedKey(0) == g_kWearer) MenuAO(g_kWearer);
    }

    listen(integer iChannel, string sName, key kID, string sMessage) {
        if (iChannel == g_iInterfaceChannel) {
            if (llGetOwnerKey(kID) != g_kWearer) return;
            if (sMessage == "-.. --- / .- ---") {
                StartUpdate(kID);
                return;
            } else if (!llGetAttached() && sMessage == "AO set installation") {
                sMessage = "";
                integer i = llGetInventoryNumber(INVENTORY_ANIMATION);
                while(i) {
                    sMessage += llGetInventoryName(INVENTORY_ANIMATION, --i);
                    if (llStringLength(sMessage) > 960) {
                        llRegionSayTo(kID, iChannel, sMessage);
                        sMessage = "";
                    }
                }
                llRegionSayTo(kID,iChannel,sMessage);
                llRegionSayTo(kID,iChannel,"@END");
                return;
            } //"CollarCommmand|499|ZHAO_STANDON" or "CollarCommmand|iAuth|ZHAO_MENU|commanderID"
            list lParams = llParseString2List(sMessage, ["|"], []);
            if (llList2String(lParams, 0) == "CollarCommand") {
                if (llList2Integer(lParams, 1) == 502)
                    Notify(llList2Key(lParams, 3), "Access denied!", FALSE);
                else
                    TranslateCollarCMD(llList2String(lParams, 2), llList2Key(lParams, 3));
            }
        } else if (iChannel == 519274) {
            g_iTimerRlvDetect = 0;
            g_iRLVOn = TRUE;
            llListenRemove(g_iRlvListener);
        } else if (llListFindList(g_lMenuIDs,[kID, iChannel]) != -1) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            string sMenuType = llList2String(g_lMenuIDs, iMenuIndex+4);
            llListenRemove(llList2Integer(g_lMenuIDs, iMenuIndex+2));
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex, iMenuIndex+4);
            if (llGetListLength(g_lMenuIDs) == 0 && g_iTimerDialogTimeout) g_iTimerDialogTimeout = 0;
            if (sMenuType == "AO") {
                if (sMessage == "Close") return;
                else if (sMessage == "-") MenuAO(kID);
                else if (sMessage == "Collar Menu") llRegionSayTo(g_kWearer, g_iHUDChannel, (string)g_kWearer+":menu");
                else if (llSubStringIndex(sMessage,"LOCK") != -1) {
                    Command(kID,llToLower(sMessage));
                    MenuAO(kID);
                } else if (sMessage == "HUD Style") MenuOptions(kID);
                else if (sMessage == "Load") MenuLoad(kID, 0);
                else if (sMessage == "Sits") MenuChooseAnim(kID, "Sitting", FALSE);
                else if (sMessage == "Walks") MenuChooseAnim(kID, "Walking", FALSE);
                else if (sMessage == "Ground Sits") MenuChooseAnim(kID, "Sitting on Ground", TRUE);
                else if (llSubStringIndex(sMessage,"Sits") == 0) {
                    if (llSubStringIndex(sMessage,"☑") >= 0) {
                        g_iSitAnimOn = FALSE;
                        llResetAnimationOverride("Sitting");
                    } else if (g_sSitAnim) {
                        g_iSitAnimOn = TRUE;
                        if (g_iAO_ON) llSetAnimationOverride("Sitting", g_sSitAnim);
                    } else Notify(kID,"Sorry, the currently loaded animation set doesn't have any sits.",TRUE);
                    MenuAO(kID);
                } else if (sMessage == "Stand Time") MenuInterval(kID);
                else if (sMessage == "Next Stand") {
                    if (g_iAO_ON) SwitchStand();
                    MenuAO(kID);
                } else if (llSubStringIndex(sMessage,"Shuffle") == 0) {
                    if (llSubStringIndex(sMessage,"☑") >= 0) g_iShuffle = FALSE;
                    else g_iShuffle = TRUE;
                    MenuAO(kID);
                }
            } else if (sMenuType == "Load") {
                integer index = llListFindList(g_lCustomCards, [sMessage]);
                if (index != -1) sMessage = llList2String(g_lCustomCards, index-1);
                if (llGetInventoryType(sMessage) == INVENTORY_NOTECARD) {
                    g_sCard = sMessage;
                    g_iCardLine = 0;
                    g_sJson_Anims = "{}";
                    g_kCard = llGetNotecardLine(g_sCard, g_iCardLine);
                    return;
                } else if (g_iReady && sMessage == "BACK") {
                    MenuAO(kID);
                    return;
                } else if (sMessage == "►") {
                    if (++g_iPage > g_iNumberOfPages) g_iPage = 0;
                } else if (sMessage == "◄") {
                    if (--g_iPage < 0) g_iPage = g_iNumberOfPages;
                } else if (g_iReady == FALSE) llOwnerSay("Please load an animation set first.");
                else llOwnerSay("Could not find animation set: "+sMessage);
                MenuLoad(kID,g_iPage);
            } else if (sMenuType == "Interval") {
                if (sMessage == "BACK") {
                    MenuAO(kID);
                    return;
                } else if (sMessage == "Never") {
                    g_iChangeInterval = FALSE;
                    g_iTimerChangeStand = 0;
                } else if ((integer)sMessage >= 20) {
                    g_iChangeInterval = (integer)sMessage;
                    if (g_iAO_ON && g_iSitAnywhereOn == FALSE) {
                        g_iTimerChangeStand = llGetUnixTime() + g_iChangeInterval;
                    }
                }
                MenuInterval(kID);
            } else if (llListFindList(["Walking","Sitting on Ground","Sitting"], [sMenuType]) != -1) {
                if (sMessage == "BACK") {
                    g_lAnims2Choose = [];
                    MenuAO(kID);
                } else if (sMessage == "▲" || sMessage == "▼") {
                    if (sMessage == "▲") g_fSitOffset += 0.025;
                    else g_fSitOffset -= 0.025;
                    AdjustSitOffset();
                    MenuChooseAnim(kID, sMenuType, TRUE);
                } else if (sMessage == "-") {
                    if (sMenuType == "Sitting on Ground") MenuChooseAnim(kID, sMenuType, TRUE);
                    else MenuChooseAnim(kID, sMenuType, FALSE);
                } else {
                    sMessage = llList2String(g_lAnims2Choose, ((integer)sMessage)-1);
                    g_lAnims2Choose = [];
                    if (llGetInventoryType(sMessage) == INVENTORY_ANIMATION) {
                        if (sMenuType == "Sitting") g_sSitAnim = sMessage;
                        else if (sMenuType == "Sitting on Ground") g_sSitAnywhereAnim = sMessage;
                        else if (sMenuType == "Walking") g_sWalkAnim = sMessage;
                        if (g_iAO_ON && (sMenuType != "Sitting" || g_iSitAnimOn))
                            llSetAnimationOverride(sMenuType,sMessage);
                    } else llOwnerSay("No "+sMenuType+" animation set.");
                    if (sMenuType == "Sitting on Ground") MenuChooseAnim(kID, sMenuType, TRUE);
                    else MenuChooseAnim(kID, sMenuType, FALSE);
                }
            } else if (sMenuType == "options") {
                if (sMessage == "BACK") {
                    MenuAO(kID);
                    return;
                } else if (sMessage == "Horizontal") {
                    g_iLayout = 0;
                    DefinePosition();
                } else if (sMessage == "Vertical") {
                    g_iLayout = 1;
                    DefinePosition();
                } else if (sMessage == "Order") {
                    OrderMenu(kID);
                    return;
                } else DoTextures(sMessage);
                MenuOptions(kID);
            } else if (sMenuType == "ordermenu") {
                if (sMessage == "BACK") MenuOptions(kID);
                else if (sMessage == "-") OrderMenu(kID);
                else if (sMessage == "Reset") {
                    FindButtons();
                    llOwnerSay("Order position reset to default.");
                    DefinePosition();
                    OrderMenu(kID);
                } else if (llSubStringIndex(sMessage, ":") >= 0) {
                    DoButtonOrder(llList2Integer(llParseString2List(sMessage, [":"], []), 1));
                    OrderMenu(kID);
                } else {
                    list lButtons;
                    string sPrompt;
                    integer iTemp = llListFindList(g_lButtons, [sMessage]);
                    g_iOldPos = llListFindList(g_lPrimOrder, [iTemp]);
                    sPrompt = "\nWhich slot do you want to swap for the "+sMessage+" button.";
                    integer i;
                    for (i = 2; i < llGetListLength(g_lPrimOrder); ++i) {
                        if (g_iOldPos != i) {
                            iTemp = llList2Integer(g_lPrimOrder, i);
                            lButtons += [llList2String(g_lButtons, iTemp)+":"+(string)i];
                        }
                    }
                    Dialog(kID, sPrompt, lButtons, ["BACK"],"ordermenu");
                }
            }
        }
    }

    timer()
    {
        integer iTimestamp = llGetUnixTime();

        if (g_iTimerChangeStand && iTimestamp > g_iTimerChangeStand) {
            if (g_iAO_ON && g_iSitAnywhereOn == FALSE && llGetAnimation(g_kWearer) == "Standing") SwitchStand();
            if (g_iChangeInterval)
                g_iTimerChangeStand = iTimestamp + g_iChangeInterval;
        }
        if (g_iTimerDialogTimeout && iTimestamp > g_iTimerDialogTimeout) {
            integer n = llGetListLength(g_lMenuIDs) - 5;
            integer iNow = llGetUnixTime();
            for (n; n >= 0; n = n-5) {
                integer iDieTime = llList2Integer(g_lMenuIDs, n+3);
                if (iNow > iDieTime) {
                    llListenRemove(llList2Integer(g_lMenuIDs, n+2));
                    g_lMenuIDs = llDeleteSubList(g_lMenuIDs, n, n+4);
                }
            }
            if (llGetListLength(g_lMenuIDs) == 0) g_iTimerDialogTimeout = 0;
        }
        if (g_iTimerRlvDetect) {
            if (g_iRlvChecks++ < RLV_MAX_CHECKS)
                llOwnerSay("@versionnew=519274");
            else {
                g_iTimerRlvDetect = 0;
                llListenRemove(g_iRlvListener);
                g_iRlvChecks = 0;
                g_iRLVOn = FALSE;
            }
        }
    }

    dataserver(key kRequest, string sData)
    {
        if (kRequest == g_kCard) {
            if (sData != EOF) {
                if (llGetSubString(sData,0,0) != "[") jump next;
                string sAnimationState = llStringTrim(llGetSubString(sData, 1, llSubStringIndex(sData, "]") - 1), STRING_TRIM);
                if (llListFindList(g_lAnimStates, [sAnimationState]) == -1) jump next;
                if (llStringLength(sData)-1 > llSubStringIndex(sData, "]")) {
                    sData = llGetSubString(sData, llSubStringIndex(sData, "]")+1, -1);
                    list lTemp = llParseString2List(sData, ["|",","], []);
                    integer i = llGetListLength(lTemp);
                    while(i--) {
                        if (llGetInventoryType(llList2String(lTemp, i)) != INVENTORY_ANIMATION)
                            lTemp = llDeleteSubList(lTemp, i, i);
                    }
                    if (sAnimationState == "Sitting on Ground")
                        g_sSitAnywhereAnim = llList2String(lTemp, 0);
                    else if (sAnimationState == "Sitting") {
                        g_sSitAnim = llList2String(lTemp, 0);
                        if (g_sSitAnim) g_iSitAnimOn = TRUE;
                        else g_iSitAnimOn = FALSE;
                    } else if (sAnimationState == "Walking")
                        g_sWalkAnim = llList2String(lTemp, 0);
                    else if (sAnimationState != "Standing") lTemp = llList2List(lTemp, 0, 0);
                    if (lTemp != []) g_sJson_Anims = llJsonSetValue(g_sJson_Anims, [sAnimationState], llDumpList2String(lTemp,"|"));
                }
                @next;
                g_kCard = llGetNotecardLine(g_sCard, ++g_iCardLine);
            } else {
                g_iCardLine = 0;
                g_kCard = NULL_KEY;
                g_iSitAnywhereOn = FALSE;
                integer index = llListFindList(g_lCustomCards, [g_sCard]);
                if (~index) g_sCard = llList2String(g_lCustomCards, index+1)+" ("+g_sCard+")";
                g_lCustomCards = [];
                if (g_sJson_Anims == "{}") {
                    llOwnerSay("\""+g_sCard+"\" is an invalid animation set and can't play.");
                    g_iAO_ON = FALSE;
                } else {
                    llOwnerSay("The \""+g_sCard+"\" animation set was loaded successfully.");
                    g_iAO_ON = TRUE;
                }
                DoStatus();
                if (llGetAttached()) llRequestPermissions(g_kWearer,PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TAKE_CONTROLS);
            }
        }
    }

    run_time_permissions(integer iFlag)
    {
        if (iFlag & PERMISSION_OVERRIDE_ANIMATIONS) {
            if (g_sJson_Anims != "{}") g_iReady = TRUE;
            else g_iReady =  FALSE;
            if (g_iAO_ON) SetAnimOverride();
            else llResetAnimationOverride("ALL");
        }
        if (iFlag & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_FWD, TRUE, TRUE);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_COLOR) {
            if (llGetColor(0) != g_vAOoncolor) DetermineColors();
        } else if (iChange & CHANGED_LINK) llResetScript();
    }
}
