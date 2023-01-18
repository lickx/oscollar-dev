
//  oc_oh_sys.lsl
//
//  Copyright (c) 2014 - 2017 Nandana Singh, Jessenia Mocha, Alexei Maven,
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

//merged HUD-menu, HUD-leash and HUD-rezzer into here June 2015 Otto (garvin.twine)

string g_sVersion = "2023.01.18";

list g_lPartners;
list g_lNewPartnerIDs;
list g_lPartnersInSim;
string g_sActivePartnerID = "ALL"; //either an UUID or "ALL"

//  list of hud channel handles we are listening for, for building lists
list g_lListeners;

string g_sMainMenu = "Main";

integer g_iListener;
integer g_iCmdListener;
integer g_iChannel = 7;

key g_kUpdater = NULL_KEY;
integer g_iUpdateChan = -7483210;

integer g_iHidden;
integer g_iPicturePrim;
string g_sPictureID;
string g_sTextureALL = "button_dark_partners";

string g_sCurrentTheme;

//  MESSAGE MAP
integer CMD_TOUCH            = 100;

integer MENUNAME_REQUEST     = 3000;
integer MENUNAME_RESPONSE    = 3001;
integer SUBMENU              = 3002;
integer ACC_CMD              = 7000;
integer DIALOG               = -9000;
integer DIALOG_RESPONSE      = -9001;
integer DIALOG_TIMEOUT       = -9002;
integer CMD_OWNER_HUD        = 10000;
integer UPDATE = 5555;
string UPMENU          = "BACK";
string g_sListPartners  = "List";
string g_sRemovePartner = "Remove";
string g_sAllPartners = "ALL";
string g_sAddPartners = "Add";

//list g_lMainMenuButtons = [" ◄ ",g_sAllPartners," ► ",g_sAddPartners, g_sListPartners, g_sRemovePartner, "Collar Menu", "Rez"];
list g_lMainMenuButtons = [" ◄ ", "ALL", " ► ", "Add", "List", "Remove", "Collar Menu", "Rez"];
list g_lMenus = ["HUD Style"];
key    g_kMenuID = NULL_KEY;
string g_sMenuType;

key    g_kRemovedPartnerID = NULL_KEY;
key    g_kOwner = NULL_KEY;

string  g_sRezObject;

integer g_iAddPartnerTimer;

string NameURI(string sID)
{
    if (osIsUUID(sID))
        return "secondlife:///app/agent/"+sID+"/about";
    else return sID; //this way we can use the function also for "ALL" and dont need a special case for that everytime
}

integer PersonalChannel(string sID, integer iOffset)
{
    integer iChan = -llAbs((integer)("0x"+llGetSubString(sID,-7,-1)) + iOffset);
    return iChan;
}

integer InSim(key kID)
{
//  check if the AV is logged in and in Sim
    return (llGetAgentSize(kID) != ZERO_VECTOR);
}

list PartnersInSim()
{
    list lTemp;
    integer i = llGetListLength(g_lPartners);
     while (i) {
        string sTemp = llList2String(g_lPartners, --i);
        if (InSim(sTemp))
            lTemp += sTemp;
    }
    return [g_sAllPartners]+lTemp;
}

SendCollarCommand(string sCmd)
{
    g_lPartnersInSim = PartnersInSim();
    integer i = llGetListLength(g_lPartnersInSim);
    if (i > 1) {
        if (osIsUUID(g_sActivePartnerID)) {
            if (llSubStringIndex(sCmd,"acc-") == 0)
                llMessageLinked(LINK_THIS, ACC_CMD, sCmd, g_sActivePartnerID);
            else if (llSubStringIndex(sCmd,"leash") == 0) {
                // don't leash partners further away than 30 meter distance:
                vector vPartnerPos = llList2Vector( llGetObjectDetails((key)g_sActivePartnerID, [OBJECT_POS]) , 0);
                if (llVecDist(llGetPos(), vPartnerPos) < 30.0)
                    llRegionSayTo(g_sActivePartnerID, PersonalChannel(g_sActivePartnerID,0), g_sActivePartnerID+":"+sCmd);
            } else {
                llRegionSayTo(g_sActivePartnerID, PersonalChannel(g_sActivePartnerID,0), g_sActivePartnerID+":"+sCmd);
            }
        } else if (g_sActivePartnerID == g_sAllPartners) {
             i = llGetListLength(g_lPartnersInSim);
             while (i > 1) { // g_lPartnersInSim has always one entry ["ALL"] do whom we dont want to send anything
                string sPartnerID = llList2String(g_lPartnersInSim,--i);
                if (llSubStringIndex(sCmd, "acc-") == 0)
                    llMessageLinked(LINK_THIS, ACC_CMD, sCmd, sPartnerID);
                else
                    llRegionSayTo(sPartnerID, PersonalChannel(sPartnerID,0), sPartnerID+":"+sCmd);
            }
        }
    } else llOwnerSay("None of your partners are in range.");
}

