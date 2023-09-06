
//  oc_particle.lsl
//
//  Copyright (c) 2008 - 2017 Lulu Pink, Nandana Singh, Garvin Twine,
//  Cleo Collins, Satomi Ahn, Joy Stipe, Wendy Starfall, Romka Swallowtail,
//  littlemousy et al.
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

integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_WEARER = 503;

integer NOTIFY = 1002;

integer REBOOT = -1000;
integer LINK_DIALOG = 3;

integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer LOCKMEISTER = -8888;
integer g_iLMListener;
integer g_iLMListernerDetach;

integer CMD_PARTICLE = 20000;

string UPMENU = "BACK";
string PARENTMENU = "Leash";
string SUBMENU = "Configure";
string L_COLOR = "Color";
string L_GRAVITY = "Gravity";
string L_SIZE = "Size";
string L_FEEL = "Feel";
string L_GLOW = "Shine";
string L_STRICT = "Strict";
string L_TURN = "Turn";
string L_DEFAULTS = "RESET";
string L_CLASSIC_TEX = "Chain";
string L_RIBBON_TEX = "Silk";
list g_lDefaultSettings = ["Shine","1","Turn","0","Strict","0","ParticleMode","Classic","R_Texture","Silk","C_Texture","Chain","Color","<1.0,1.0,1.0>","Size","<0.04,0.04,1.0>","Gravity","-1.0"];

//list g_lSettings=g_lDefaultSettings;
list g_lSettings = ["Shine","1","Turn","0","Strict","0","ParticleMode","Ribbon","R_Texture","Silk","C_Texture","Chain","Color","<1.0,1.0,1.0>","Size","<0.04,0.04,1.0>","Gravity","-1.0"];

list g_lMenuIDs;
integer g_iMenuStride = 3;
key g_kWearer;

key g_kLeashedTo = NULL_KEY;
key g_kLeashToPoint = NULL_KEY;
key g_kParticleTarget = NULL_KEY;

integer g_iLeashActive;
integer g_iTurnMode;
integer g_iStrictMode;
integer g_iStrictRank;
string g_sParticleMode = "Classic";
string g_sRibbonTexture;
string g_sClassicTexture;
list g_lLeashPrims;

integer g_iLoop;
string g_sSettingToken = "particle_";


string g_sParticleTexture = "Chain";
string g_sParticleTextureID;
vector g_vLeashColor = <1.00000, 1.00000, 1.00000>;
vector g_vLeashSize = <0.04, 0.04, 1.0>;
integer g_iParticleGlow = TRUE;
float g_fParticleAge = 3.5;
vector g_vLeashGravity = <0.0,0.0,-1.0>;
integer g_iParticleCount = 1;
float g_fBurstRate = 0.0;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenuName)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex != -1)
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sMenuName], iIndex, iIndex + g_iMenuStride-1);
    else
        g_lMenuIDs += [kID, kMenuID, sMenuName];
}

FindLinkedPrims()
{
    integer linkcount = llGetNumberOfPrims();
    for (g_iLoop = 2; g_iLoop <= linkcount; g_iLoop++) {
        string sPrimDesc = (string)llGetObjectDetails(llGetLinkKey(g_iLoop), [OBJECT_DESC]);
        list lTemp = llParseString2List(sPrimDesc, ["~"], []);
        integer iLoop;
        for (iLoop = 0; iLoop < llGetListLength(lTemp); iLoop++) {
            string sTest = llList2String(lTemp, iLoop);
            if (llGetSubString(sTest, 0, 9) == "leashpoint") {
                if (llGetSubString(sTest, 11, -1) == "") g_lLeashPrims += [sTest, (string)g_iLoop, "1"];
                else g_lLeashPrims += [llGetSubString(sTest, 11, -1), (string)g_iLoop, "1"];
            }
        }
    }
    if (llGetListLength(g_lLeashPrims) == 0) g_lLeashPrims = ["collar", LINK_THIS, "1"];
    else llMessageLinked(LINK_ROOT, LM_SETTING_RESPONSE,"leashpoint="+llList2String(g_lLeashPrims,1) ,"");
}

