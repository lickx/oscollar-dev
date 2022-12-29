
//  oc_themes.lsl
//
//  Copyright (c) 2008 - 2017 Nandana Singh, Lulu Pink, Garvin Twine,
//  Cleo Collins, Master Starship, Joy Stipe, Wendy Starfall, littlemousy,
//  Romka Swallowtail et al.
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

// Based on a merge of all OpenCollar appearance plugins by littlemousy
// Virtual Disgrace - Paint is derivate of Virtual Disgrace - Customize
// OpenCollar - styles is derivative of Virtual Disgrace - Paint

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

list g_lElements;
list g_lElementFlags;
list g_lTextureDefaults;
list g_lShinyDefaults;
list g_lColorDefaults;

string g_sDeviceType = "collar";

list g_lTextures;
list g_lTextureShortNames;
list g_lTextureKeys;
integer g_iTexturesNotecardLine;
key g_kTextureCardUUID;
string g_sTextureCard;
key g_kTexturesNotecardRead;
string g_sCurrentTheme;
integer g_iThemesReady;

list g_lMenuIDs;
integer g_iMenuStride = 3;

integer CMD_OWNER = 500;
integer CMD_WEARER = 503;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;

integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

key g_kWearer = NULL_KEY;

list g_lShiny = ["none","low","medium","high","specular"];
list g_lGlow = ["none",0.0,"low",0.1,"medium",0.2,"high",0.4,"veryHigh",0.8];
integer g_iNumHideableElements;
integer g_iNumElements;
string g_sThemesCard = ".themes";
key g_kThemesNotecardRead = NULL_KEY;
key g_kThemesCardUUID = NULL_KEY;
integer g_iSetThemeAuth;
key g_kSetThemeUser = NULL_KEY;
string g_sThemesNotecardReadType;
list g_lThemes;
integer g_iThemesNotecardLine;
integer g_iLeashParticle;
integer g_iLooks;
integer g_iThemePage;

list g_lCommands = ["themes", "color", "texture", "shiny", "glow", "looks"];

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

LooksMenu(key kID, integer iAuth) {
    Dialog(kID, "\nHere you can change cosmetic settings of the %DEVICETYPE%. \"Themes\" will also be applied to any matching cuffs.", ["Color","Glow","Shiny","Texture","Themes"], ["BACK"],0, iAuth, "LooksMenu~menu");
}

ThemeMenu(key kID, integer iAuth, integer iPage) {
    list lButtons;
    integer i;
    while (i < llGetListLength(g_lThemes)) {
        lButtons += llList2List(g_lThemes,i,i);
        i=i+2;
    }
    Dialog(kID, "\nThemes\n\nChoose a visual theme for your %DEVICETYPE%.\n", lButtons, ["BACK"], iPage, iAuth, "ThemeMenu~themes");
    lButtons=[];
}

ShinyMenu(key kID, integer iAuth, string sElement) {
    string sShineElement = llList2String(llParseString2List(sElement,[" "],[]),-1);
    Dialog(kID, "\nSelect a degree of shine for "+sShineElement+".", g_lShiny, ["BACK"], 0, iAuth, "ShinyMenu~"+sElement);
}

GlowMenu(key kID, integer iAuth, string sElement) {
    string sGlowElement = llList2String(llParseString2List(sElement,[" "],[]),-1);
    list lButtons = llList2ListStrided(g_lGlow, 0, -1, 2);
    Dialog(kID, "\nSelect a degree of glow for "+sGlowElement+".", lButtons, ["BACK"], 0, iAuth, "GlowMenu~"+sElement);
}