string PlainName(key kID)
{
    string sFullName = llKey2Name(kID);
    integer idx = llSubStringIndex(sFullName, "@");
    if (idx != -1) {
        // hg name
        integer iDot = llSubStringIndex(sFullName, ".");
        string sFirstName = llGetSubString(sFullName, 0, iDot-1);
        string sLastName = llGetSubString(sFullName, iDot+1, idx-2);
        return sFirstName+" "+sLastName;
    } else return sFullName; // local grid name
}

// Partner avi keys are stores on texture side 2 to 7 of g_iPicturePrim
// (Side 0 is border, side 1 is actual picture)
StorePartners()
{
    if (g_iPicturePrim == 0) return;
    integer iPartner;
    for (iPartner = 0; iPartner < 6; iPartner++) {
        if (iPartner < llGetListLength(g_lPartners)) {
            // write
            llSetLinkPrimitiveParamsFast(g_iPicturePrim, [
                PRIM_TEXTURE, iPartner+2, llList2String(g_lPartners, iPartner), <1,1,0>, <0,0,0>, 0
            ]);
        } else {
            // pad blank
            llSetLinkPrimitiveParamsFast(g_iPicturePrim, [
                PRIM_TEXTURE, iPartner+2, (string)TEXTURE_BLANK, <1,1,0>, <0,0,0>, 0
            ]);
        }
    }
}

LoadPartners()
{
    if (g_iPicturePrim == 0) return;
    g_lPartners = [];
    integer iSide;
    for (iSide = 2; iSide < 8; iSide++) {
        list l = llGetLinkPrimitiveParams(g_iPicturePrim, [PRIM_TEXTURE, iSide]);
        key kID = llList2Key(l, 0);
        if ((string)kID == TEXTURE_BLANK) return; // end of list
        else g_lPartners += [kID];
    }
}

AddPartner(string sID)
{
    if (llListFindList(g_lPartners, [sID]) != -1) return;
    if ((key)sID != NULL_KEY) {//don't register any unrecognised
        g_lPartners += [sID];//Well we got here so lets add them to the list.
        llOwnerSay("\n\n"+NameURI(sID)+" has been registered.\nFor easy selection, add a photo or texture to the Owner HUD called '"+PlainName((key)sID)+"'.\n");//Tell the owner we made it.
        StorePartners();
    }
}

RemovePartner(string sID)
{
    integer index = llListFindList(g_lPartners,[sID]);
    if (index != -1) {
        g_lPartners =llDeleteSubList(g_lPartners, index, index);
        llOwnerSay(NameURI(sID)+" has been removed.");
        if (sID == g_sActivePartnerID) NextPartner(0, FALSE);
        StorePartners();
    }
}

Dialog(string sPrompt, list lChoices, list lUtilityButtons, integer iPage, string sMenuType)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET,DIALOG, (string)g_kOwner+"|"+sPrompt+"|"+(string)iPage+"|"+llDumpList2String(lChoices,"`")+"|"+llDumpList2String(lUtilityButtons,"`"), kID);
    g_kMenuID = kID;
    g_sMenuType = sMenuType;
}

MainMenu()
{
    string sPrompt = "\n𝐎 𝐒 𝐂 𝐨 𝐥 𝐥 𝐚 𝐫  Owner HUD\t"+g_sVersion;
    sPrompt += "\n\nSelected Partner: "+NameURI(g_sActivePartnerID);
    list lButtons = g_lMainMenuButtons + g_lMenus;
    Dialog(sPrompt, lButtons, [], 0, g_sMainMenu);
}

