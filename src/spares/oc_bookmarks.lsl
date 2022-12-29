
//  oc_bookmarks.lsl
//
//  Copyright (c) 2008 - 2017 Satomi Ahn, Nandana Singh, Wendy Starfall,
//  Sumi Perl, Master Starship, littlemousy, mewtwo064, ml132,
//  Romka Swallowtail, Garvin Twine et al.
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

string g_sAppVersion = "2022.12.29";

string g_sSubMenu = "Bookmarks";
string g_sParentMenu = "Apps";
string PLUGIN_CHAT_CMD = "tp";
string PLUGIN_CHAT_CMD_ALT = "bookmarks";
string g_sCard = ".bookmarks";

list g_lDestinations;
list g_lDestinations_Slurls;
list g_lVolatile_Destinations;
list g_lVolatile_Slurls;
string g_tempLoc;

list g_lMenuIDs;
integer g_iMenuStride = 3;

key g_kWearer = NULL_KEY;

string  g_sSettingToken = "bookmarks_";
key g_kDataID = NULL_KEY;
integer g_iLine;
string UPMENU = "BACK";
key g_kCommander = NULL_KEY;

list PLUGIN_BUTTONS = ["Add", "Remove", "Print"];

integer CMD_OWNER = 500;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;

integer NOTIFY = 1002;
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
integer MENUNAME_REMOVE = 3003;
integer RLV_CMD = 6000;
integer RLV_OFF = 6100;
integer RLV_ON = 6101;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuType];
}

DoMenu(key keyID, integer iAuth) {
    string sPrompt = "\nBookmarks\t"+g_sAppVersion+"\n\nTake me away, gumby!";
    list lMyButtons = PLUGIN_BUTTONS + g_lDestinations + g_lVolatile_Destinations;
    Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0, iAuth, "bookmarks");
}