TextureMenu(key kID, integer iPage, integer iAuth, string sElement) {
    list lElementTextures;
    integer iCustomTextureFound;
    string sTexElement = llList2String(llParseString2List(sElement,[" "],[]),-1);
    integer iNumTextures=llGetListLength(g_lTextures);
    while (iNumTextures--) {
        string sTextureName=llList2String(g_lTextures,iNumTextures);
        if (llListFindList(lElementTextures,[sTextureName])==-1) {
            if (!llSubStringIndex(sTextureName,sTexElement+"~")) {
                lElementTextures+=llList2String(g_lTextureShortNames,iNumTextures);
                if ((!iCustomTextureFound) && llGetListLength(lElementTextures) ) {
                    iCustomTextureFound=1;
                    lElementTextures=[];
                    iNumTextures=llGetListLength(g_lTextures);
                }
            } else if (llSubStringIndex(sTextureName,"~") == -1 && !iCustomTextureFound)
                lElementTextures+=llList2String(g_lTextureShortNames,iNumTextures);
        }
    }
    Dialog(kID, "\nSelect a texture to apply to "+sTexElement+".",llListSort(lElementTextures,1,1), ["BACK"], iPage, iAuth, "TextureMenu~"+sElement);
}

ColorMenu(key kID, integer iPage, integer iAuth, string sBreadcrumbs) {
    string sCategory = llList2String(llParseString2List(sBreadcrumbs,[" "],[]),-1);
    Dialog(kID, "\nSelect a color for "+sCategory+".", ["colormenu please"], ["BACK"], iPage, iAuth, "ColorMenu~"+sBreadcrumbs);
}

ElementMenu(key kAv, integer iPage, integer iAuth, string sType) {
    integer iMask;
    string sTypeNice;
    sType=llToLower(sType);
    if (sType == "texture") {
        iMask=1;
        sTypeNice = "Texture";
    } else if (sType == "color") {
        iMask=2;
        sTypeNice = "Color";
    } else if (sType == "shiny") {
        iMask=4;
        sTypeNice = "Shininess";
    } else if (sType == "glow") {
        iMask=8;
        sTypeNice = "Glow";
    }
    string sPrompt = "\nSelect an element to adjust its "+sTypeNice+".";
    list lButtons;
    integer numElements = g_iNumElements;
    while(numElements--) {
        if ( ~llList2Integer(g_lElementFlags,numElements) & iMask) {
            string sElement=llList2String(g_lElements,numElements);
            lButtons += sElement;
        }
    }
    lButtons = llListSort(lButtons, 1, TRUE);
    Dialog(kAv, sPrompt, lButtons, ["ALL", "BACK"], iPage, iAuth, "ElementMenu~"+sType);
}

string LinkType(integer iLinkNum, string sSearchString) {
    string sDesc = llList2String(llGetLinkPrimitiveParams(iLinkNum, [PRIM_DESC]),0);
    list lParams = llParseString2List(llStringTrim(sDesc,STRING_TRIM), ["~"], []);
    if (~llListFindList(lParams,[sSearchString])) return "immutable";
    else if (sDesc == "" || sDesc == "(No Description)") return "";
    else return llList2String(lParams, 0);
}

BuildThemesList() {
    if(llGetInventoryType(g_sThemesCard)==INVENTORY_NOTECARD) {
        g_kThemesCardUUID=llGetInventoryKey(g_sThemesCard);
        g_lThemes=[];
        g_iThemesNotecardLine=0;
        g_sThemesNotecardReadType="initialize";
        g_kThemesNotecardRead=llGetNotecardLine(g_sThemesCard,g_iThemesNotecardLine);
    }
}