Particles(integer iLink, key kParticleTarget)
{
    if (kParticleTarget == NULL_KEY) return;
    integer iFlags = PSYS_PART_FOLLOW_VELOCITY_MASK | PSYS_PART_TARGET_POS_MASK | PSYS_PART_FOLLOW_SRC_MASK;
    if (g_sParticleMode == "Ribbon") iFlags = iFlags | PSYS_PART_RIBBON_MASK;
    if (g_iParticleGlow) iFlags = iFlags | PSYS_PART_EMISSIVE_MASK;
    list lTemp = [
        PSYS_PART_MAX_AGE,g_fParticleAge,
        PSYS_PART_FLAGS,iFlags,
        PSYS_PART_START_COLOR, g_vLeashColor,
        PSYS_PART_START_SCALE,g_vLeashSize,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
        PSYS_SRC_BURST_RATE,g_fBurstRate,
        PSYS_SRC_ACCEL, g_vLeashGravity,
        PSYS_SRC_BURST_PART_COUNT,g_iParticleCount,
        PSYS_SRC_TARGET_KEY,kParticleTarget,
        PSYS_SRC_MAX_AGE, 0,
        PSYS_SRC_TEXTURE, g_sParticleTextureID
        ];
    llLinkParticleSystem(iLink, lTemp);
}

StartParticles(key kParticleTarget)
{
    StopParticles(FALSE);
    if (g_sParticleMode == "noParticle") return;
    else if (g_sParticleMode == "Ribbon") {
        // Use all leashpoints
        for (g_iLoop = 0; g_iLoop < llGetListLength(g_lLeashPrims); g_iLoop = g_iLoop + 3) {
            if ((integer)llList2String(g_lLeashPrims, g_iLoop+2)) {
                Particles((integer)llList2String(g_lLeashPrims, g_iLoop+1), kParticleTarget);
            }
        }
    } else {
        // Only use first leashpoint
        Particles((integer)llList2String(g_lLeashPrims, 1), kParticleTarget);
    }
    g_iLeashActive = TRUE;
}

StopParticles(integer iEnd)
{
    for (g_iLoop = 0; g_iLoop < llGetListLength(g_lLeashPrims); g_iLoop++)
        llLinkParticleSystem((integer)llList2String(g_lLeashPrims, g_iLoop+1), []);
    if (iEnd > 0) {
        g_iLeashActive = FALSE;
        g_kLeashedTo = NULL_KEY;
        g_kLeashToPoint = NULL_KEY;
        g_kParticleTarget = NULL_KEY;
        llSetTimerEvent(0.0);
    }
}

string Vec2String(vector vVec)
{
    list lParts = [vVec.x, vVec.y, vVec.z];
    for (g_iLoop = 0; g_iLoop < 3; g_iLoop++) {
        string sStr = llList2String(lParts, g_iLoop);
        while (llSubStringIndex(sStr, ".") != -1 && (llGetSubString(sStr, -1, -1) == "0"
            || llGetSubString(sStr, -1, -1) == "."))
            sStr = llGetSubString(sStr, 0, -2);
        lParts = llListReplaceList(lParts, [sStr], g_iLoop, g_iLoop);
    }
    return "<" + llDumpList2String(lParts, ",") + ">";
}

string Float2String(float in)
{
    string out = (string)in;
    integer i = llSubStringIndex(out, ".");
    while (i >= 0 && llStringLength(llGetSubString(out, i + 2, -1)) && llGetSubString(out, -1, -1) == "0") {
        out = llGetSubString(out, 0, -2);
    }
    return out;
}

SaveSettings(string sToken, string sValue, integer iSaveToLocal)
{
    integer iIndex = llListFindList(g_lSettings, [sToken]);
    if (iIndex != -1) g_lSettings = llListReplaceList(g_lSettings, [sValue], iIndex +1, iIndex +1);
    else g_lSettings += [sToken, sValue];

    if (sToken == "R_Texture") {
        if (llToLower(llGetSubString(sValue, 0, 6)) == "!ribbon") L_RIBBON_TEX = llGetSubString(sValue, 8, -1);
        else L_RIBBON_TEX = sValue;
    }
    else if (sToken == "C_Texture") {
        if (llToLower(llGetSubString(sValue, 0, 7)) == "!classic") L_CLASSIC_TEX = llGetSubString(sValue, 9, -1);
        else L_CLASSIC_TEX = sValue;
    }
    if (iSaveToLocal) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + sToken + "=" + sValue, "");
}