RezMenu()
{
    Dialog("\nRez something!\n\nSelected Partner: "+NameURI(g_sActivePartnerID), BuildObjectList(),["BACK"],0,"RezzerMenu");
}

AddPartnerMenu()
{
    string sPrompt = "\nWho would you like to add?\n";
    list lButtons;
    integer index;
    do {
        lButtons += llList2Key(g_lNewPartnerIDs, index);
    } while (++index < llGetListLength(g_lNewPartnerIDs));
    Dialog(sPrompt, lButtons, [g_sAllPartners,UPMENU], -1,"AddPartnerMenu");
}

StartUpdate()
{
    integer pin = (integer)llFrand(99999998.0) + 1;
    llSetRemoteScriptAccessPin(pin);
    llRegionSayTo(g_kUpdater, g_iUpdateChan, "ready|" + (string)pin );
}

list BuildObjectList()
{
    list lRezObjects;
    integer i;
    do lRezObjects += llGetInventoryName(INVENTORY_OBJECT,i);
    while (++i < llGetInventoryNumber(INVENTORY_OBJECT));
    return lRezObjects;
}

SetPicturePrim(string sActivePartnerName)
{
    string sTexture;
    if (llGetInventoryKey(sActivePartnerName)!=NULL_KEY) {
        sTexture = sActivePartnerName;
        llSetLinkPrimitiveParamsFast(g_iPicturePrim,[PRIM_TEXTURE, 1, sTexture, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0]);
        return;
    } else if (llGetInventoryType("buttons_"+g_sCurrentTheme+"_initials") != INVENTORY_TEXTURE) {
        llSetLinkPrimitiveParamsFast(g_iPicturePrim,[PRIM_TEXTURE, 1, sTexture, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0]);  // fallback to default_profile_picture
        return;
    }
    string sAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890";
    string sLetter = llGetSubString(sActivePartnerName, 0, 0);
    integer iPos = llSubStringIndex(sAlphabet, sLetter);
    if (~iPos) {
        sTexture = ".initials";
        float WIDTH = 1.0 / 6.0;
        float HEIGHT = 1.0 / 6.0;
        float fOffsetY = 0.5 - ((iPos / 6) * HEIGHT) - (HEIGHT/2);
        float fOffsetX = -0.5 + ((iPos % 6) * WIDTH) + (WIDTH/2);
        llSetLinkPrimitiveParamsFast(g_iPicturePrim,[PRIM_TEXTURE, 1, "button_"+g_sCurrentTheme+"_initials", <WIDTH, HEIGHT, 0.0>, <fOffsetX, fOffsetY, 0>, 0.0]);
    } else llSetLinkPrimitiveParamsFast(g_iPicturePrim,[PRIM_TEXTURE, 1, sTexture, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0]);  // fallback to default_profile_picture
}

NextPartner(integer iDirection, integer iTouch)
{
    g_lPartnersInSim = PartnersInSim();
    if ((llGetListLength(g_lPartnersInSim) > 1) && iDirection) {
        integer index = llListFindList(g_lPartnersInSim, [g_sActivePartnerID])+iDirection;
        if (index >= llGetListLength(g_lPartnersInSim)) index = 0;
        else if (index < 0) index = llGetListLength(g_lPartnersInSim)-1;
        g_sActivePartnerID = llList2String(g_lPartnersInSim,index);
    } else g_sActivePartnerID = g_sAllPartners;
    if (osIsUUID(g_sActivePartnerID)) {
        // Nothing like osGetProfilePicture exists yet, so use a pic from inventory
        // Try find a texture by partner name, else use a default picture
        string sTexture = "244e3128-c44f-4c32-a549-430cbca5b26e"; // default_profile_picture
        string sActivePartnerName = llKey2Name((key)g_sActivePartnerID);
        integer iDot = llSubStringIndex(llKey2Name((key)g_sActivePartnerID), ".");
        integer iAt = llSubStringIndex(llKey2Name((key)g_sActivePartnerID), "@");
        // Convert 'First.Last @grid:port' to 'First Last' if hypergrid name found
        if (iDot > 0 && iAt > 0) sActivePartnerName = llGetSubString(sActivePartnerName, 0, iDot-1) +" "+llGetSubString(sActivePartnerName, iDot+1, iAt-2);
        if (g_iPicturePrim) SetPicturePrim(sActivePartnerName);
    } else if (g_sActivePartnerID == g_sAllPartners)
        if (g_iPicturePrim) llSetLinkPrimitiveParamsFast(g_iPicturePrim,[PRIM_TEXTURE, 1, g_sTextureALL,<1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0]);
    if(iTouch) {
        if (llGetListLength(g_lPartnersInSim) < 2) llOwnerSay("There is nobody nearby at the moment.");
        else llOwnerSay("\n\nSelected Partner: "+NameURI(g_sActivePartnerID)+"\n");
    }
}