BuildTexturesList() {
    g_lTextures=[];
    g_lTextureKeys=[];
    g_lTextureShortNames=[];
    integer numInventoryTextures = llGetInventoryNumber(INVENTORY_TEXTURE);
    while (numInventoryTextures--) {
        string sTextureName = llGetInventoryName(INVENTORY_TEXTURE, numInventoryTextures);
        string sShortName=llList2String(llParseString2List(sTextureName, ["~"], []), -1);
        if (!(llGetSubString(sTextureName, 0, 5) == "leash_" || sTextureName == "chain" || sTextureName == "rope" || llGetSubString(sTextureName, 0, 5) == "font_")) {
            g_lTextures += sTextureName;
            g_lTextureKeys += sTextureName;
            g_lTextureShortNames+=sShortName;
        }
    }
    g_sTextureCard = "!textures";
    if(llGetInventoryType(g_sTextureCard)!=INVENTORY_NOTECARD) g_sTextureCard=".textures";
    if(llGetInventoryType(g_sTextureCard)==INVENTORY_NOTECARD) {
        g_iTexturesNotecardLine=0;
        g_kTextureCardUUID=llGetInventoryKey(g_sTextureCard);
        g_kTexturesNotecardRead=llGetNotecardLine(g_sTextureCard,g_iTexturesNotecardLine);
    } else g_kTextureCardUUID=NULL_KEY;
}

BuildElementsList(){
    g_iNumHideableElements = 0;
    g_iNumElements = 0;
    integer iLinkNum = llGetNumberOfPrims()+1;
    while (iLinkNum-- > 1) {
        string sElement = llList2String(llGetLinkPrimitiveParams(iLinkNum, [PRIM_DESC]),0);
        if ((~llSubStringIndex(llToLower(sElement),"floattext")) || (~llSubStringIndex(llToLower(sElement),"leashpoint"))) {
        } else if (sElement != "" && sElement != "(No Description)") {
            list lParams = llParseString2List(llStringTrim(sElement,STRING_TRIM), ["~"], []);
            string sElementName = llList2String(lParams,0);
            integer iLinkFlags;
            if (~llListFindList(lParams,["notexture"])) iLinkFlags = iLinkFlags | 1;
            if (~llListFindList(lParams,["nocolor"])) iLinkFlags = iLinkFlags | 2;
            if (~llListFindList(lParams,["noshiny"])) iLinkFlags = iLinkFlags | 4;
            if (~llListFindList(lParams,["noglow"])) iLinkFlags = iLinkFlags | 8;
            integer iElementIndex=llListFindList(g_lElements, [sElementName]);
            if (! ~iElementIndex ) {
                g_lElements += sElementName;
                g_lElementFlags += iLinkFlags;
                if (! (iLinkFlags & 16)) {
                    g_iNumHideableElements++;
                }
                g_iNumElements++;
            } else {
                integer iOldFlags=llList2Integer(g_lElementFlags,iElementIndex);
                iLinkFlags = iLinkFlags & iOldFlags;
                g_lElementFlags = llListReplaceList(g_lElementFlags,[iLinkFlags],iElementIndex, iElementIndex);
                if (iLinkFlags & 16 & ~iOldFlags) {
                    g_iNumHideableElements++;
                }
            }
        }
    }
}