UserCommand(integer iNum, string sStr, key kID) {
    if (sStr == "reset") {
        if(iNum == CMD_WEARER || iNum == CMD_OWNER) llResetScript();
    } else if (sStr == "rm bookmarks") {
        if (kID != g_kWearer && iNum != CMD_OWNER) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else Dialog(kID,"\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes","No","Cancel"], [], 0, iNum,"rmbookmarks");
    } else if (sStr == PLUGIN_CHAT_CMD || llToLower(sStr) == "menu " + PLUGIN_CHAT_CMD_ALT || llToLower(sStr) == PLUGIN_CHAT_CMD_ALT) {
        if (iNum == CMD_GROUP) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else DoMenu(kID, iNum);
    } else if (llGetSubString(sStr,0,llStringLength(PLUGIN_CHAT_CMD+" add")-1) == PLUGIN_CHAT_CMD+" add") {
        if (iNum == CMD_GROUP) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else if(llStringLength(sStr) > llStringLength(PLUGIN_CHAT_CMD + " add")) {
            string sAdd = llStringTrim(llGetSubString(sStr, llStringLength(PLUGIN_CHAT_CMD + " add") + 1, -1), STRING_TRIM);
            if(llListFindList(g_lVolatile_Destinations, [sAdd]) >= 0 || llListFindList(g_lDestinations, [sAdd]) >= 0)
                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"This destination name is already taken",kID);
            else {
                string slurl = FormatRegionName();
                addDestination(sAdd, slurl, kID);
            }
        } else {
            Dialog(kID,
"Enter a name for the destination below. Submit a blank field to cancel and return.
You can enter:
1) A friendly name to add your current location to your favorites
2) A new location or SLurl", [], [], 0, iNum,"TextBoxIdSave");

        }
    } else if (llGetSubString(sStr,0,llStringLength(PLUGIN_CHAT_CMD+" remove")-1) == PLUGIN_CHAT_CMD+" remove") {
        if (iNum == CMD_GROUP) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else if (llStringLength(sStr) > llStringLength(PLUGIN_CHAT_CMD + " remove")) {
            string sDel = llStringTrim(llGetSubString(sStr,  llStringLength(PLUGIN_CHAT_CMD + " remove"), -1), STRING_TRIM);
            if (llListFindList(g_lVolatile_Destinations, [sDel]) < 0) {
                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Can't find bookmark " + (string)sDel + " to be deleted.",kID);
            } else {
                integer iIndex;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + sDel, "");
                iIndex = llListFindList(g_lVolatile_Destinations, [sDel]);
                g_lVolatile_Destinations = llDeleteSubList(g_lVolatile_Destinations, iIndex, iIndex);
                g_lVolatile_Slurls = llDeleteSubList(g_lVolatile_Slurls, iIndex, iIndex);
                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Removed destination " + sDel,kID);
            }
        } else
            Dialog(kID, "Select a bookmark to be removed...", g_lVolatile_Destinations, [UPMENU], 0, iNum,"RemoveMenu");
    } else if (llGetSubString(sStr,0,llStringLength(PLUGIN_CHAT_CMD+" print")-1) == PLUGIN_CHAT_CMD+" print") {
        if (iNum == CMD_GROUP) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else PrintDestinations(kID);
    } else if (llGetSubString(sStr,0,llStringLength(PLUGIN_CHAT_CMD)-1) == PLUGIN_CHAT_CMD) {
        if (iNum == CMD_GROUP) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
            return;
        }
        string sCmd = llStringTrim(llGetSubString(sStr, llStringLength(PLUGIN_CHAT_CMD) + 1, -1), STRING_TRIM);
        g_kCommander = kID;
        if (llListFindList(g_lVolatile_Destinations, [sCmd]) >= 0) {
            integer iIndex = llListFindList(g_lVolatile_Destinations, [sCmd]);
            TeleportTo(llList2String(g_lVolatile_Slurls, iIndex));
        } else if (llListFindList(g_lDestinations, [sCmd]) >= 0) {
            integer iIndex = llListFindList(g_lDestinations, [sCmd]);
            TeleportTo(llList2String(g_lDestinations_Slurls, iIndex));
        } else if (llStringLength(sCmd) > 0) {
            integer i;
            integer iEnd = llGetListLength(g_lDestinations);
            string sDestination;
            integer iFound;
            list matchedBookmarks;
            for (; i < iEnd; i++) {
                sDestination = llList2String(g_lDestinations, i);
                if(llSubStringIndex(llToLower(sDestination), llToLower(sCmd)) >= 0) {
                    iFound += 1;
                    matchedBookmarks += sDestination;
                }
            }
            iEnd = llGetListLength(g_lVolatile_Destinations);
            for(i = 0; i < iEnd; i++) {
                sDestination = llList2String(g_lVolatile_Destinations, i);
                if(llSubStringIndex(llToLower(sDestination), llToLower(sCmd)) >= 0) {
                    iFound += 1;
                    matchedBookmarks += sDestination;
                }
            }
            if (!iFound) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"The bookmark '" + sCmd + "' has not been found in the %DEVICETYPE% of %WEARERNAME%.",kID);
            else if (iFound > 1) Dialog(kID, "More than one matching bookmark was found in the %DEVICETYPE% of %WEARERNAME%.\nChoose a bookmark to teleport to.", matchedBookmarks, [UPMENU], 0, iNum,"choose bookmark");
            else UserCommand(iNum, PLUGIN_CHAT_CMD + " " + llList2String(matchedBookmarks, 0), g_kCommander);
        }
        else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"I didn't understand your command.",kID);
    }
}

addDestination(string sMessage, string sLoc, key kID) {
    if (llGetListLength(g_lVolatile_Destinations)+llGetListLength(g_lDestinations) >= 45 ) {
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"The maximum number 45 bookmars is already reached.",kID);
        return;
    }
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + sMessage + "=" + sLoc, "");
    g_lVolatile_Destinations += sMessage;
    g_lVolatile_Slurls += sLoc;
    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Added destination " + sMessage + " with a location of: " + sLoc,kID);
}

string FormatRegionName() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);
    return (region + "(" + posx + "," + posy + "," + posz + ")");
}

string convertSlurl(string sStr) {
    sStr = llStringTrim(llUnescapeURL(sStr), STRING_TRIM);
    string sIndex = "http:";
    list lPieces =  llParseStringKeepNulls(sStr, ["/"], []);
    integer iHttploc = 0;
    string sStringToKeep;
    integer iHttpInString = llSubStringIndex(llList2String(lPieces, 0), sIndex);
    if(iHttpInString > 0)
        sStringToKeep = llGetSubString(llList2String(lPieces, 0), 0, iHttpInString - 1);
    if (llGetListLength(lPieces) == 8) {
        string sRegion = llList2String(lPieces, iHttploc + 4);
        string sLocationx = llList2String(lPieces, iHttploc + 5);
        string sLocationy = llList2String(lPieces, iHttploc + 6);
        string sLocationz = llList2String(lPieces, iHttploc + 7);
        sStr = sStringToKeep + sRegion + "(" + sLocationx + "," + sLocationy + "," + sLocationz + ")";
        return sStr;
    }
    return sStr;
}

