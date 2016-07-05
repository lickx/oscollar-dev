////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenCollar - camera                               //
//                                 version 3.996                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2016  Individual Contributors and OpenCollar - submission set free™ //
// ------------------------------------------------------------------------------ //
//                    github.com/OpenCollar/OpenCollarUpdater                     //
// ------------------------------------------------------------------------------ //
////////////////////////////////////////////////////////////////////////////////////

//allows owner to set different camera mode
//responds to commands from modes list

key g_kWearer;
integer g_iLastNum;
string g_sSubMenu = "Camera";
string g_sParentMenu = "Apps";
key g_kMenuID;
string g_sCurrentMode = "default";
float g_fReapeat = 0.5;

//these 4 are used for syncing dom to us by broadcasting cam pos/rot
integer g_iSync2Me;//TRUE if we're currently dumping cam pos/rot iChanges to chat so the owner can sync to us
vector g_vCamPos;
rotation g_rCamRot;
integer g_rBroadChan;

string g_sJsonModes;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer COMMAND_BLACKLIST = 520;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to settings store
                            //str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from store
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value in the settings store

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_CLEAR = 6002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";
//string MORE = ">";
string g_sScript;

/*
integer g_iProfiled;
Debug(string sStr) {
    //if you delete the first // from the preceeding and following  lines,
    //  profiling is off, debug is off, and the compiler will remind you to 
    //  remove the debug calls from the code, we're back to production mode
    if (!g_iProfiled){
        g_iProfiled=1;
        llScriptProfiler(1);
    }
    llOwnerSay(llGetScriptName() + "(min free:"+(string)(llGetMemoryLimit()-llGetSPMaxMemory())+")["+(string)llGetFreeMemory()+"] :\n" + sStr);
}
*/

//changed the mode handles to a Json object with json arrays, one issue remains:
//vectors get converted into strings and need to be reconverted to vectors. 
//For this to work easiest seems to just put for any mode which contains a vector,
//the vector as last entry (if there shall be a mode which contains 2 vectors, 
//this needs to be addressed and handles as excetion in the list lJsonModes function
string JsonModes() {
    // Opensim bug: The original constants can't be used in llList2Json so we manually
    // define them as constants
    // As defined here: http://wiki.secondlife.com/wiki/LlSetCameraParams
    // Opensim bug report: http://opensimulator.org/mantis/view.php?id=7957
    integer _CAMERA_PITCH = 0;
    integer _CAMERA_FOCUS_OFFSET = 1;
    integer _CAMERA_POSITION_LAG = 5;
    integer _CAMERA_FOCUS_LAG = 6;
    integer _CAMERA_DISTANCE = 7;
    integer _CAMERA_BEHINDNESS_ANGLE = 8;
    integer _CAMERA_BEHINDNESS_LAG = 9;
    integer _CAMERA_POSITION_THRESHOLD = 10;
    integer _CAMERA_FOCUS_THRESHOLD = 11;
    integer _CAMERA_ACTIVE = 12;
    integer _CAMERA_POSITION = 13;
    integer _CAMERA_FOCUS = 17;
    integer _CAMERA_POSITION_LOCKED = 21;
    integer _CAMERA_FOCUS_LOCKED = 22;

    string sDefault =   llList2Json(JSON_ARRAY, [_CAMERA_ACTIVE,FALSE]);
    string sHuman =     llList2Json(JSON_ARRAY, [_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_BEHINDNESS_ANGLE,0.0,
                                                _CAMERA_BEHINDNESS_LAG,0.0,
                                                _CAMERA_DISTANCE,2.5,
                                                _CAMERA_FOCUS_LAG,0.05,
                                                _CAMERA_POSITION_LOCKED,FALSE,
                                                _CAMERA_FOCUS_THRESHOLD,0.0,
                                                _CAMERA_PITCH,20.0,
                                                _CAMERA_POSITION_LAG,0.0,
                                                _CAMERA_POSITION_THRESHOLD,0.0,
                                                _CAMERA_FOCUS_OFFSET,<0.0, 0.0, 0.35>]);
    string s1stperson = llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_DISTANCE, 0.5,
                                                _CAMERA_FOCUS_OFFSET, <2.5,0,1.0>]);
    string sAss =       llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_DISTANCE,0.5]);
    string sFar =       llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_DISTANCE,10.0]);
    string sGod =       llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_DISTANCE,10.0,
                                                _CAMERA_PITCH,80.0]);
    string sGround =    llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_PITCH,-15.0]);
    string sWorm =      llList2Json(JSON_ARRAY,[_CAMERA_ACTIVE,TRUE,
                                                _CAMERA_PITCH,-15.0,
                                                _CAMERA_FOCUS_OFFSET, <0.0,0.0,-0.75>]);

    return llList2Json(JSON_OBJECT,["default",sDefault,"human", sHuman, "1stperson",s1stperson,"ass",sAss,"far",sFar,"god",sGod,"ground",sGround,"worm",sWorm]);

}

