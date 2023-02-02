
//  oc_camera.lsl
//
//  Copyright (c) 2011 - 2016 Nandana Singh, Wendy Starfall, Medea Destiny,
//  littlemousy, Romka Swallowtail, Garvin Twine et al.
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

//allows owner to set different camera mode
//responds to commands from modes list

string g_sAppVersion = "2023.01.04";

key g_kWearer = NULL_KEY;
integer g_iLastNum;
string g_sSubMenu = "Camera";
string g_sParentMenu = "Apps";
key g_kMenuID = NULL_KEY;
string g_sCurrentMode = "default";
float g_fReapeat = 0.5;

//these 4 are used for syncing dom to us by broadcasting cam pos/rot
integer g_iSync2Me;//TRUE if we're currently dumping cam pos/rot iChanges to chat so the owner can sync to us
vector g_vCamPos;
rotation g_rCamRot;
integer g_iBroadChan;
key g_kBroadRcpt = NULL_KEY;

list g_lModes = ["default", "human", "1stperson", "ass", "far", "god", "ground", "worm"];

//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUSTED = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;  // new for safeword

integer NOTIFY = 1002;
//integer SAY = 1004;
integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to settings store
                            //str must be in form of "token=value"
//integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from store
//integer LM_SETTING_EMPTY = 2004;//sent when a token has no value in the settings store

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_CLEAR = 6002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

list g_lMenuIDs;  //menu information
integer g_iMenuStride=3;

string UPMENU = "BACK";

string g_sSettingToken = "camera_";

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex != -1) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex+g_iMenuStride-1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

CamMode(string sMode)
{
    list lMode = [];
    llClearCameraParams();
    if (sMode=="default") {
        lMode = [CAMERA_ACTIVE,FALSE];
    } else if (sMode=="human") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_BEHINDNESS_ANGLE, 0.0,
                CAMERA_BEHINDNESS_LAG, 0.0,
                CAMERA_DISTANCE, 2.5,
                CAMERA_FOCUS_LAG, 0.05,
                CAMERA_POSITION_LOCKED, FALSE,
                CAMERA_FOCUS_THRESHOLD, 0.0,
                CAMERA_PITCH, 20.0,
                CAMERA_POSITION_LAG, 0.0,
                CAMERA_POSITION_THRESHOLD, 0.0,
                CAMERA_FOCUS_OFFSET, <0.0, 0.0, 0.35>];
    } else if (sMode=="1stperson") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_DISTANCE, 0.5,
                CAMERA_FOCUS_OFFSET, <2.5,0,1.0>];
    } else if (sMode=="ass") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_DISTANCE, 0.5];
    } else if (sMode=="far") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_DISTANCE, 10.0];
    } else if (sMode=="god") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_DISTANCE, 10.0,
                CAMERA_PITCH, 80.0];
    } else if (sMode=="ground") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_PITCH, -15.0];
    } else if (sMode=="worm") {
        lMode = [CAMERA_ACTIVE, TRUE,
                CAMERA_PITCH, -15.0,
                CAMERA_FOCUS_OFFSET, <0.0,0.0,-0.75>];
    }    
    if (llGetListLength(lMode) > 0) llSetCameraParams(lMode);
}

ClearCam()
{
    if (llGetPermissions() & PERMISSION_CONTROL_CAMERA) llClearCameraParams();
    g_iLastNum = 0;
    g_iSync2Me = FALSE;
    llMessageLinked(LINK_RLV, RLV_CMD, "camunlock=y", "camera");
    llMessageLinked(LINK_RLV, RLV_CMD, "camdistmax:0=y", "camera");
    llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "all", "");
}

rotation Slerp(rotation a, rotation b, float t)
{
   return llAxisAngle2Rot( llRot2Axis(b /= a), t * llRot2Angle(b)) * a;
}//Written collectively, Taken from http://forums-archive.secondlife.com/54/3b/50692/1.html