integer isInteger(string input) {
    return ((string)((integer)input) == input);
}

integer validatePlace(string sStr, key kAv, integer iAuth) {
    list lPieces;
    integer MAX_CHAR_TYPE = 2;
    string sAssembledLoc;
    string sRegionName;
    string sFriendlyName;
    sStr = llStringTrim(sStr, STRING_TRIM);
    lPieces = llParseStringKeepNulls(sStr, ["~"], []);
    if (llGetListLength(lPieces) == MAX_CHAR_TYPE) {
        if(llStringLength(llList2String(lPieces, 0)) < 1) return 2;
        sFriendlyName = llStringTrim(llList2String(lPieces, 0), STRING_TRIM);
        lPieces = llParseStringKeepNulls(llList2String(lPieces, 1), ["("], []);
    } else if (llGetListLength(lPieces) > MAX_CHAR_TYPE) return 1;
    else lPieces = llParseStringKeepNulls(llList2String(lPieces, 0), ["("], []);
    if (llGetListLength(lPieces) == MAX_CHAR_TYPE) {
        if(llStringLength(llList2String(lPieces, 0)) < 1) return 4;
        sRegionName = llStringTrim(llList2String(lPieces, 0), STRING_TRIM);
    } else if (llGetListLength(lPieces) > MAX_CHAR_TYPE) return 3;
    else  {
        UserCommand(iAuth, PLUGIN_CHAT_CMD + " add " + sStr, kAv);
        UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
        return 0;
    }
    sAssembledLoc = llStringTrim("(" + llList2String(lPieces, 1), STRING_TRIM);
    lPieces = llParseStringKeepNulls(sAssembledLoc, [","], []);
    if (llGetListLength(lPieces) != 3) return 5;
    if (llGetSubString(sAssembledLoc, 0, 0) != "(") return 6;
    if (llGetSubString(sAssembledLoc, llStringLength(sAssembledLoc) - 1, llStringLength(sAssembledLoc) - 1) != ")") return 7;
    lPieces = llParseStringKeepNulls(llGetSubString(sAssembledLoc, 1, llStringLength(sAssembledLoc) - 2), [","], []);
    integer i;
    for (; i <= llGetListLength(lPieces)-1; ++i) {
        integer y = 0;
        integer z = llStringLength(llList2String(lPieces, i)) - 1;
        for (y = 0; y <= z; ++y) {
            if (isInteger(llGetSubString(llList2String(lPieces, i), y, y)) != 1)
                 return 8;
        }
    }
    if (sFriendlyName == "") {
        g_tempLoc = sRegionName + sAssembledLoc;
        Dialog(kAv,
"\nEnter a name for the destination " + sRegionName + sAssembledLoc + "
below.\n- Submit a blank field to cancel and return.", [], [], 0, iAuth,"TextBoxIdLocation");

    } else {
        addDestination(sFriendlyName, sRegionName, kAv);
        UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
    }
    return 0;
}

ReadDestinations() {
    g_lDestinations = [];
    g_lDestinations_Slurls = [];
    g_iLine = 0;
    if(llGetInventoryType(g_sCard)==INVENTORY_NOTECARD)
        g_kDataID = llGetNotecardLine(g_sCard, 0);
}

TeleportTo(string sStr) {
    string sRegion = llStringTrim(llGetSubString(sStr, 0, llSubStringIndex(sStr, "(") - 1), STRING_TRIM);
    string sCoords = "<"+llStringTrim(llGetSubString(sStr, llSubStringIndex(sStr, "(") + 1 , llStringLength(sStr) - 2), STRING_TRIM)+">";
    vector vCoords = (vector)sCoords;
    vector vLookAt = llRot2Euler(llGetRot()) * RAD_TO_DEG;
    osTeleportOwner(sRegion, vCoords, vLookAt); // Threatlevel none, works with HG
}

PrintDestinations(key kID) {  // On inventory change, re-read our ~destinations notecard
    integer i;
    integer iLength = llGetListLength(g_lDestinations);
    string sMsg;
    sMsg += "\n\nThe below can be copied and pasted into the " + g_sCard + " notecard. The format should follow:\n\nDestination Name~http://hg.example.com:8002:Region Name(127,127,20)\n\n";
    for(; i < iLength; i++) {
        sMsg += llList2String(g_lDestinations, i) + "~" + llList2String(g_lDestinations_Slurls, i) + "\n";
        if (llStringLength(sMsg) >1000) {
             llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sMsg,kID);
             sMsg = "";
        }
    }
    iLength = llGetListLength(g_lVolatile_Destinations);
    for(i = 0; i < iLength; i++) {
        sMsg += llList2String(g_lVolatile_Destinations, i) + "~" + llList2String(g_lVolatile_Slurls, i) + "\n";
        if (llStringLength(sMsg) >1000) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sMsg,kID);
            sMsg = "";
        }
    }
    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sMsg,kID);
}