string GetDefaultSetting(string sToken)
{
    integer index = llListFindList(g_lDefaultSettings, [sToken]);
    if (index != -1) return llList2String(g_lDefaultSettings, index+1);
    else return "";
}

string GetSetting(string sToken)
{
    integer index = llListFindList(g_lSettings, [sToken]);
    if (index != -1) return llList2String(g_lSettings, index+1);
    else return GetDefaultSetting(sToken);
}

GetSettings(integer iStartParticles)
{
    g_sParticleMode = GetSetting("ParticleMode");
    g_sClassicTexture = GetSetting("C_Texture");
    g_sRibbonTexture = GetSetting("R_Texture");
    g_vLeashSize = (vector)GetSetting(L_SIZE);
    g_vLeashColor = (vector)GetSetting(L_COLOR);
    g_vLeashGravity.z = (float)GetSetting(L_GRAVITY);
    g_iParticleGlow = (integer)GetSetting(L_GLOW);
    if (g_sParticleMode == "Classic") SetTexture(g_sClassicTexture, NULL_KEY);
    else if (g_sParticleMode == "Ribbon") SetTexture(g_sRibbonTexture, NULL_KEY);
    if (iStartParticles && g_kLeashedTo != NULL_KEY){
        llSleep(0.1);
        StartParticles(g_kParticleTarget);
    }
}

SetTexture(string sIn, key kIn)
{
    g_sParticleTexture = sIn;
    if (sIn=="Silk") g_sParticleTextureID = "leash_silk";
    else if (sIn=="Chain") g_sParticleTextureID = "leash_chain";
    else if (sIn=="Leather") g_sParticleTextureID = "leash_leather";
    else if (sIn=="Rope") g_sParticleTextureID = "leash_rope";
    else if (sIn=="totallytransparent") g_sParticleTextureID = TEXTURE_TRANSPARENT;
    else {
        if (llToLower(g_sParticleTexture) == "noleash") g_sParticleMode = "noParticle";
        g_sParticleTextureID = llGetInventoryKey(g_sParticleTexture);
        if(g_sParticleTextureID == NULL_KEY) g_sParticleTextureID = sIn;
    }
    if (g_sParticleMode == "Ribbon") {
        if (llToLower(llGetSubString(sIn,0,6)) == "!ribbon") L_RIBBON_TEX = llGetSubString(sIn, 8, -1);
        else L_RIBBON_TEX = sIn;
        if (GetSetting("R_TextureID")) g_sParticleTextureID = GetSetting("R_TextureID");
        if (kIn != NULL_KEY)
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Leash texture set to " + L_RIBBON_TEX, kIn);
    }
    else if (g_sParticleMode == "Classic") {
        if (llToLower(llGetSubString(sIn,0,7)) == "!classic") L_CLASSIC_TEX = llGetSubString(sIn, 9, -1);
        else L_CLASSIC_TEX = sIn;
        if (GetSetting("C_TextureID")) g_sParticleTextureID = GetSetting("C_TextureID");
        if (kIn != NULL_KEY) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Leash texture set to " + L_CLASSIC_TEX, kIn);
    } else  if (kIn != NULL_KEY) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Leash texture set to " + g_sParticleTexture, kIn);
    if (g_iLeashActive) {
        if (g_sParticleMode == "noParticle") StopParticles(FALSE);
        else StartParticles(g_kParticleTarget);
    }
}

ConfigureMenu(key kIn, integer iAuth)
{
    list lButtons;
    if (g_iParticleGlow) lButtons += "☑ Shine";
    else lButtons += "☐ Shine";
    if (g_iTurnMode) lButtons += "☑ Turn";
    else lButtons += "☐ Turn";
    if (g_iStrictMode) lButtons += "☑ Strict";
    else lButtons += "☐ Strict";
    if (g_sParticleMode == "Ribbon") lButtons += ["☐ "+L_CLASSIC_TEX,"☒ "+L_RIBBON_TEX,"☐ Invisible"];
    else if (g_sParticleMode == "noParticle") lButtons += ["☐ "+L_CLASSIC_TEX,"☐ "+L_RIBBON_TEX,"☒ Invisible"];
    else if (g_sParticleMode == "Classic")  lButtons += ["☒ "+L_CLASSIC_TEX,"☐ "+L_RIBBON_TEX,"☐ Invisible"];

    lButtons += [L_FEEL, L_COLOR];
    string sPrompt = "\nLeash Configuration\n\nCustomize the looks and feel of your leash.";
    Dialog(kIn, sPrompt, lButtons, [UPMENU], 0, iAuth,"configure");
}

