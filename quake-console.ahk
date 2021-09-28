; app quake console: Visor-like functionality for Windows
; Version: 1.8
; Author: Jon Rogers (lonepie@gmail.com)
; URL: https://github.com/lonepie/app-quake-console
; Credits:
;   Originally forked from: https://github.com/marcharding/app-quake-console
;   app: https://github.com/app/
;   Visor: http://visor.binaryage.com/
;
; MIT License
; Copyright (c) 2018 Jon Rogers

; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

;*******************************************************************************
;               Settings
;*******************************************************************************
#NoEnv
#SingleInstance force
#Persistent
; #Warn

WriteLog("Script starting")

SendMode Input
DetectHiddenWindows, on
SetWinDelay, -1

; get path to cygwin from registry
RegRead, cygwinRootDir, HKEY_LOCAL_MACHINE, SOFTWARE\Cygwin\setup, rootdir
cygwinBinDir := cygwinRootDir . "\bin"

; force process to be DPI aware
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

;*******************************************************************************
;               Preferences & Variables
;*******************************************************************************
VERSION = 1.8
SCRIPTNAME := "quake-console"
iniFile := A_ScriptDir . "\" . SCRIPTNAME . ".ini"
localIniFile := StrReplace(iniFile, ".ini", ".local.ini")
if (FileExist(localIniFile)) {
    WriteLog("Found local ini file, using that instead: " . localIniFile)
    iniFile := localIniFile
}
IniRead, appPath, %iniFile%, General, app_path, -
IniRead, appArgs, %iniFile%, General, app_args, -
IniRead, appIcon, %iniFile%, General, app_icon, %appPath%
IniRead, consoleHotkey, %iniFile%, General, hotkey, ^``
IniRead, startWithWindows, %iniFile%, Display, start_with_windows, 0
IniRead, startHidden, %iniFile%, Display, start_hidden, 1
IniRead, alwaysOnTop, %iniFile%, Display, always_on_top, 0
IniRead, initialHeight, %iniFile%, Display, initial_height, 400
IniRead, initialWidth, %iniFile%, Display, initial_width, 100 ; percent
IniRead, initialTrans, %iniFile%, Display, initial_trans, 235 ; 0-255 stepping
IniRead, autohide, %iniFile%, Display, autohide_by_default, 0
IniRead, animationModeFade, %iniFile%, Display, animation_mode_fade, 1
IniRead, animationModeSlide, %iniFile%, Display, animation_mode_slide, 0
IniRead, animationStep, %iniFile%, Display, animation_step, 20
IniRead, animationTimeout, %iniFile%, Display, animation_timeout, 10
IniRead, windowBorders, %iniFile%, Display, window_borders, 0
IniRead, displayOnMonitor, %iniFile%, Display, display_on_monitor, 0

if !FileExist(iniFile) {
    SaveSettings()
}
else {
    ; add/remove windows startup if needed
    CheckWindowsStartup(startWithWindows)
}

appPath := ExpandEnvVars(appPath)
appArgs := ExpandEnvVars(appArgs)

; path to app
appPathArgs := appPath . " " . appArgs
WriteLog("Full app command: " . appPathArgs)

; initial height and width of console window
heightConsoleWindow := initialHeight
widthConsoleWindow := initialWidth

isVisible := False
app_pid = 0

;*******************************************************************************
;               Hotkeys
;*******************************************************************************
Hotkey, %consoleHotkey%, ConsoleHotkey

;*******************************************************************************
;               Menu
;*******************************************************************************
if !InStr(A_ScriptName, ".exe")
    Menu, Tray, Icon, %appIcon%
Menu, Tray, NoStandard
; Menu, Tray, MainWindow
Menu, Tray, Tip, %SCRIPTNAME% %VERSION%
Menu, Tray, Click, 1
Menu, Tray, Add, Show/Hide, ToggleVisible
Menu, Tray, Default, Show/Hide
Menu, Tray, Add, Enabled, ToggleScriptState
Menu, Tray, Check, Enabled
Menu, Tray, Add, Auto-Hide, ToggleAutoHide
if (autohide)
    Menu, Tray, Check, Auto-Hide