list lJsonModes(string sMode) {
    string sJsonTmp = llJsonGetValue(g_sJsonModes, [sMode]);
    list lTest = llJson2List(sJsonTmp);
    integer index = llGetListLength(lTest)-1;
    //last entry is checked if it is a vector to be converted from string to vector here:
    if ((vector)llList2String(lTest,index)) lTest = llListReplaceList(lTest,[(vector)llList2String(lTest,index)],index,index);
    return lTest;
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    //Debug("Made menu.");
    return kID;
} 

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else
    {
        if (llGetAgentSize(kID)) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

CamMode(string sMode) {
    llClearCameraParams();
    llSetCameraParams(lJsonModes(sMode));
}

ClearCam()
{
    if (llGetPermissions()&PERMISSION_CONTROL_CAMERA) llClearCameraParams();
    g_iLastNum = 0;    
    g_iSync2Me = FALSE;
    llMessageLinked(LINK_SET, RLV_CMD, "camunlock=y", "camera");
    llMessageLinked(LINK_SET, RLV_CMD, "camdistmax:0=y", "camera");
    llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "all", "");    
}

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
    for(; fCurrentStep <= fSteps; ++fCurrentStep)
    {
        //Set next position in tween
        vector vNextPos = vStartPose + (vPosStep * fCurrentStep);
        rotation rNextRot = Slerp( rStartRot, g_rCamRot, fCurrentStep / fSteps);
 
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
}
 
rotation Slerp( rotation a, rotation b, float f ) {
    float fAngleBetween = llAngleBetween(a, b);
    if ( fAngleBetween > PI )
        fAngleBetween = fAngleBetween - TWO_PI;
    return a*llAxisAngle2Rot(llRot2Axis(b/a)*a, fAngleBetween*f);
}//Written by Francis Chung, Taken from http://forums.secondlife.com/showthread.php?p=536622

LockCam()
{
    llSetCameraParams([
        CAMERA_ACTIVE, TRUE,
        //CAMERA_POSITION, llGetCameraPos()
        CAMERA_POSITION_LOCKED, TRUE
    ]);
    llMessageLinked(LINK_SET, RLV_CMD, "camunlock=n", "camera");
}

CamMenu(key kID, integer iAuth)
{
    string sPrompt = "\nCurrent camera mode is " + g_sCurrentMode + ".\n\nwww.opencollar.at/camera\n\nNOTE: Full functionality only on RLV API v2.9 and greater.";
    list lButtons = ["CLEAR","FREEZE","MOUSELOOK"];
    integer n;
    integer stop = llGetListLength(llJson2List(g_sJsonModes));
    for (n = 0; n < stop; n +=2)
    {
        lButtons += [Capitalize(llList2String(llJson2List(g_sJsonModes),n))];
    }
    g_kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

string Capitalize(string sIn)
{
    return llToUpper(llGetSubString(sIn, 0, 0)) + llGetSubString(sIn, 1, -1);
}
/*
string StrReplace(string sSrc, string sFrom, string sTo) {
//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    integer iLen = (~-(llStringLength(sFrom)));
    if(~iLen) {
        string  sBuffer = sSrc;
        integer iBufPos = -1;
        integer iToLen = (~-(llStringLength(sTo)));
        @loop;//instead of a while loop, saves 5 bytes (and run faster).
        integer iToPos = ~llSubStringIndex(sBuffer, sFrom);
        if(iToPos) {
//            iBufPos -= iToPos;
//            sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos, iBufPos + iLen), iBufPos, sTo);
//            iBufPos += iToLen;
//            sBuffer = llGetSubString(sSrc, (-~(iBufPos)), 0x8000);
            sBuffer = llGetSubString(sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos -= iToPos, iBufPos + iLen), iBufPos, sTo), (-~(iBufPos += iToLen)), 0x8000);
            jump loop;
        }
    }
    return sSrc;
}
*/

SaveSetting(string sToken)
{
    sToken = g_sScript + sToken;
    string sValue = (string)g_iLastNum;
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, sToken + "=" + sValue, "");
}

ChatCamParams(integer chan)
{
    g_vCamPos = llGetCameraPos();
    g_rCamRot = llGetCameraRot();
    string sPosLine = osReplaceString((string)g_vCamPos, " ", "", -1, 0) + " " + osReplaceString((string)g_rCamRot, " ", "", -1, 0);
    //if not channel 0, say to whole region.  else just say locally   
    if (chan)
    {
        llRegionSay(chan, sPosLine);                    
    }
    else
    {
        llSay(chan, sPosLine);
    }
}