integer PicturePrim()
{
    integer i = llGetNumberOfPrims();
    do {
        if (llSubStringIndex((string)llGetLinkPrimitiveParams(i, [PRIM_DESC]),"Picture") != -1)
            return i;
    } while (--i > 1);
    return 0;
}

default {
    state_entry() {
        g_kOwner = llGetOwner();
        if (llGetInventoryType("oc_installer_sys") == INVENTORY_SCRIPT) return;
        string sObjectName = osReplaceString(llGetObjectName(), "\\d+\\.\\d+\\.?\\d+", g_sVersion, -1, 0);
        if (sObjectName != llGetObjectName()) llSetObjectName(sObjectName);
        llSleep(1.0);//giving time for others to reset before populating menu
        g_iListener = llListen(PersonalChannel(g_kOwner, 0), "", "", ""); //lets listen here
        g_iCmdListener = llListen(g_iChannel, "", g_kOwner, "");
        llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sMainMenu, "");
        g_iPicturePrim = PicturePrim();
        LoadPartners();
        if (llGetListLength(g_lPartners) == 0) {
            llOwnerSay("\n\nYou are probably wearing this Owner HUD for the first time. I'm opening the menu where you can manage your partners. Make sure that your partners are near you and click Add to register them. To open the menu again, please select the gear (⚙) icon on your HUD.\n");
        }
        NextPartner(0,0);
        MainMenu();
    }

    on_rez(integer i)
    {
        //if (g_kOwner != llGetOwner()) llResetScript();
        llResetScript();
    }

    touch_end(integer iNum)
    {
        // Dont do anything if not attached to the HUD
        if (llGetAttached() == 0 || llDetectedKey(0) != g_kOwner) return;
        // I made the root prim the "menu" prim, and the button action default to "menu."
        string sButtonDesc = llToLower((string)llGetLinkPrimitiveParams(llDetectedLinkNumber(0),[PRIM_DESC]));
        string sButtonName = llToLower(llGetLinkName(llDetectedLinkNumber(0)));
        if (llSubStringIndex(sButtonName, "remote") != -1 || llSubStringIndex(sButtonName, "owner hud") != -1)
            llMessageLinked(LINK_SET, CMD_TOUCH,"hide", "");
        else if (sButtonName == "hudmenu") MainMenu();
        else if (sButtonName == "rez") RezMenu();
        else if (llSubStringIndex(sButtonDesc, "picture") != -1) NextPartner(1, TRUE);
        //else if (sButtonName == "bookmarks") llMessageLinked(LINK_THIS, 0, "bookmarks menu", "");
        else if (sButtonName == "tp save") llMessageLinked(LINK_THIS, 0, sButtonDesc, "");
        else SendCollarCommand(sButtonName);
    }

    listen(integer iChannel, string sName, key kID, string sMessage)
    {
        if (iChannel == g_iChannel) {
            list lParams = llParseString2List(sMessage, [" "], []);
            string sCmd = llList2String(lParams, 0);
            if (sMessage == "menu")
                MainMenu();
            else if (sCmd == "channel") {
                integer iNewChannel = llList2Integer(lParams,1);
                if (iNewChannel) {
                    g_iChannel = iNewChannel;
                    llListenRemove(g_iCmdListener);
                    g_iCmdListener = llListen(g_iChannel, "", g_kOwner, "");
                    llOwnerSay("Your new HUD command channel is "+(string)g_iChannel+". Type /"+(string)g_iChannel+"menu to bring up your HUD menu.");
                } else llOwnerSay("Your HUD command channel is "+(string)g_iChannel+". Type /"+(string)g_iChannel+"menu to bring up your HUD menu.");
            }
            else if (llToLower(sMessage) == "help")
                llOwnerSay("\n\nThe manual page can be found at [placeholder]\n");
            else if (sMessage == "reset") llResetScript();
        } else if (iChannel == PersonalChannel(g_kOwner, 0) && llGetOwnerKey(kID) == g_kOwner) {
            if (sMessage == "-.. --- / .... ..- -..") {
                g_kUpdater = kID;
                Dialog("\nINSTALLATION REQUEST PENDING:\n\nAn update or app installer is requesting permission to continue. Installation progress can be observed above the installer box and it will also tell you when it's done.\n\nShall we continue and start with the installation?", ["Yes","No"], ["Cancel"], 0, "UpdateConfirmMenu");
            }
        } else if (llGetSubString(sMessage, 36, 40)==":pong") {
            if (llListFindList(g_lNewPartnerIDs, [llGetOwnerKey(kID)]) == -1 && llListFindList(g_lPartners, [(string)llGetOwnerKey(kID)]) == -1)
                g_lNewPartnerIDs += [llGetOwnerKey(kID)];
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_RESPONSE) {
            list lParams = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParams, 0) == g_sMainMenu) {
                string sChild = llList2String(lParams, 1);
                if (llListFindList(g_lMenus, [sChild]) == -1)
                    g_lMenus+=[sChild];
                    g_lMenus = llListSort(g_lMenus, 1, TRUE);
            }
            lParams = [];
        } else if (iNum == SUBMENU && sStr == "Main") MainMenu();
        else if (iNum == CMD_OWNER_HUD) SendCollarCommand(sStr);
        else if (iNum == UPDATE) {
            if (sStr != "") g_lPartners = llCSV2List(sStr);
            else llMessageLinked(iSender, UPDATE+1, llList2CSV(g_lPartners),"");
        } else if (iNum == 111) {
            g_sTextureALL = sStr;
            if (g_sActivePartnerID == g_sAllPartners)
                llSetLinkPrimitiveParamsFast(g_iPicturePrim, [PRIM_TEXTURE, ALL_SIDES, g_sTextureALL , <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0]);
        } else if (iNum == 112) {
            g_sCurrentTheme = sStr;
            SetPicturePrim(llKey2Name((key)g_sActivePartnerID));
        } else if (iNum == DIALOG_RESPONSE && kID == g_kMenuID) {
            list lParams = llParseString2List(sStr, ["|"], []);
            string sMessage = llList2String(lParams, 1);
            integer i;
            if (g_sMenuType == "Main") {
                if (sMessage == "Collar Menu") SendCollarCommand("menu");
                else if (sMessage == "Rez")
                    RezMenu();
                else if (sMessage == g_sRemovePartner)
                    Dialog("\nWho would you like to remove?\n", g_lPartners, [UPMENU], -1,"RemovePartnerMenu");
                else if (sMessage == g_sListPartners) {
                    string sText ="\n\nI'm currently managing: ";
                    integer iPartnerCount = llGetListLength(g_lPartners);
                    if (iPartnerCount) {
                        i=0;
                        do {
                            if (llStringLength(sText) > 950) {
                                llOwnerSay(sText);
                                sText ="";
                            }
                            sText += NameURI(llList2Key(g_lPartners, i))+", " ;
                        } while (++i < iPartnerCount-1);
                        if (iPartnerCount > 1)sText += " and "+NameURI(llList2Key(g_lPartners, i));
                        if (iPartnerCount == 1) sText = llGetSubString(sText, 0, -3);
                    } else sText += "nobody :(";
                    llOwnerSay(sText);
                    MainMenu();
                } else if (sMessage == g_sAddPartners) {
                     // Ping for auth OpenCollars in the parcel
                     list lAgents = llGetAgentList(AGENT_LIST_PARCEL, []); //scan for who is in the parcel
                     llOwnerSay("Scanning for collar access....");
                     integer iChannel;
                     i =  llGetListLength(lAgents);
                     do {
                        kID = llList2Key(lAgents, --i);
                        if (kID != g_kOwner && llListFindList(g_lPartners,[(string)kID]) == -1 && !osIsNpc(kID)) {
                            if (llGetListLength(g_lListeners) < 60) {//Only 65 listens can simultaneously be open in any single script (SL wiki)
                                iChannel = PersonalChannel(kID, 0);
                                g_lListeners += [llListen(iChannel, "", "", "" )] ;
                                llRegionSayTo(kID, iChannel, (string)kID+":ping");
                            } else i=0;
                        }
                    } while (i);
                    g_iAddPartnerTimer = llGetUnixTime() + 2;
                    llSetTimerEvent(0.5);
                } else if (sMessage == " ◄ ") {
                    NextPartner(-1, FALSE);
                    MainMenu();
                } else if (sMessage == " ► ") {
                    NextPartner(1, FALSE);
                    MainMenu();
                } else if (sMessage == g_sAllPartners) {
                    g_sActivePartnerID = g_sAllPartners;
                    NextPartner(0, FALSE);
                    MainMenu();
                } else if (llListFindList(g_lMenus,[sMessage]) != -1) llMessageLinked(LINK_SET, SUBMENU, sMessage, kID);
            } else if (g_sMenuType == "RemovePartnerMenu") {
                integer index = llListFindList(g_lPartners, [sMessage]);
                if (sMessage == UPMENU) MainMenu();
                else if (sMessage == "Yes") {
                    RemovePartner(g_kRemovedPartnerID);
                    MainMenu();
                } else if (sMessage == "No") MainMenu();
                else if (index != -1) {
                    g_kRemovedPartnerID = llList2Key(g_lPartners, index);
                    Dialog("\nAre you sure you want to remove "+NameURI(g_kRemovedPartnerID)+"?", ["Yes", "No"], [UPMENU], 0,"RemovePartnerMenu");
                }
            } else if (g_sMenuType == "UpdateConfirmMenu") {
                if (sMessage=="Yes") StartUpdate();
                else {
                    llOwnerSay("Installation cancelled.");
                    return;
                }
            } else if (g_sMenuType == "RezzerMenu") {
                    if (sMessage == UPMENU) MainMenu();
                    else {
                        g_sRezObject = sMessage;
                        if (llGetInventoryType(g_sRezObject) == INVENTORY_OBJECT)
                            llRezObject(g_sRezObject, llGetPos() + <2, 2, 0>, ZERO_VECTOR, llGetRot(), 0);
                    }
            } else if (g_sMenuType == "AddPartnerMenu") {
                if (sMessage == g_sAllPartners) {
                    i = llGetListLength(g_lNewPartnerIDs);
                    key kNewPartnerID;
                    do {
                        kNewPartnerID = llList2Key(g_lNewPartnerIDs, --i);
                        if (kNewPartnerID != NULL_KEY) {
                            if (llGetListLength(g_lPartners) < 6) AddPartner(kNewPartnerID);
                            else llOwnerSay("Can't add any more partners, you are at the maximum of 6");
                        }
                    } while (i);
                } else if (osIsUUID(sMessage))
                    AddPartner(sMessage);
                g_lNewPartnerIDs = [];
                MainMenu();
            }
        }
    }

    timer()
    {
        integer iTimeStamp = llGetUnixTime();

        if (g_iAddPartnerTimer && iTimeStamp >= g_iAddPartnerTimer) {
            g_iAddPartnerTimer = 0;
            if (llGetListLength(g_lNewPartnerIDs) > 0) AddPartnerMenu();
            else llOwnerSay("\n\nYou currently don't have access to any nearby collars. Requirements to add partners are to either have them captured or their collar is set to public or they have you listed as an owner or trust role.\n");
            llSetTimerEvent(0.0);
            integer n = llGetListLength(g_lListeners);
            while (n--)
                llListenRemove(llList2Integer(g_lListeners,n));
            g_lListeners = [];
        }

        if (g_iAddPartnerTimer == FALSE) llSetTimerEvent(0.0);
    }

    object_rez(key kID)
    {
        llSleep(0.5); // make sure object is rezzed and listens
        if (g_sActivePartnerID == g_sAllPartners)
            llRegionSayTo(kID, PersonalChannel(g_kOwner, 1234), llDumpList2String(llDeleteSubList(PartnersInSim(), 0, 0), ","));
        else
            llRegionSayTo(kID, PersonalChannel(g_kOwner, 1234), g_sActivePartnerID);
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER) llResetScript();
    }
}