Menu, Tray, Add
Menu, Tray, Add, Options, ShowOptionsGui
Menu, Tray, Add, Edit Config, EditSettings
Menu, Tray, Add, About, AboutDlg
Menu, Tray, Add, Reload, ReloadSub
Menu, Tray, Add, Exit, ExitSub

init()
return
;*******************************************************************************
;               Functions / Labels
;*******************************************************************************
init() {
    global
    initCount++
    ; get last active window
    WinGet, current_pid, ID, A
    if !WinExist("ahk_pid" . app_pid) {
        WriteLog("Couldnt find an ative window, starting one")
        app_pid = 0
        Run %appPathArgs%, %cygwinBinDir%, Hide, app_pid
        WriteLog("Started application with pid " . app_pid)

        WinWait, ahk_pid %app_pid%, , 5
        if ErrorLevel {
            ; WinWait Timed out (WHY?!?)
            WinGet, app_pid, PID, ahk_exe %appPath%
        }
    }
    else {
        WinGet, app_pid, PID, ahk_class app
    }

    ; MsgBox, 4, %SCRIPTNAME%, "Is active"
    WinActivate, ahk_pid %app_pid%
    ; IfWinActive, ahk_pid %app_pid% 
    ; {
    ;     MsgBox, 4, %SCRIPTNAME%, "Is active"
    ;     Slide("ahk_pid" . app_pid, "Out")
    ; }

    WinGetPos, OrigXpos, OrigYpos, OrigWinWidth, OrigWinHeight, ahk_pid %app_pid%
    toggleScript("on")
    if (initCount = 1 and startHidden) {
        toggle()
    }
    setAlwaysOnTop()

    WinActivate, ahk_id %current_pid%
    Slide("ahk_pid" . app_pid, "Out")
}

toggle() {
    global

    IfWinActive ahk_pid %app_pid% 
    {
        Slide("ahk_pid" . app_pid, "Out")
        ; reset focus to last active window
        WinActivate, ahk_id %current_pid%
    }
    else {
        ; get last active window
        WinGet, current_pid, ID, A

        if (!alwaysOnTop || (alwaysOnTop && !isVisible)) {
            WinActivate ahk_pid %app_pid%
            Slide("ahk_pid" . app_pid, "In")
        }
        else if (isVisible) {
            Slide("ahk_pid" . app_pid, "Out") 
            ; reset focus to last active window
            WinActivate, ahk_id %current_pid%
        }
    }
}

Slide(Window, Dir) {
    global widthConsoleWindow, animationModeFade, animationModeSlide, animationStep, animationTimeout, autohide, isVisible, currentTrans, initialTrans, displayOnMonitor
    WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%

    WinGet, testTrans, Transparent, %Window%
    if (testTrans = "" or (animationModeFade and currentTrans = 0)) {
        ; Solution for Windows 8 to find window without borders, only 1st call will flash borders
        WinSet, Style, +0xC00000, %Window% ; show window border
        WinSet, Transparent, %currentTrans%, %Window%
        if (!windowBorders)
            WinSet, Style, -0xC00000, %Window% ; hide window border
        ; this problem seems to happen if app's transparency is set to "Off"
        ; app will lose transparency when the window loses focus, so it's best to just use
        ; app's built in transparency setting
    }

    VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

    if (animationModeFade) {
        WinMove, %Window%,, WinLeft, ScreenTop
    }

    ; Multi monitor support.  Always move to current window
    If (Dir = "In") {
        WinShow %Window%
        width := ScreenWidth * widthConsoleWindow / 100
        if (displayOnMonitor > 0)
            WinLeft := ScreenLeft
        else
            WinLeft := ScreenLeft + (1 - widthConsoleWindow/100) * ScreenWidth / 2
        WinMove, %Window%, , WinLeft, , width
    }
    Loop {
        inConditional := (animationModeSlide) ? (Ypos >= ScreenTop) : (currentTrans == initialTrans)
        outConditional := (animationModeSlide) ? (Ypos <= (-WinHeight)) : (currentTrans == 0)

        If (Dir = "In") And inConditional Or (Dir = "Out") And outConditional
            Break

        if (animationModeFade = 1) {
            dRate := animationStep/300*255
            dT := % (Dir = "In") ? currentTrans + dRate : currentTrans - dRate
            dT := (dT < 0) ? 0 : ((dT > initialTrans) ? initialTrans : dT)

            WinSet, Transparent, %dT%, %Window%
            currentTrans := dT
        }
        else {
            dRate := animationStep
            dY := % (Dir = "In") ? Ypos + dRate : Ypos - dRate
            WinMove, %Window%,,, dY
        }

        WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%
        Sleep, %animationTimeout%
    }

    If (Dir = "In") {
        WinMove, %Window%,,, ScreenTop
        if (autohide)
            SetTimer, HideWhenInactive, 250
        isVisible := True
    }
    If (Dir = "Out") {
        WinHide %Window%
        if (autohide)
            SetTimer, HideWhenInactive, Off
        isVisible := False
    }
}

