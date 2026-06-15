#Requires AutoHotkey v2.0
FileInstall("fish.png", A_ScriptDir "\fish.png", 1)
FileInstall("fm.png", A_ScriptDir "\fm.png", 1)
FileInstall("pin.png", A_ScriptDir "\pin.png", 1)
FileInstall("up.png", A_ScriptDir "\up.png", 1)
FileInstall("relog.png", A_ScriptDir "\relog.png", 1)
FileInstall("relog2.png", A_ScriptDir "\relog2.png", 1)
FileInstall("relog3.png", A_ScriptDir "\relog3.png", 1)
FileInstall("relog4.png", A_ScriptDir "\relog4.png", 1)

if !A_IsAdmin {
    Reloader()
}

CoordMode("Mouse", "Window")
CoordMode("Pixel", "Window")

; Global variables
global path := A_WorkingDir
try {
	path := A_Args[1]
}
global config := path . "\config.ini"
global targetWindow := "ahk_exe kaizen v92.exe"
global savedX := -1
global savedY := -1
global isRunning := false

global userPass := IniRead(config, "default", "password", "")
global userPin := IniRead(config, "default", "pin", "")
global numChar := IniRead(config, "default", "char", 1)
global userChan := IniRead(config, "default", "channel", 1)
global userDelay := IniRead(config, "default", "delay", 1)
global defame := IniRead(config, "default", "defame", 0)

global maxChar, fish, fm, defamer

global accs := []

global isFirstRun := true ; Tracks if the script is resuming from a fresh login

; ==========================================
; Game-Specific Hotkeys
; ==========================================

; Restrict F2 and F3 to ONLY work when kaizen v92.exe is the active window
#HotIf WinActive(targetWindow)

; 0. Press F2 to save a coordinate to click
F2:: {
    global savedX, savedY
    MouseGetPos(&savedX, &savedY)
    ToolTip("Coordinate saved: " savedX ", " savedY)
    SetTimer(() => ToolTip(), -2000) ; Hides tooltip after 2 seconds
}

; 1. Press F3 to open the setup menu and start
F3:: {
    global savedX, savedY
    if (savedX == -1) {
		savedX := IniRead(config, "default", "defaultX", "1086")
		savedY := IniRead(config, "default", "defaultY", "541")
		MsgBox("No coordinate was selected. The default coordinate is now set.", "Warning", "4096")
    }
    ShowGui()
}

#HotIf ; Reset hotkey condition so F12 works globally (Safety Kill-Switch)

; 6. Stop script with F12 (Global so you can stop it even if the game minimizes)
F12:: {
    global isRunning, isFirstRun, numChar
	isFirstRun := true
	if( MsgBox("Script stopped. `nLast Character: " . numChar-1 . "`nDo you wish to continue?", "Status", "YesNo Icon!") == "No" ){
		Reloader()
	}
	WinActivate(targetWindow)
}

; ==========================================
; GUI Setup
; ==========================================

ShowGui() {
    global userPass, userPin, numChar, userChan, maxChar, defame
    SetupGui := Gui("+AlwaysOnTop", "Login Setup")
    
    ; The inputs now default to the saved global variables so you can easily resume
    SetupGui.Add("Text", "w200", "Password:")
    Global PassEdit := SetupGui.Add("Edit", "w200 Password", userPass)
    
    SetupGui.Add("Text", "w200", "PIN:")
    Global PinEdit := SetupGui.Add("Edit", "w200 Password Number", userPin)
    
    SetupGui.Add("Text", "w200", "Starting Character Number:")
    Global CharEdit := SetupGui.Add("Edit", "w200 Number Limit3", String(numChar))
    
    SetupGui.Add("Text", "w200", "Channel:")
    Global ChanEdit := SetupGui.Add("Edit", "w200 Number Limit2", String(userChan))
	
	SetupGui.Add("Text", "w200", "Number of Characters:")
    Global maxEdit := SetupGui.Add("Edit", "w200 Number Limit3", String(IsSet(maxChar) ? maxChar : 127))

	Global goFish := SetupGui.Add("Radio", "xm Group Checked", "Fish")
	Global goFM := SetupGui.Add("Radio", "x+m", "FM")
	Global doDefame := SetupGui.Add("Checkbox", "x+m" . (defame ? " Checked" : ""), "Defame")
    
    StartBtn := SetupGui.Add("Button", "xm w200 h30 default", "Start Faming")
    StartBtn.OnEvent("Click", StartFaming)
    
    SetupGui.Show()
}