UserCommand(integer iNum, string sStr, key kID, integer reMenu, integer iPage) {
    string sStrLower = llToLower(sStr);
    if (sStrLower == "rm themes") {
        Dialog(kID,"\nDo you really want to uninstall the themes plugin?",["Yes","No","Cancel"],[],0,iNum,"rmThemes");
        return;
    }
    list lParams = llParseString2List(sStrLower, [" "], []);
    if ((~llListFindList(g_lCommands, [llList2String(lParams,0)])) || (llList2String(lParams,0)=="menu" && (~llListFindList(g_lCommands, [llList2String(lParams,1)]))) ) {
        if (kID == g_kWearer || iNum == CMD_OWNER) {
            lParams = llParseString2List(sStr, [" "], []);
            string sCommand=llToLower(llList2String(lParams,0));
            string sElement=llList2String(lParams,1);
            if (sCommand == "themes" || sStrLower == "menu themes") {
                sElement = llGetSubString(sStr, 7, -1);
                integer iElementIndex = llListFindList(g_lThemes,[sElement]);
                if (~iElementIndex) {
                    g_sThemesNotecardReadType="processing";
                    g_iThemesNotecardLine = 1 + llList2Integer(g_lThemes,iElementIndex+1);
                    g_kSetThemeUser=kID;
                    g_iSetThemeAuth=iNum;
                    llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Applying the "+sElement+" theme...",kID);
                    llMessageLinked(LINK_ROOT,601,"themes "+sElement,g_kWearer);
                    g_iThemePage = iPage;
                    g_kThemesNotecardRead=llGetNotecardLine(g_sThemesCard,g_iThemesNotecardLine);
                } else if (g_kThemesCardUUID != NULL_KEY) {
                    if (g_iThemesReady) ThemeMenu(kID,iNum,iPage);
                    else {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Themes still loading...",kID);
                        if (g_iLooks) LooksMenu(kID, iNum);
                        else llMessageLinked(LINK_ROOT, iNum, "menu Settings", kID);
                    }
                } else {
                    Dialog(kID,"\n⚠ This %DEVICETYPE% has no dedicated themes configured for it\n\nYou can [Uninstall] the themes plugin to save resources\nor you can use the [Looks] menu to fine-tune your %DEVICETYPE%\n\nATTENTION:\n\nDevices that are properly configured for [Looks] don't show this warning. Please use [Looks] responsibly in this case as it could alter your %DEVICETYPE% permanently\n\nIn case of doubt simply [Uninstall] this plugin ❤\n\n",[],["Uninstall","Looks","BACK"],0,iNum,"NoThemesMenu");
                }
            } else if (sCommand == "looks") LooksMenu(kID,iNum);
            else if (sCommand == "menu") ElementMenu(kID, 0, iNum, sElement);
            else if (sCommand == "shiny") {
                string sShiny=llList2String(lParams,2);
                integer iShinyIndex=llListFindList(g_lShiny,[sShiny]);
                if (~iShinyIndex) sShiny=(string)iShinyIndex;
                integer iShiny=(integer)sShiny;
                if (sShiny=="") ShinyMenu(kID, iNum, sStr);
                else if (iShiny || sShiny=="0") {
                    integer iLinkCount = llGetNumberOfPrims()+1;
                    while (iLinkCount-- > 1) {
                        string sLinkType=LinkType(iLinkCount, "no"+sCommand);
                        if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                            // OpenSim doesn't support PRIM_SPECULAR (yet) so we only support traditional shiny
                            if (iShiny < 4 ) llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_BUMP_SHINY,ALL_SIDES,iShiny,0]);
                        }
                    }
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "shininess_" + sElement + "=" + (string)iShiny, "");
                    if (reMenu) ShinyMenu(kID, iNum, "shiny "+sElement);
                }
            } else if (sCommand == "glow") {
                string sGlow=llList2String(lParams,2);
                integer iGlowIndex=llListFindList(g_lGlow,[sGlow]);
                float fGlow = (float)sGlow;
                if (~iGlowIndex) {
                    sGlow=(string)llList2String(g_lGlow,iGlowIndex+1);
                    fGlow = llList2Float(g_lGlow,iGlowIndex+1);
                }
                if (sGlow=="") {
                    GlowMenu(kID, iNum, sStr);
                } else if ((fGlow >= 0.0 && fGlow <= 1.0)|| sGlow=="0") {
                    integer iLinkCount = llGetNumberOfPrims()+1;
                    while (iLinkCount-- > 1) {
                        string sLinkType=LinkType(iLinkCount, "no"+sCommand);
                        if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                            llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_GLOW,ALL_SIDES,fGlow]);
                        }
                    }
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "glow_" + sElement + "=" + (string)fGlow, "");
                    if (reMenu) GlowMenu(kID, iNum, "glow "+sElement);
                }
            } else if (sCommand == "color") {
                string sColor = llDumpList2String(llDeleteSubList(lParams,0,1)," ");
                if (sColor != "") {
                    integer iLinkCount = llGetNumberOfPrims()+1;
                    vector vColorValue=(vector)sColor;
                    while (iLinkCount-- > 1) {
                        string sLinkType=LinkType(iLinkCount, "nocolor");
                        if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                            llSetLinkColor(iLinkCount, vColorValue, ALL_SIDES);
                        }
                    }
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "color_"+sElement+"="+sColor, "");
                    if (reMenu) ColorMenu(kID, iPage, iNum, sCommand+" "+sElement);
                } else {
                    ColorMenu(kID, iPage, iNum, sCommand+" "+sElement);
                }
            } else if (sCommand == "texture") {
                string sTextureShortName=llDumpList2String(llDeleteSubList(lParams,0,1)," ");
                if (sTextureShortName=="Default") {
                    integer iDefaultTextureIndex = llListFindList(g_lTextureDefaults, [sElement]);
                    if (~iDefaultTextureIndex) sTextureShortName = llList2String(g_lTextureDefaults, iDefaultTextureIndex + 1);
                }
                integer iTextureIndex=llListFindList(g_lTextures,[sElement+"~"+sTextureShortName]);
                if (osIsUUID(sTextureShortName)) iTextureIndex = 0;
                else if (! (~iTextureIndex))
                    iTextureIndex = llListFindList(g_lTextures,[sTextureShortName]);
                if (sTextureShortName == "") {
                    TextureMenu(kID, 0, iNum, sStr);
                } else if (iTextureIndex==-1) {
                    llMessageLinked(LINK_DIALOG,NOTIFY, "0"+"Sorry! The \""+sTextureShortName+"\" texture doesn't fit on this particular element, please try another.",kID);
                    if (reMenu) TextureMenu(kID, 0, iNum, sCommand+" "+sElement);
                } else {
                    string sTextureKey;
                    if (osIsUUID(sTextureShortName)) sTextureKey=sTextureShortName;
                    else sTextureKey= llList2String(g_lTextureKeys,iTextureIndex);
                    integer iLinkCount = llGetNumberOfPrims()+1;
                    while (iLinkCount-- > 1) {
                        string sLinkType = LinkType(iLinkCount, "notexture");
                        if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                            integer iSides = llGetLinkNumberOfSides(iLinkCount);
                            integer iFace ;
                            for (iFace = 0; iFace < iSides; iFace++) {
                                list lTextureParams = llGetLinkPrimitiveParams(iLinkCount,[PRIM_TEXTURE,iFace]);
                                lTextureParams = llDeleteSubList(lTextureParams,0,0);
                                llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_TEXTURE,iFace,sTextureKey]+lTextureParams);
                            }
                        }
                    }
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "texture_" + sElement + "=" + sTextureShortName, "");
                    if (reMenu) TextureMenu(kID, 0, iNum, sCommand+" "+sElement);
                }
            }
        } else {
            llMessageLinked(LINK_DIALOG,NOTIFY, "0"+"%NOACCESS%",kID);
            llMessageLinked(LINK_ROOT, iNum, "menu Settings", kID);
        }
    }
}