toggleScript(state) {
    ; enable/disable script effects, hotkeys, etc
    global
    ; WinGetPos, Xpos, Ypos, WinWidth, WinHeight, ahk_pid %app_pid%
    if (state = "on" or state = "init") {
        If !WinExist("ahk_pid" . app_pid) {
            WriteLog("Unable to find window for pid: " . app_pid . " exiting")
            init()
            ExitApp
        }

        ; use app's transparency setting, if it's set
        WinGet, appTrans, Transparent, ahk_pid %app_pid%
        if (appTrans <> "")
            initialTrans:=appTrans
        WinSet, Transparent, %initialTrans%, ahk_pid %app_pid%
        currentTrans:=initialTrans

        WinHide ahk_pid %app_pid%
        winExists := WinExist("ahk_pid" . app_pid)
        WriteLog("Window exists? " . winExists)
        if (!windowBorders) { 
            WinSet, Style, -0xC00000, ahk_pid %app_pid% ; hide window borders and caption/title
        }

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) / 2)
        WinMove, ahk_pid %app_pid%, , %left%, -%heightConsoleWindow%, %width%, %heightConsoleWindow% ; resize/move

        scriptEnabled := True
        Menu, Tray, Check, Enabled

        if (state = "init" and initCount = 1 and startHidden) {
            return
        }

        WinShow ahk_pid %app_pid%
        WinActivate ahk_pid %app_pid%
        Slide("ahk_pid" . app_pid, "In")
    }
    else if (state = "off") {
        WinSet, Style, +0xC00000, ahk_pid %app_pid% ; show window borders and caption/title
        if (OrigYpos >= 0)
            WinMove, ahk_pid %app_pid%, , %OrigXpos%, %OrigYpos%, %OrigWinWidth%, %OrigWinHeight% ; restore size / position
        else
            WinMove, ahk_pid %app_pid%, , %OrigXpos%, 100, %OrigWinWidth%, %OrigWinHeight%
        WinShow, ahk_pid %app_pid% ; show window
        scriptEnabled := False
        Menu, Tray, Uncheck, Enabled
        killProcess(app_pid)
    }
}

killProcess(pid) {
    WriteLog("Seeing if application is running with pid " . pid)
    Process, Exist, %pid%
    processExists := ErrorLevel
    if processExists != 0
        WriteLog("Found application running with pid " . pid . " killing it")
    RunWait, taskkill /PID %pid% /T /F
}

HideWhenInactive:
    IfWinNotActive ahk_pid %app_pid%
    {
        Slide("ahk_pid" . app_pid, "Out")
        SetTimer, HideWhenInactive, Off
    }
return

ToggleVisible:
    if (isVisible)
    {
        Slide("ahk_pid" . app_pid, "Out")
    }
    else
    {
        WinActivate ahk_pid %app_pid%
        Slide("ahk_pid" . app_pid, "In")
    }
return

ToggleScriptState:
    if (scriptEnabled)
        toggleScript("off")
    else
        toggleScript("on")
return

ToggleAutoHide:
    autohide := !autohide
    Menu, Tray, ToggleCheck, Auto-Hide
    SetTimer, HideWhenInactive, Off
    SaveSettings()
return

ConsoleHotkey:
    if (scriptEnabled) {
        WriteLog("Toggle key pressed")
        IfWinExist ahk_pid %app_pid%
        {
            WriteLog("Windows exists, toggling")
            toggle()
        }
        else
        {
            WriteLog("Windows doesnt exists, running init")
            init()
        }
    }