CamFocus(vector g_vCamPos, rotation g_rCamRot)
{
    vector vStartPose = llGetCameraPos();
    rotation rStartRot = llGetCameraRot();
    float fSteps = 8.0;
    //Keep fSteps a float, but make sure its rounded off to the nearest 1.0
    fSteps = (float)llRound(fSteps);
    //Calculate camera position increments
    vector vPosStep = (g_vCamPos - vStartPose) / fSteps;
    //Calculate camera rotation increments
    //rotation rStep = (g_rCamRot - rStartRot);
    //rStep = <rStep.x / fSteps, rStep.y / fSteps, rStep.z / fSteps, rStep.s / fSteps>;
    float fCurrentStep = 0.0; //Loop through motion for fCurrentStep = current step, while fCurrentStep <= Total steps
    for(fCurrentStep = 0.0; fCurrentStep <= fSteps; ++fCurrentStep) {
        //Set next position in tween
        vector vNextPos = vStartPose + (vPosStep * fCurrentStep);
        rotation rNextRot = Slerp(rStartRot, g_rCamRot, fCurrentStep / fSteps);
         //Set camera parameters
        llSetCameraParams([
            CAMERA_ACTIVE, 1, //1 is active, 0 is inactive
            CAMERA_BEHINDNESS_ANGLE, 0.0, //(0 to 180) degrees
            CAMERA_BEHINDNESS_LAG, 0.0, //(0 to 3) seconds
            CAMERA_DISTANCE, 0.0, //(0.5 to 10) meters
            CAMERA_FOCUS, vNextPos + llRot2Fwd(rNextRot), //Region-relative position
            CAMERA_FOCUS_LAG, 0.0 , //(0 to 3) seconds
            CAMERA_FOCUS_LOCKED, TRUE, //(TRUE or FALSE)
            CAMERA_FOCUS_THRESHOLD, 0.0, //(0 to 4) meters
            CAMERA_POSITION, vNextPos, //Region-relative position
            CAMERA_POSITION_LAG, 0.0, //(0 to 3) seconds
            CAMERA_POSITION_LOCKED, TRUE, //(TRUE or FALSE)
            CAMERA_POSITION_THRESHOLD, 0.0, //(0 to 4) meters
            CAMERA_FOCUS_OFFSET, ZERO_VECTOR //<-10,-10,-10> to <10,10,10> meters
        ]);
    }
   // Debug("Focus set");
}

LockCam()
{
    llSetCameraParams([
        CAMERA_ACTIVE, TRUE,
        CAMERA_POSITION_LOCKED, TRUE
    ]);
    llMessageLinked(LINK_RLV, RLV_CMD, "camunlock=n", "camera");
}

CamMenu(key kID, integer iAuth)
{
    string sPrompt = "\nCamera\t"+g_sAppVersion+"\n\nCurrent camera mode is " + g_sCurrentMode + ".\n\nNOTE: Full functionality only on RLV API v2.9 and greater.";
    list lButtons = ["CLEAR","FREEZE","MOUSELOOK"];
    integer n;
    lButtons += g_lModes;
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "camera");
}

string Capitalize(string sIn)
{
    return llToUpper(llGetSubString(sIn, 0, 0)) + llGetSubString(sIn, 1, -1);
}

SaveSetting(string sToken)
{
    //Debug("last mode: "+g_sCurrentMode);
    llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + g_sCurrentMode, "");
    g_sCurrentMode = sToken;
    sToken = g_sSettingToken + sToken;
    string sValue = (string)g_iLastNum;
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, sToken + "=" + sValue, "");
}

ChatCamParams(integer iChannel, key kID)
{
    g_vCamPos = llGetCameraPos();
    g_rCamRot = llGetCameraRot();
    string sPosLine = llReplaceSubString((string)g_vCamPos, " ", "", 0) + " " +
        llReplaceSubString((string)g_rCamRot, " ", "", 0);


    //if not channel 0, say to whole region.  else just say locally
    if (iChannel > 0)
        llRegionSayTo(kID, iChannel, sPosLine);
    else
        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+sPosLine,kID);
}