integer UserCommand(integer iNum, string sStr, key kID) // here iNum: auth value, sStr: user command, kID: avatar id
{
    if (iNum > COMMAND_WEARER || iNum < COMMAND_OWNER) return FALSE; // sanity check
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    string sValue2 = llList2String(lParams, 2);
    if (sStr == "menu " + g_sSubMenu) {
        CamMenu(kID, iNum);
    }
    else if (sCommand == "cam" || sCommand == "camera")
    {
        if (sValue == "")
        {
            //they just said *cam.  give menu
            CamMenu(kID, iNum);
            return TRUE;
        }
        if (!(llGetPermissions() & PERMISSION_CONTROL_CAMERA))
        {
            Notify(kID, "Permissions error: Can not control camera.", FALSE);
            return TRUE;
        }
        if (g_iLastNum && iNum > g_iLastNum)
        {
            Notify(kID, "Sorry, cam settings have already been set by someone outranking you.", FALSE);
            return TRUE;
        }   
        //Debug("g_iLastNum=" + (string)g_iLastNum);                        
        if (sValue == "clear")
        {
            ClearCam();
            Notify(kID, "Cleared camera settings.", TRUE);
        }
        else if (sValue == "freeze")
        {
            LockCam();
            Notify(kID, "Freezing current camera position.", TRUE);
            g_iLastNum = iNum;                    
            SaveSetting("freeze");                          
        }
        else if (sValue == "mouselook")
        {
            Notify(kID, "Enforcing mouselook.", TRUE);
            g_iLastNum = iNum; 
            llMessageLinked(LINK_SET, RLV_CMD, "camdistmax:0=n", "camera");                   
            SaveSetting("mouselook");                          
        }
        else if ((vector)sValue != ZERO_VECTOR && (vector)sValue2 != ZERO_VECTOR)
        {
            Notify(kID, "Setting camera focus to " + sValue + ".", TRUE);
            //CamFocus((vector)sValue, (vector)sValue2);
            g_iLastNum = iNum;                        
            //Debug("newiNum=" + (string)iNum);
        }
        else
        {
            integer iIndex = llSubStringIndex(g_sJsonModes, sValue);//llListFindList(g_lModes, [sValue]);
            if (iIndex != -1)
            {
                CamMode(sValue);
                g_iLastNum = iNum;
                llMessageLinked(LINK_SET, RLV_CMD, "camunlock=n", "camera");
                Notify(kID, "Set " + sValue + " camera mode.", TRUE);
                SaveSetting(sValue);
            }
            else
            {
                Notify(kID, "Invalid camera mode: " + sValue, FALSE);
            }
        }
    } 
    else if (sCommand == "camto")
    {
        if (!g_iLastNum || iNum <= g_iLastNum)
        {
            CamFocus((vector)sValue, (rotation)sValue2);
            g_iLastNum = iNum;                    
        }
        else
        {
            Notify(kID, "Sorry, cam settings have already been set by someone outranking you.", FALSE);
        }
    }
    else if (sCommand == "camdump")
    {
        g_rBroadChan = (integer)sValue;
        integer g_fReapeat = (integer)sValue2;
        ChatCamParams(g_rBroadChan);
        if (g_fReapeat)
        {
            g_iSync2Me = TRUE;
            llSetTimerEvent(g_fReapeat);
        }
    }
    else if ((iNum == COMMAND_OWNER  || kID == g_kWearer) && sStr == "runaway")
    {
        ClearCam();
        llResetScript();
    }
    return TRUE;
}

default {
    on_rez(integer iNum) {
        llResetScript();
    }    
    
    state_entry() {
        //llSetMemoryLimit(65536);  //this script needs to be profiled, and its memory limited
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer = llGetOwner();
        g_sJsonModes = JsonModes();
        if (llGetAttached()) llRequestPermissions(g_kWearer, PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA);
        //Debug("Starting");
    }
    
    run_time_permissions(integer iPerms)
    {
        if (iPerms & (PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA))
        {
            llClearCameraParams();
        }
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //only respond to owner, secowner, group, wearer
        if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == COMMAND_SAFEWORD || iNum == RLV_CLEAR)
        {
            ClearCam();
            llResetScript();
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        }    
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["=", ","], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sScript)
            {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (llGetPermissions() & PERMISSION_CONTROL_CAMERA)
                {
                    if (sToken == "freeze") LockCam();
                    else if (sToken == "mouselook") llMessageLinked(LINK_SET, RLV_CMD, "camdistmax:0=n", "camera"); 
                    else if (~llSubStringIndex(g_sJsonModes, sToken)) CamMode(sToken);
                    g_iLastNum = (integer)sValue;
                }
            }           
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                // integer iPage = (integer)llList2String(lMenuParams, 2); 
                integer iAuth = (integer)llList2String(lMenuParams, 3); 
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
                }
                else
                {
                    UserCommand(iAuth, "cam " + llToLower(sMessage), kAv);
                    CamMenu(kAv, iAuth);
                }                              
            }
        }
    }
    
    timer()
    {       
        //handle cam pos/rot changes 
        if (g_iSync2Me)
        {
            vector vNewPos = llGetCameraPos();
            rotation rNewRot = llGetCameraRot();
            if (vNewPos != g_vCamPos || rNewRot != g_rCamRot)
            {
                ChatCamParams(g_rBroadChan);
            }
        }
        else
        {
            llSetTimerEvent(0.0);            
        }
    }
    
    changed(integer iChange) {
/*
        if (iChange & CHANGED_REGION) {
            if (g_iProfiled) {
                llScriptProfiler(1);
                Debug("profiling restarted");
            }
        }
*/
    }
}