return

ExitSub:
    if A_ExitReason not in Logoff,Shutdown
    {
        WriteLog("Running exit hook")
        ; MsgBox, 4, %SCRIPTNAME%, Are you sure you want to exit?
        ; IfMsgBox, No
        ;     return
        toggleScript("off")
    }
    WriteLog("Script exiting")
ExitApp

ReloadSub:
    WriteLog("Reload event")
    killProcess(app_pid)
    Reload
return

AboutDlg:
    MsgBox, 64, About, %SCRIPTNAME% AutoHotkey script`nVersion: %VERSION%`nAuthor: Jonathon Rogers <lonepie@gmail.com>`nURL: https://github.com/lonepie/app-quake-console
return

ShowOptionsGui:
    OptionsGui()
return

EditSettings:
    EnvGet, envEditor, Editor
    if (StrLen(Trim(envEditor)) == 0)
        envEditor := "notepad.exe"
    Run, %envEditor% %iniFile%
return

;*******************************************************************************
;               Extra Hotkeys
;*******************************************************************************
#IfWinActive ahk_exe alacritty.exe
    ; why this method doesn't work, I don't know...
    ; IncreaseHeight:
^!NumpadAdd::
^+=::
    if (WinActive("ahk_pid" . app_pid)) {

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)
        if (heightConsoleWindow < ScreenHeight) {
            heightConsoleWindow += animationStep
            WinMove, ahk_pid %app_pid%,,,,, heightConsoleWindow
        }
    }
return
; DecreaseHeight:
^!NumpadSub::
^+-::
    if (WinActive("ahk_pid" . app_pid)) {
        if (heightConsoleWindow > 100) {
            heightConsoleWindow -= animationStep
            WinMove, ahk_pid %app_pid%,,,,, heightConsoleWindow
        }
    }
return
; Decrease Width
^![::
    if (widthConsoleWindow >= 20) {
        widthConsoleWindow -= 5
        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) / 2)
        WinMove, ahk_pid %app_pid%, , %left%, , %width% ; resize/move
    }
return
; Increase Width
^!]::
    if (widthConsoleWindow < 100) {
        widthConsoleWindow += 5

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) / 2)
        WinMove, ahk_pid %app_pid%, , %left%, , %width% ; resize/move
    }
return
; Toggle window borders
^!NumpadDiv::
    WinSet, Style, ^0xC40000, ahk_pid %app_pid%
    windowBorders := !windowBorders
return
; Save Height & border state to ini
^!NumpadMult::
    IniWrite, %heightConsoleWindow%, %iniFile%, Display, initial_height
    IniWrite, %widthConsoleWindow%, %iniFile%, Display, initial_width
    IniWrite, %windowBorders%, %iniFile%, Display, window_borders
return
; Toggle script on/off
^!NumpadDot::
    GoSub, ToggleScriptState
return
#IfWinActive

;*******************************************************************************
;               Options
;*******************************************************************************
SaveSettings() {
    global
    IniWrite, %appPath%, %iniFile%, General, app_path
    IniWrite, %appArgs%, %iniFile%, General, app_args

    ; Special case : If there is no key entered and both windows key and control key are checked
    If (consoleHotkey == "" and ControlKey and WindowsKey)
    {
        consoleHotkey = ^LWin
    }
    Else If (consoleHotkey != "")
    {
        ; If the Windows Key checkbox is checked and there isn't already the Windows key in the hotkey string, we add it
        If (WindowsKey)
        {
            IfNotInString, consoleHotkey, #
                consoleHotkey = #%consoleHotkey%
        }

        ; If the Control Key checkbox is checked and there isn't already the Control key in the hotkey string, we add it
        If (ControlKey)
        {
            IfNotInString, consoleHotkey, ^
                consoleHotkey = ^%consoleHotkey%
        }

    }
    ; In case the hotkey is empty and only one of the checkbox is checked, we put back the default value
    Else
    {
        consoleHotkey = ^``
    }

    IniWrite, %consoleHotkey%, %iniFile%, General, hotkey
    IniWrite, %startWithWindows%, %iniFile%, Display, start_with_windows
    IniWrite, %startHidden%, %iniFile%, Display, start_hidden
    IniWrite, %alwaysOnTop%, %iniFile%, Display, always_on_top
    IniWrite, %heightConsoleWindow%, %iniFile%, Display, initial_height
    IniWrite, %widthConsoleWindow%, %iniFile%, Display, initial_width
    IniWrite, %initialTrans%, %iniFile%, Display, initial_trans
    IniWrite, %autohide%, %iniFile%, Display, autohide_by_default
    IniWrite, %animationModeSlide%, %iniFile%, Display, animation_mode_slide
    IniWrite, %animationModeFade%, %iniFile%, Display, animation_mode_fade
    IniWrite, %animationStep%, %inifile%, Display, animation_step
    IniWrite, %animationTimeout%, %iniFile%, Display, animation_timeout
    IniWrite, %windowBorders%, %iniFile%, Display, window_borders
    CheckWindowsStartup(startWithWindows)
    setAlwaysOnTop()
}

CheckWindowsStartup(enable) {
    SplitPath, A_ScriptName, , , , OutNameNoExt
    LinkFile=%A_Startup%\%OutNameNoExt%.lnk

    if !FileExist(LinkFile) {
        if (enable) {
            FileCreateShortcut, %A_ScriptFullPath%, %LinkFile%
        }
    }
    else {
        if (!enable) {
            FileDelete, %LinkFile%
        }
    }
}

setAlwaysOnTop() {
    ; set always on top depending on preference
    global alwaysOnTop
    if (alwaysOnTop) {
        Winset, AlwaysOnTop, On
    }
    else {
        Winset, AlwaysOnTop, Off
    }
}

OptionsGui() {
    global
    If not WinExist("ahk_id" GuiID) {
        Gui, Add, GroupBox, x12 y10 w450 h110 , General
        Gui, Add, GroupBox, x12 y130 w450 h250 , Display
        Gui, Add, Button, x242 y390 w100 h30 Default, Save
        Gui, Add, Button, x362 y390 w100 h30 , Cancel
        Gui, Add, Text, x22 y30 w70 h20 , app Path:
        Gui, Add, Edit, x92 y30 w250 h20 VappPath, %appPath%
        Gui, Add, Button, x352 y30 w100 h20, Browse
        Gui, Add, Text, x22 y60 w100 h20 , app Arguments:
        Gui, Add, Edit, x122 y60 w330 h20 VappArgs, %appArgs%
        Gui, Add, Text, x22 y90 w100 h20 , Hotkey Trigger:
        Gui, Add, Text, x232 y92 w10 h10, +
        Gui, Add, CheckBox, x245 y89 w90 h20 VWindowsKey, Windows Key
        Gui, Add, Text, x340 y92 w10 h10, +
        Gui, Add, CheckBox, x360 y89 w80 h20 VControlKey, Control Key
        ; If there is a # (Windows Key) in the consoleHotkey var, we remove it, as the Hotkey control doesn't support it, and we check the Windows Key checkbox
        IfInString, consoleHotkey, #
        {
            GuiControl, , WindowsKey, 1
            StringReplace, consoleHotkey, consoleHotkey, # , , All
        }
        Gui, Add, Hotkey, x122 y90 w100 h20 VconsoleHotkey, %consoleHotkey%
        Gui, Add, CheckBox, x22 y150 w100 h30 VstartHidden Checked%startHidden%, Start Hidden
        Gui, Add, CheckBox, x22 y180 w150 h30 Vautohide Checked%autohide%, Auto-Hide when focus is lost
        Gui, Add, CheckBox, x22 y210 w120 h30 VstartWithWindows Checked%startWithWindows%, Start With Windows
        Gui, Add, CheckBox, x22 y239 w100 h30 ValwaysOnTop Checked%alwaysOnTop%, Always On Top
        Gui, Add, Text, x22 y280 w100 h20 , Initial Height (px):
        Gui, Add, Edit, x22 y300 w100 h20 VinitialHeight, %initialHeight%
        Gui, Add, Text, x22 y330 w115 h20 , Initial Width (percent):
        Gui, Add, Edit, x22 y350 w100 h20 VinitialWidth, %initialWidth%

        Gui, Add, GroupBox, x232 y150 w220 h45 , Animation Type:
        Gui, Add, Radio, x252 y168 w70 h20 VanimationModeSlide group Checked%animationModeSlide%, Slide
        Gui, Add, Radio, x332 y168 w70 h20 VanimationModeFade Checked%animationModeFade%, Fade

        Gui, Add, Text, x232 y210 w220 h20 , Animation Delta (px):
        Gui, Add, Text, x232 y260 w220 h20 , Animation Time (ms):
        Gui, Add, Slider, x232 y230 w220 h30 VanimationStep Range1-100 TickInterval20 , %animationStep%
        Gui, Add, Slider, x232 y280 w220 h30 VanimationTimeout Range1-50 TickInterval10, %animationTimeout%
        Gui, Add, Text, x232 y310 w220 h20 , Window Transparency (`%):
        Gui, Add, Slider, x232 y330 w220 h30 VinitialTrans Range100-255 , %initialTrans%
        ; Gui, Add, Text, x232 y320 w220 h20 +Center, Animation Speed = Delta / Time
    }
    ; Generated using SmartGUI Creator 4.0
    Gui, Show, h440 w482, %SCRIPTNAME% Options
    Gui, +LastFound
    GuiID := WinExist()

    Loop {
        ;sleep to reduce CPU load
        Sleep, 100

        ;exit endless loop, when settings GUI closes
        If not WinExist("ahk_id" GuiID)
            Break
    }