// here iNum: auth value, sStr: user command, kID: avatar id
UserCommand(integer iNum, string sStr, key kID)
{
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    string sValue2 = llList2String(lParams, 2);
    if (sStr == "menu " + g_sSubMenu)
        CamMenu(kID, iNum);
    else if (sCommand == "cam" || sCommand == "camera") {
        //Debug("g_iLastNum=" + (string)g_iLastNum);
        if (sValue == "")//they just said *cam.  give menu
            CamMenu(kID, iNum);
        else if (!(llGetPermissions() & PERMISSION_CONTROL_CAMERA))
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
        else if (g_iLastNum && iNum > g_iLastNum)
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Sorry, cam settings have already been set by someone outranking you.", kID);
        else if (sValue == "clear") {
            ClearCam();
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Cleared camera settings.", kID);
        } else if (sValue == "freeze") {
            LockCam();
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Freezing current camera position.", kID);
            g_iLastNum = iNum;
            SaveSetting("freeze");
        } else if (sValue == "mouselook") {
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Enforcing mouselook.", kID);
            g_iLastNum = iNum;
            llMessageLinked(LINK_RLV, RLV_CMD, "camdistmax:0=n", "camera");
            SaveSetting("mouselook");
            //Debug("newiNum=" + (string)iNum);
        } else {
            integer iIndex = llListFindList(g_lModes, [sValue]);
            if (iIndex != -1) {
                CamMode(sValue);
                g_iLastNum = iNum;
                llMessageLinked(LINK_RLV, RLV_CMD, "camunlock=n", "camera");
                llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Set " + sValue + " camera mode.", kID);
                SaveSetting(sValue);
            } else
                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Invalid camera mode: " + sValue, kID);
        }
    } else if (sCommand == "camto") {
        if (g_iLastNum == 0 || iNum <= g_iLastNum) {
            CamFocus((vector)sValue, (rotation)sValue2);
            g_iLastNum = iNum;
        } else
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Sorry, cam settings have already been set by someone outranking you.", kID);
    } else if (sCommand == "camdump") {
        g_iBroadChan = (integer)sValue;
        integer g_fReapeat = (integer)sValue2;
        ChatCamParams(g_iBroadChan, kID);
        if (g_fReapeat) {
            g_kBroadRcpt = kID;
            g_iSync2Me = TRUE;
            llSetTimerEvent(g_fReapeat);
        }
    } else if (sStr == "rm camera") {
            if (kID != g_kWearer && iNum != CMD_OWNER) llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kID);
            else Dialog(kID, "\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes","No","Cancel"], [], 0, iNum,"rmcamera");
    } else if ((iNum == CMD_OWNER  || kID == g_kWearer) && sStr == "runaway") {
        ClearCam();
        //llResetScript();
    }
   // Debug(sCommand+" executed");
}

default
{
    on_rez(integer iNum)
    {
        llResetScript();
    }

    state_entry()
    {
        g_kWearer = llGetOwner();
        if (llGetAttached()) llRequestPermissions(g_kWearer, PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA);
    }

    run_time_permissions(integer iPerms)
    {
        if (iPerms & (PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA))
            llClearCameraParams();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //only respond to owner, secowner, group, wearer
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == CMD_SAFEWORD || iNum == RLV_CLEAR) {
            ClearCam();
            //llResetScript();
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["=", ","], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (llGetPermissions() & PERMISSION_CONTROL_CAMERA) {
                    if (sToken == "freeze") LockCam();
                    else if (sToken == "mouselook") llMessageLinked(LINK_RLV, RLV_CMD, "camdistmax:0=n", "camera");
                    else if (llListFindList(g_lModes, [sToken]) != -1) CamMode(sToken);
                    g_iLastNum = (integer)sValue;
                }
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                // integer iPage = llList2Integer(lMenuParams, 2);
                integer iAuth = llList2Integer(lMenuParams, 3);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenuType == "camera") {
                    if (sMessage == UPMENU)
                        llMessageLinked(LINK_ROOT, iAuth, "menu " + g_sParentMenu, kAv);
                    else {
                        UserCommand(iAuth, "cam " + llToLower(sMessage), kAv);
                        CamMenu(kAv, iAuth);
                    }
                } else if (sMenuType == "rmcamera") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_ROOT, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kAv);
                        llRemoveInventory(llGetScriptName());
                    } else llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kAv);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    timer()
    {
        //handle cam pos/rot changes
        if (g_iSync2Me) {
            vector vNewPos = llGetCameraPos();
            rotation rNewRot = llGetCameraRot();
            if (vNewPos != g_vCamPos || rNewRot != g_rCamRot)
                ChatCamParams(g_iBroadChan,g_kBroadRcpt);
        } else {
            g_kBroadRcpt = NULL_KEY;
            llSetTimerEvent(0.0);
        }
    }

}