FeelMenu(key kIn, integer iAuth)
{
    list lButtons = ["Bigger", "Smaller", L_DEFAULTS, "Heavier", "Lighter"];
    string sPrompt = "\nHere you can change the weight and size of your leash.";
    Dialog(kIn, sPrompt, lButtons, [UPMENU], 0, iAuth,"feel");
}

ColorMenu(key kIn, integer iAuth, integer iPage)
{
    string sPrompt = "\nChoose a color.";
    Dialog(kIn, sPrompt, ["colormenu please"], [UPMENU], iPage, iAuth,"color");
}

LMSay()
{
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) + "collar");
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) + "handle");
    llSetTimerEvent(4.0);
}

default
{
    on_rez(integer iRez)
    {
        llResetScript();
    }

    state_entry()
    {
        g_kWearer = llGetOwner();
        FindLinkedPrims();
        StopParticles(TRUE);
        GetSettings(FALSE);
    }

    link_message(integer iSender, integer iNum, string sMessage, key kMessageID)
    {
        if (iNum == CMD_PARTICLE) {
            g_kLeashedTo = kMessageID;
            if (sMessage == "unleash") {
                StopParticles(TRUE);
                llListenRemove(g_iLMListener);
                llListenRemove(g_iLMListernerDetach);
            } else {
                if (g_sParticleMode != "noParticle") {
                    integer bLeasherIsAv = (integer)llList2String(llParseString2List(sMessage, ["|"], [""]), 1);
                    g_kParticleTarget = g_kLeashedTo;
                    StartParticles(g_kParticleTarget);
                    if (bLeasherIsAv) {
                        llListenRemove(g_iLMListener);
                        llListenRemove(g_iLMListernerDetach);
                        if (llGetSubString(sMessage, 0, 10)  == "leashhandle") {
                            g_iLMListener = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle ok");
                            g_iLMListernerDetach = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle detached");
                        } else  g_iLMListener = llListen(LOCKMEISTER, "", "", "");
                        LMSay();
                    }
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            if (llToLower(sMessage) == "leash configure") {
                if(iNum <= CMD_TRUSTED || iNum==CMD_WEARER) ConfigureMenu(kMessageID, iNum);
                else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kMessageID);
            } else if (sMessage == "menu "+SUBMENU) {
                if(iNum <= CMD_TRUSTED || iNum==CMD_WEARER) ConfigureMenu(kMessageID, iNum);
                else {
                    llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kMessageID);
                    llMessageLinked(LINK_THIS, iNum, "menu "+PARENTMENU, kMessageID);
                }
            } else if (llToLower(sMessage) == "particle reset") {
                g_lSettings = [];
                if (kMessageID != NULL_KEY) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Leash-settings restored to %DEVICETYPE% defaults.",kMessageID);
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "all", "");
                GetSettings(TRUE);
            } else if (llToLower(sMessage) == "theme particle sent")
                GetSettings(TRUE);
        } else if (iNum == MENUNAME_REQUEST && sMessage == PARENTMENU)
            llMessageLinked(iSender, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, "");
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            if (iMenuIndex != -1) {
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sButton = llList2String(lMenuParams, 1);
                integer iPage = llList2Integer(lMenuParams, 2);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);
                if (sButton == UPMENU) {
                    if(sMenu == "configure") llMessageLinked(LINK_THIS, iAuth, "menu "+PARENTMENU, kAv);
                    else ConfigureMenu(kAv, iAuth);
                } else  if (sMenu == "configure") {
                    string sButtonType = llGetSubString(sButton, 2, -1);
                    string sButtonCheck = llGetSubString(sButton,0,0);
                    if (sButton == L_COLOR) {
                        ColorMenu(kAv, iAuth,0);
                        return;
                    } else if (sButton == "Feel") {
                        FeelMenu(kAv, iAuth);
                        return;
                    } else if(sButtonType == L_GLOW) {
                        if (sButtonCheck == "☐") g_iParticleGlow = TRUE;
                        else g_iParticleGlow = FALSE;
                        SaveSettings(sButtonType, (string)g_iParticleGlow, TRUE);
                    } else if(sButtonType == L_TURN) {
                        if (sButtonCheck == "☐") g_iTurnMode = TRUE;
                        else g_iTurnMode = FALSE;
                        if (g_iTurnMode) llMessageLinked(LINK_THIS, iAuth, "turn on", kAv);
                        else llMessageLinked(LINK_THIS, iAuth, "turn off", kAv);
                    } else if(sButtonType == L_STRICT) {
                        if (sButtonCheck == "☐") {
                            g_iStrictMode = TRUE;
                            g_iStrictRank = iAuth;
                            llMessageLinked(LINK_THIS, iAuth, "strict on", kAv);
                        } else if (iAuth <= g_iStrictRank) {
                            g_iStrictMode = FALSE;
                            g_iStrictRank = iAuth;
                            llMessageLinked(LINK_THIS, iAuth, "strict off", kAv);
                        } else llMessageLinked(LINK_DIALOG, NOTIFY,"0%NOACCESS%",kAv);
                    } else if(sButtonType == L_RIBBON_TEX) {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        } else {
                            g_sParticleMode = "Classic";
                            SetTexture(g_sClassicTexture, kAv);
                            SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        }
                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    } else if(sButtonType == L_CLASSIC_TEX) {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "Classic";
                            SetTexture(g_sClassicTexture, kAv);
                            SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        } else {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        }
                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    } else if(sButtonType == "Invisible") {
                        if (sButtonCheck == "☐") {
                            g_sParticleMode = "noParticle";
                            g_sParticleTexture = "noleash";
                            SetTexture("noleash", kAv);
                        } else {
                            g_sParticleMode = "Ribbon";
                            SetTexture(g_sRibbonTexture, kAv);
                            SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        }
                        SaveSettings("ParticleMode", g_sParticleMode, TRUE);
                    }
                    if (g_sParticleMode != "noParticle" && g_iLeashActive) StartParticles(g_kParticleTarget);
                    else if (g_iLeashActive) StopParticles(FALSE);
                    else StopParticles(TRUE);
                    ConfigureMenu(kAv, iAuth);
                } else if (sMenu == "color") {
                    g_vLeashColor = (vector)sButton;
                    SaveSettings(L_COLOR, sButton, TRUE);
                    if (g_sParticleMode != "noParticle" && g_iLeashActive) StartParticles(g_kParticleTarget);
                    ColorMenu(kAv, iAuth,iPage);
                } else if (sMenu == "feel") {
                    if (sButton == L_DEFAULTS) {
                        if (g_sParticleMode == "Ribbon") g_vLeashSize = (vector)GetDefaultSetting(L_SIZE);
                        else g_vLeashSize = (vector)GetDefaultSetting(L_SIZE) + <0.03,0.03,0.0>;
                        g_vLeashGravity.z = (float)GetDefaultSetting(L_GRAVITY);
                     } else if (sButton == "Bigger") {
                        g_vLeashSize.x +=0.03;
                        g_vLeashSize.y +=0.03;
                    } else if (sButton == "Smaller") {
                        g_vLeashSize.x -=0.03;
                        g_vLeashSize.y -=0.03;
                        if (g_vLeashSize.x < 0.04 && g_vLeashSize.y < 0.04) {
                            g_vLeashSize.x = 0.04 ;
                            g_vLeashSize.y = 0.04 ;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"The leash won't get much smaller.", kAv);
                        }
                    } else if (sButton == "Heavier") {
                        g_vLeashGravity.z -= 0.1;
                        if (g_vLeashGravity.z < -3.0) {
                            g_vLeashGravity.z = -3.0;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"That's the heaviest it can be.", kAv);
                        }
                    } else if (sButton == "Lighter") {
                        g_vLeashGravity.z += 0.1;
                        if (g_vLeashGravity.z > 0.0) {
                            g_vLeashGravity.z = 0.0 ;
                            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"It can't get any lighter now.", kAv);
                        }
                    }
                    SaveSettings(L_GRAVITY, Float2String(g_vLeashGravity.z), TRUE);
                    SaveSettings(L_SIZE, Vec2String(g_vLeashSize), TRUE);
                    if (g_sParticleMode != "noParticle" && g_iLeashActive) StartParticles(g_kParticleTarget);
                    FeelMenu(kAv, iAuth);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kMessageID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LM_SETTING_RESPONSE) {
            integer i = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, i - 1);
            string sValue = llGetSubString(sMessage, i + 1, -1);
            i = llSubStringIndex(sToken, "_");
            if (sToken == "leash_leashedto") g_kLeashedTo = llList2Key(llParseString2List(sValue, [","], []), 0);
            else if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                SaveSettings(sToken, sValue, FALSE);
            } else if (llGetSubString(sToken, 0, i) == "leash_") {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "strict") {
                    g_iStrictMode = (integer)llGetSubString(sValue,0,0);
                    g_iStrictRank = (integer)llGetSubString(sValue,2,-1);
                } else if (sToken == "turn") {
                    g_iTurnMode = (integer)sValue;
                }
            }
            else if (sMessage == "settings=sent" || sMessage == "theme particle sent")
                GetSettings(TRUE);
        } else if (iNum == LINK_UPDATE) {
            if (sMessage == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sMessage == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sMessage == "reboot") llResetScript();
    }

    timer()
    {
        if (llGetOwnerKey(g_kParticleTarget) == g_kParticleTarget) {
            if (g_kLeashedTo != NULL_KEY) {
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
                llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo+"|LMV2|RequestPoint|collar");
            }
            else if(g_iLeashActive == FALSE) llSetTimerEvent(0.0);
        }
    }

    listen(integer iChannel, string sName, key kID, string sMessage)
    {
        if (iChannel == LOCKMEISTER) {
            if (sMessage == (string)g_kLeashedTo + "handle detached") {
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
                llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo+"|LMV2|RequestPoint|collar");
            }
            if (llGetOwnerKey(kID) == g_kLeashedTo) {
                if(llGetSubString(sMessage, -2, -1) == "ok") {
                    sMessage = llGetSubString(sMessage, 36, -1);
                    if (sMessage == "collar ok") {
                        g_kParticleTarget = kID;
                        StartParticles(g_kParticleTarget);
                        llRegionSayTo(g_kLeashedTo, LOCKMEISTER, (string)g_kLeashedTo+"|LMV2|RequestPoint|collar");
                    }
                    if (sMessage == "handle ok") {
                        g_kParticleTarget = kID;
                        StartParticles(g_kParticleTarget);
                    }
                }  else {
                    list lTemp = llParseString2List(sMessage,["|"],[""]);
                    if(llList2String(lTemp, 1) == "LMV2" && llList2String(lTemp,2) == "ReplyPoint") {
                        g_kParticleTarget = llList2Key(lTemp,4);
                        StartParticles(g_kParticleTarget);
                    }
                }
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY) {
            integer iNumberOfTextures = llGetInventoryNumber(INVENTORY_TEXTURE);
            integer iLeashTexture;
            if (iNumberOfTextures) {
                for (g_iLoop = 0; g_iLoop < iNumberOfTextures; ++g_iLoop) {
                    string sName = llGetInventoryName(INVENTORY_TEXTURE, g_iLoop);
                    if (llToLower(llGetSubString(sName,0,6)) == "!ribbon") {
                        g_sRibbonTexture = sName;
                        L_RIBBON_TEX = llGetSubString(g_sRibbonTexture, 8, -1);
                        SaveSettings("R_Texture", g_sRibbonTexture, TRUE);
                        iLeashTexture = iLeashTexture+1;
                    }
                    else if (llToLower(llGetSubString(sName,0,7)) == "!classic") {
                        g_sClassicTexture = sName;
                        L_CLASSIC_TEX = llGetSubString(g_sClassicTexture, 9, -1);
                        SaveSettings("C_Texture", g_sClassicTexture, TRUE);
                        iLeashTexture = iLeashTexture+2;
                    }
                }
            }
            if (iLeashTexture == FALSE) {
                if (llSubStringIndex(GetSetting("C_Texture"), "!")==0) SaveSettings("C_Texture", "Chain", TRUE);
                if (llSubStringIndex(GetSetting("R_Texture"), "!")==0) SaveSettings("R_Texture", "Silk", TRUE);
            } else if (iLeashTexture == 1) {
                if (llSubStringIndex(GetSetting("C_Texture"), "!")==0) SaveSettings("C_Texture", "Chain", TRUE);
            } else if (iLeashTexture == 2) {
                if (llSubStringIndex(GetSetting("R_Texture"), "!")==0) SaveSettings("R_Texture", "Silk", TRUE);
            }
        }
    }

}