StartFaming(GuiCtrlObj, Info) {
    global userPass, userPin, numChar, userChan, maxChar, isRunning, isFirstRun, fish, fm, defamer
    
    ; Save GUI inputs to variables
    userPass := PassEdit.Value
    userPin := PinEdit.Value
    numChar := Integer(CharEdit.Value)
    userChan := Integer(ChanEdit.Value)
	maxChar := Integer(maxEdit.Value)
	defamer := doDefame.Value ? 20 : 5
	fish := goFish.Value == 1
	fm := goFM.Value == 1
    
    GuiCtrlObj.Gui.Destroy() ; Close the GUI
    
    isRunning := true
    isFirstRun := true ; Reset the first run tracker every time you hit Start
    RunMainLoop()
}

; ==========================================
; Main Logic Loop
; ==========================================

RunMainLoop() {
    global isRunning, userPass, userPin, numChar, userChan, savedX, savedY, targetWindow, maxChar, userDelay, accs, isFirstRun, fish, fm
    ; 6. Repeat until stopped or numChar reaches maxChar
	pauseLoop := 0
    while (isRunning) {
        
        ; Ensure the game is still running
        if !WinExist(targetWindow) {
            MsgBox("Kaizen closed. Stopping script.")
            isRunning := false
            break
        }

        ; Ensure the game is the active window before sending keystrokes
        if !WinActive(targetWindow) {
            WinActivate(targetWindow)
            WinWaitActive(targetWindow, , 2)
        }

		numChar := Max(1, numChar)
		if(!userPass)
		{
			if(!nextAcc()){
				MsgBox("Info not entered. Try again.", "Error", "4096")
				break
			}
		}

        ; 2. Type password, enter
		Click(712, 425)
		Sleep(10)
        Send("{Backspace 15}" userPass)
        Sleep(200)
        Click(760, 425)
        Sleep(1000 * userDelay) ; Wait for login screen transition (adjust if needed)

        ; selWorld(character)
        selWorld(numChar)
        Sleep(500 * userDelay)

        ; selChannel(channel)
        selChannel(userChan)
        Sleep(500 * userDelay)

        ; selChar()
        selChar()
        Sleep(200 * userDelay) ; Wait for character select screen / PIN screen to load

        ; 3. Check for "pin.png", if it appears, type pin
        if ImageSearch(&FoundX, &FoundY, 0, 0, 1366, 768, "pin.png") {
            Send(userPin)
            Sleep(200)
            Send("{Enter}")
        }
		
        Sleep(2250 * userDelay)
		
		; 4.5 Check for fishing lagoon or fm
		if(fish){
			if ( !ImageSearch(&UpX, &UpY, 600, 280, 680, 330, "*20 fish.png") ){
				Send("{Enter}")
				Sleep(50)
				Send("@go fish{Enter}")
				Sleep(1250 * userDelay)
			}
		}
		else if (fm){
			if ( !ImageSearch(&UpX, &UpY, 0, 0, 1366, 768, "*20 fm.png") ){
				Send("{Enter}")
				Sleep(50)
				Send("@go fm{Enter}")
				Sleep(1250 * userDelay)
			}
		}
		else{
			MsgBox("Map selection not found.")
		}

		Loop 3 {
			Click(savedX, savedY, 2) ; The '2' stands for Double Click
			Sleep(300)
			
			if ImageSearch(&UpX, &UpY, 0, 0, 1366, 768, "*20 up.png") {
				;Click(UpX - 13 , UpY + 105)
				Click(UpX + defamer , UpY + 5)
				Sleep(100)
				Click(1280, 777)
				Sleep(100)
				Click(1245, 745)
				Sleep(1000*userDelay) ; Wait for reset/transition before looping back
				pauseLoop := 0
				break
			}
			else if (A_Index == 3){
				if(pauseLoop == 1){
					SoundBeep 400, 500
					MsgBox("Attempt to reset failed. `nLast Character: " . numChar-1 . "`nCurrent time: " . FormatTime(A_Now, "HH:mm:ss"))
					numChar--
					isRunning := false
					pauseLoop := false
				}
				else{
					Loop{
						if(A_Index == 4){
							SoundBeep 400, 500
							MsgBox("Attempt to relog failed. Go back to login screen before you click OK. `nLast Character: " . numChar-1 . "`nCurrent time: " . FormatTime(A_Now, "HH:mm:ss"))
							break
						}
						Send("{Esc}")
						Sleep(1000)
						if (ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog.png")){
							Click(1245, 745)
							break
						}
						else if ( ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog2.png") || ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog3.png" ) ){
							Send("{Enter}")
							Sleep(100)
							break
						}
						else if ( ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog4.png") ){
							break
						}
					}
					pauseLoop := 1

					Sleep(1000*userDelay)
					isFirstRun := true
					numChar--
					continue
				}
				SoundBeep 800, 100
			}
			else {
				ToolTip("Attempt " A_Index " failed")
				SetTimer(() => ToolTip(), -200)
				SoundBeep 800, 100
			}
		}
	    if (numChar > maxChar) {
			if(!nextAcc()){
				SoundBeep 400, 100
				SoundBeep 100, 300
				MsgBox("Finished: Reached character limit (" maxChar ").")
				isRunning := false
				break
			}
		}
    }
}