ButtonSave:
    Gui, Submit
    SaveSettings()
    Reload
return

ButtonBrowse:
    FileSelectFile, SelectedPath, 3, %A_MyDocuments%, Path to app.exe, Executables (*.exe)
    if SelectedPath !=
        GuiControl,, appPath, %SelectedPath%
return

GuiClose:
GuiEscape:
ButtonCancel:
    Gui, Cancel
return
}

;*******************************************************************************
;               Utility
;*******************************************************************************
; Gets the edge that the taskbar is docked to.  Returns:
;   "top"
;   "right"
;   "bottom"
;   "left"

VirtScreenPos(ByRef mLeft, ByRef mTop, ByRef mWidth, ByRef mHeight) {
    global displayOnMonitor
    if (displayOnMonitor > 0) {
        SysGet, Mon, Monitor, %displayOnMonitor%
        SysGet, MonArea, MonitorWorkArea, %displayOnMonitor%

        mLeft:=MonAreaLeft
        mTop:=MonAreaTop
        mWidth:=(MonAreaRight - MonAreaLeft)
        mHeight:=(MonAreaBottom - MonAreaTop)
    }
    else {
        Coordmode, Mouse, Screen
        MouseGetPos,x,y
        SysGet, m, MonitorCount

        ; Iterate through all monitors.
        Loop, %m%
        { ; Check if the window is on this monitor.
            SysGet, Mon, Monitor, %A_Index%
            SysGet, MonArea, MonitorWorkArea, %A_Index%
            if (x >= MonLeft && x <= MonRight && y >= MonTop && y <= MonBottom)
            {
                mLeft:=MonAreaLeft
                mTop:=MonAreaTop
                mWidth:=(MonAreaRight - MonAreaLeft)
                mHeight:=(MonAreaBottom - MonAreaTop)
            }
        }
    }
}
ExpandEnvVars(ppath) {
    VarSetCapacity(dest, 2000)
    DllCall("ExpandEnvironmentStrings", "str", ppath, "str", dest, int, 1999, "Cdecl int")
return dest
}

WriteLog(text) {
    FormatTime, time, A_Now, HH:mm:ss
    FileAppend, % time ": " text "`n", logfile.txt ; can provide a full path to write to another directory
}

/*
ResizeAndCenter(w, h)
{
  ScreenX := GetScreenLeft()
  ScreenY := GetScreenTop()
  ScreenWidth := GetScreenWidth()
  ScreenHeight := GetScreenHeight()

  WinMove A,,ScreenX + (ScreenWidth/2)-(w/2),ScreenY + (ScreenHeight/2)-(h/2),w,h
}
*/