default {

    state_entry() {
        g_kWearer = llGetOwner();
        BuildTexturesList();
        BuildElementsList();
        BuildThemesList();
    }

    on_rez(integer iStart) {
        if (llGetOwner() != g_kWearer) llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID, FALSE,0);
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sID = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sID, "_");
            string sCategory=llGetSubString(sID, 0, i);
            string sToken = llGetSubString(sID, i + 1, -1);
            if (sID == "global_DeviceType") g_sDeviceType = sValue;
            else if (sID == "intern_looks") g_iLooks = (integer)sValue;
            else if (sCategory == "texture_") {
                i = llListFindList(g_lTextureDefaults, [sToken]);
                if (~i) g_lTextureDefaults = llListReplaceList(g_lTextureDefaults, [sValue], i + 1, i + 1);
                else g_lTextureDefaults += [sToken, sValue];
            }
            else if (sCategory == "shininess_") {
                i = llListFindList(g_lShinyDefaults, [sToken]);
                if (~i) g_lShinyDefaults = llListReplaceList(g_lShinyDefaults, [sValue], i + 1, i + 1);
                else g_lShinyDefaults += [sToken, sValue];
            }
            else if (sCategory == "color_") {
                i = llListFindList(g_lColorDefaults, [sToken]);
                if (~i) g_lColorDefaults = llListReplaceList(g_lColorDefaults, [sValue], i + 1, i + 1);
                else g_lColorDefaults += [sToken, sValue];
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (llSubStringIndex(sMenu,"ElementMenu~")==0) {
                    if (sMessage == "BACK") LooksMenu(kAv, iAuth);
                    else {
                        string sMenuType=llList2String(llParseString2List(sMenu,["~"],[]),1);
                        UserCommand(iAuth, sMenuType+" "+sMessage, kAv, TRUE,iPage);
                    }
                } else if ((sMenu == "LooksMenu~menu" || sMenu == "NoThemesMenu") && sMessage == "BACK") llMessageLinked(LINK_ROOT,iAuth,"menu Settings",kAv);
                else if (sMenu == "NoThemesMenu") {
                     if (sMessage == "Uninstall") UserCommand(iAuth,"rm themes",kAv,TRUE,iPage);
                     else LooksMenu(kAv,iAuth);
                } else if (sMenu == "rmThemes") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"The themes plugin has been removed.",kAv);
                        llRemoveInventory(llGetScriptName());
                    } else llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"The themes plugin remains installed.",kAv);
                } else {
                    string sBreadcrumbs=llList2String(llParseString2List(sMenu,["~"],[]),1);
                    string sBackMenu=llList2String(llParseString2List(sBreadcrumbs,[" "],[]),0);
                    if (sMessage == "BACK") {
                        if (~llSubStringIndex(sMenu,"ThemeMenu~themes")) {
                            if (g_iLooks) LooksMenu(kAv, iAuth);
                            else llMessageLinked(LINK_ROOT, iAuth, "menu Settings", kAv);
                        } else  ElementMenu(kAv, 0, iAuth, sBackMenu);
                    }
                    else UserCommand(iAuth,sBreadcrumbs+" "+sMessage, kAv, TRUE,iPage);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    dataserver(key kID, string sData) {
        if (kID==g_kTexturesNotecardRead) {
            if(sData!=EOF) {
                if(llStringTrim(sData,STRING_TRIM) != "" && llGetSubString(sData,0,1) != "//") {
                    list lThisLine=llParseString2List(sData,[","],[]);
                    key kTextureKey=(key)llStringTrim(llList2String(lThisLine,1),STRING_TRIM);
                    string sTextureName=llStringTrim(llList2String(lThisLine,0),STRING_TRIM);
                    string sShortName=llList2String(llParseString2List(sTextureName, ["~"], []), -1);
                    if ( ~llListFindList(g_lTextures,[sTextureName])) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Texture "+sTextureName+" is in the %DEVICETYPE% AND the notecard.  %DEVICETYPE% texture takes priority.",g_kWearer);
                    else if(kTextureKey!=NULL_KEY) {
                        if(llStringLength(sShortName) > 23) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Texture "+sTextureName+" in textures notecard too long, dropping.",g_kWearer);
                        else {
                            g_lTextures+=sTextureName;
                            g_lTextureKeys+=kTextureKey;
                            g_lTextureShortNames+=sShortName;
                        }
                    } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Texture key for "+sTextureName+" in textures notecard not recognised, dropping.",g_kWearer);
                }
                g_kTexturesNotecardRead=llGetNotecardLine(g_sTextureCard,++g_iTexturesNotecardLine);
            }
        } else if (kID==g_kThemesNotecardRead) {
            if(sData != EOF) {
                sData = llStringTrim(sData,STRING_TRIM);
                if(sData != "" && llSubStringIndex(sData,"#") != 0) {
                    if( llGetSubString(sData,0,0) == "[" ){
                        sData = llGetSubString(sData,llSubStringIndex(sData,"[")+1,llSubStringIndex(sData,"]")-1);
                        sData = llStringTrim(sData,STRING_TRIM);
                        if (g_sThemesNotecardReadType == "initialize") {
                            g_lThemes += [sData,g_iThemesNotecardLine];
                        } else if (sData == g_sThemesNotecardReadType) {
                            g_sThemesNotecardReadType = "processing";
                            g_sCurrentTheme = sData;
                        } else if (g_sThemesNotecardReadType == "processing") {
                            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Applied!",g_kSetThemeUser);
                            UserCommand(g_iSetThemeAuth,"themes",g_kSetThemeUser,TRUE,g_iThemePage);
                            return;
                        }
                        g_kThemesNotecardRead = llGetNotecardLine(g_sThemesCard,++g_iThemesNotecardLine);
                    } else {
                        if (g_sThemesNotecardReadType == "processing"){
                            list lParams = llParseStringKeepNulls(sData,["~"],[]);
                            string element = llStringTrim(llList2String(lParams,0),STRING_TRIM);
                            if (element != "") {
                                if (~llSubStringIndex(element,"particle")) {
                                    integer i;
                                    for (i=1; i < llGetListLength(lParams); i=i+2) {
                                        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "particle_"+llList2String(lParams,i)+"="+ llList2String(lParams,i+1), "");
                                        llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, "particle_"+llList2String(lParams,i)+"="+ llList2String(lParams,i+1), "");
                                    }
                                    llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "theme particle sent","");
                                    g_iLeashParticle = TRUE;
                                } else {
                                    list commands = ["texture","color","shiny","glow"];
                                    integer succes;
                                    integer i;
                                    for (i = 1; i < llGetListLength(lParams); i++) {
                                        string substring = llStringTrim(llList2String(lParams,i),STRING_TRIM);
                                        if (substring != "") {
                                            list params = llParseString2List(substring, ["="], []);
                                            string cmd = llList2String(params,0);
                                            sData = llList2String(params,1);
                                            if (llListFindList(commands, [cmd])!=-1) {
                                                UserCommand(g_iSetThemeAuth, cmd+" "+element+" "+sData, g_kSetThemeUser, FALSE,0);
                                                succes++;
                                            }
                                        }
                                    }

                                    if (!succes) {
                                        for (i = 0; i < 4; i++) {
                                            sData = llStringTrim(llList2String(lParams,i+1),STRING_TRIM);
                                            if (sData != "" && sData != ",,") UserCommand(g_iSetThemeAuth, llList2String(commands,i)+" "+element+" "+sData, g_kSetThemeUser, FALSE,0);
                                        }
                                    }
                                }
                            }
                        }
                        g_kThemesNotecardRead=llGetNotecardLine(g_sThemesCard,++g_iThemesNotecardLine);
                    }
                } else g_kThemesNotecardRead=llGetNotecardLine(g_sThemesCard,++g_iThemesNotecardLine);
            } else {
                if (g_sThemesNotecardReadType == "processing") {
                    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Applied!",g_kSetThemeUser);
                    UserCommand(g_iSetThemeAuth,"themes",g_kSetThemeUser,TRUE,g_iThemePage);
                } else g_iThemesReady = TRUE;
            }
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_LINK) BuildElementsList();
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_INVENTORY) {
            if (llGetInventoryType(g_sTextureCard)==INVENTORY_NOTECARD && llGetInventoryKey(g_sTextureCard)!=g_kTextureCardUUID) BuildTexturesList();
            else if (!llGetInventoryType(g_sTextureCard)==INVENTORY_NOTECARD) g_kTextureCardUUID = NULL_KEY;
            if (llGetInventoryType(g_sThemesCard)==INVENTORY_NOTECARD && llGetInventoryKey(g_sThemesCard)!=g_kThemesCardUUID) BuildThemesList();
            else if (!llGetInventoryType(g_sThemesCard)==INVENTORY_NOTECARD) g_kThemesCardUUID = NULL_KEY;
        }
    }
}