; Functions

selWorld(inputVal) {
	global userDelay
	
    if ( inputVal > 90 ) {
        Send("{Down}")
        Sleep(10 * userDelay)
		inputVal := inputVal - 90
    }
	
    Loop ( (inputVal-1) // 15 ) {
        Send("{Right}")
        Sleep(10 * userDelay)
    }

    Send("{Enter}")
}

selChannel(inputVal) {
	global userDelay
	inputVal := inputVal - 1
    downPresses := inputVal // 5

    Loop downPresses {
        Send("{Down}")
        Sleep(10 * userDelay)
    }

    Loop Mod(inputVal, 5) {
        Send("{Right}")
        Sleep(10 * userDelay)
    }

    Send("{Enter}")
}

selChar() {
    global numChar, isFirstRun, userDelay
    
    if (isFirstRun) {
        ; On the very first run/resume, the client resets the cursor to position 1.
        ; This loop calculates how many times to press Right to reach the target character.
        targetSlot := Mod(numChar - 1, 15)
		Loop 14 {
			Send("{Left}")
			Sleep(10 * userDelay)
		}
        Loop targetSlot-1 {
            Send("{Right}")
            Sleep(10 * userDelay)
        }
        isFirstRun := false ; Set to false so subsequent loops go back to normal logic
    }
	; Normal relative logic for when the script is naturally looping
	if (Mod(numChar - 1, 15) == 0) {
		Loop 14 {
			Send("{Left}")
			Sleep(10 * userDelay)
		}
	}
	else {
		Send("{Right}")
		Sleep(10 * userDelay)
	}
    
    Sleep(200)
    Send("{Enter}")
    numChar := numChar + 1
}

nextAcc(){
	global accs, numChar, maxChar, userDelay, targetWindow, userPass, userPin, config
	if (Integer(IniRead(config, "default", "multi", 0)) == 0)
		return false

	Loop {
		try {
			lockHandle := FileOpen(path "\config.lock", "w-r")
			sectionText := IniRead(config, "accs")
			accs.Length := 0
			
			; Extract everything on the first line
			if RegExMatch(sectionText, "^([^=]+)=\s*(.+)", &match) {
				keyName := Trim(match[1])
				cleanRow := RegExReplace(match[2], "\s+", " ")
				
				accs.Push(StrSplit(cleanRow, " "))
				IniDelete(config, "accs", keyName)
				break
			} 
			else
				return false
		} catch {
			Sleep(Random(1, 500))
		} finally{
			try{
					lockHandle.Close()
					FileDelete(path "\config.lock")
				}
		}
	}

	Sleep(1100 * userDelay)
	Click(700,400)
	Sleep(100)
	Send("{Backspace 15}" accs[1][1])
	Sleep(100)
	Send("{Tab}")

	numChar := 1
	userPass := accs[1][2]
	userPin := accs[1][3]
	maxChar := accs[1][4]
	
	accs.RemoveAt(1)

	isFirstRun := true
	return true
}

Reloader(){
	args := ""
	Loop A_Args.Length{
		args .= ' "' A_Args[A_Index] '"'
	}
	Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"' args)
    ExitApp()
}