default {
    on_rez(integer iStart) {
        if (llGetOwner()!=g_kWearer) llResetScript();
        ReadDestinations();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        ReadDestinations();
    }

    dataserver(key kID, string sData) {
        if (kID == g_kDataID) {
            list split;
            if (sData != EOF) {
                if(llGetSubString(sData, 0, 2) != "") {
                    sData = llStringTrim(sData, STRING_TRIM);
                    split = llParseString2List(sData, ["~"], []);
                    if (!~llListFindList(g_lDestinations, [llStringTrim(llList2String(split, 0), STRING_TRIM)])){
                        g_lDestinations += [ llStringTrim(llList2String(split, 0), STRING_TRIM) ];
                        g_lDestinations_Slurls += [ llStringTrim(llList2String(split, 1), STRING_TRIM) ];
                        if (llGetListLength(g_lDestinations) == 30) return;
                    }
                }
                g_iLine++;
                g_kDataID = llGetNotecardLine(g_sCard, g_iLine);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if(iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if(llGetSubString(sToken, 0, i) == g_sSettingToken) {
                list lDestination = [llGetSubString(sToken, llSubStringIndex(sToken, "_") + 1, llSubStringIndex(sToken, "="))];
                if(llListFindList(g_lVolatile_Destinations, lDestination) < 0) {
                    g_lVolatile_Destinations += lDestination;
                    g_lVolatile_Slurls += [sValue];
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if(iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenuType == "TextBoxIdLocation") {
                    if(sMessage != " ")
                        addDestination(sMessage, g_tempLoc, kID);
                    UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
                } else if (sMenuType == "TextBoxIdSave") {
                    if(sMessage != " ")
                        validatePlace(convertSlurl(sMessage),kAv,iAuth);
                    else
                        UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
                } else if (sMenuType == "RemoveMenu") {
                    if (sMessage == UPMENU)
                        UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
                    else if (sMessage != "") {
                        UserCommand(iAuth, PLUGIN_CHAT_CMD + " remove " + sMessage, kAv);
                        UserCommand(iAuth, PLUGIN_CHAT_CMD + " remove", kAv);
                    } else { UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv); }
                } else if (sMessage == UPMENU)
                    llMessageLinked(LINK_ROOT, iAuth, "menu " + g_sParentMenu, kAv);
                else if (sMenuType == "rmbookmarks") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_ROOT, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kAv);
                        if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT) llRemoveInventory(llGetScriptName());
                    } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kAv);
                } else if (~llListFindList(PLUGIN_BUTTONS, [sMessage])) {
                    if (sMessage == "Add")
                        UserCommand(iAuth, PLUGIN_CHAT_CMD + " add", kAv);
                    else if (sMessage == "Remove")
                        UserCommand(iAuth, PLUGIN_CHAT_CMD + " remove", kAv);
                    else if (sMessage == "Print") {
                        UserCommand(iAuth, PLUGIN_CHAT_CMD + " print", kAv);
                        UserCommand(iAuth, PLUGIN_CHAT_CMD, kAv);
                    }
                } else if (~llListFindList(g_lDestinations + g_lVolatile_Destinations, [sMessage]))
                    UserCommand(iAuth, PLUGIN_CHAT_CMD + " " + sMessage, kAv);
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    changed(integer iChange) {
        if(iChange & CHANGED_INVENTORY) ReadDestinations();
        if(iChange & CHANGED_OWNER)  llResetScript();
    }
}

