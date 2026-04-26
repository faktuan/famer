#Requires AutoHotkey v2.0
FileInstall("fish.png", A_ScriptDir "\fish.png", 1)
FileInstall("pin.png", A_ScriptDir "\pin.png", 1)
FileInstall("up.png", A_ScriptDir "\up.png", 1)
FileInstall("relog.png", A_ScriptDir "\relog.png", 1)
FileInstall("relog2.png", A_ScriptDir "\relog2.png", 1)

if !A_IsAdmin {
    Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}


CoordMode("Mouse", "Window")
CoordMode("Pixel", "Window")

; Global variables
global targetWindow := "ahk_exe kaizen v92.exe"
global savedX := -1
global savedY := -1
global isRunning := false

global userPass := IniRead("config.ini", "default", "password", "")
global userPin := IniRead("config.ini", "default", "pin", "")
global numChar := IniRead("config.ini", "default", "char", 1)
global userChan := IniRead("config.ini", "default", "channel", 1)
global userDelay := IniRead("config.ini", "default", "delay", 1)
global accs := []

if (Integer(IniRead("config.ini", "default", "multi", 0)) == 1){
	sectionText := IniRead("config.ini", "accs")

	Loop Parse, sectionText, "`n", "`r" {
		parts := StrSplit(A_LoopField, "=", " `t", 2) 
		
		if (parts.Length < 1)
			continue ; Skip if it's a blank or invalid line
			
		rowData := parts[2]
		
		cleanRow := RegExReplace(rowData, "\s+", " ")
		accs.Push(StrSplit(cleanRow, " "))
	}
}

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
    global savedX
    if (savedX == -1) {
        MsgBox("Please press F2 to save a coordinate before starting.", "Error")
        return
    }
    ShowGui()
}

#HotIf ; Reset hotkey condition so F12 works globally (Safety Kill-Switch)

; 6. Stop script with F12 (Global so you can stop it even if the game minimizes)
F12:: {
    global isRunning, isFirstRun
	isFirstRun := true
	if( MsgBox("Script stopped. Do you wish to continue?", "Status", "YesNo Icon!") == "No" ){
		Reload()
	}
}

; ==========================================
; GUI Setup
; ==========================================

ShowGui() {
    global userPass, userPin, numChar, userChan, maxChar := 127
    SetupGui := Gui("+AlwaysOnTop", "Login Setup")
    
    ; The inputs now default to the saved global variables so you can easily resume
    SetupGui.Add("Text", "w200", "Password:")
    Global PassEdit := SetupGui.Add("Edit", "w200 Password", userPass)
    
    SetupGui.Add("Text", "w200", "PIN:")
    Global PinEdit := SetupGui.Add("Edit", "w200 Password Number", userPin)
    
    SetupGui.Add("Text", "w200", "Starting Character Number:")
    Global CharEdit := SetupGui.Add("Edit", "w200 Number", String(numChar))
    
    SetupGui.Add("Text", "w200", "Channel:")
    Global ChanEdit := SetupGui.Add("Edit", "w200 Number", String(userChan))
	
	SetupGui.Add("Text", "w200", "Number of Characters:")
    Global maxEdit := SetupGui.Add("Edit", "w200 Number", String(maxChar))
    
    StartBtn := SetupGui.Add("Button", "w200 h30 default", "Start Sequence")
    StartBtn.OnEvent("Click", StartSequence)
    
    SetupGui.Show()
}

StartSequence(GuiCtrlObj, Info) {
    global userPass, userPin, numChar, userChan, maxChar, isRunning, isFirstRun
    
    ; Save GUI inputs to variables
    userPass := PassEdit.Value
    userPin := PinEdit.Value
    numChar := Integer(CharEdit.Value)
    userChan := Integer(ChanEdit.Value)
	maxChar := Integer(maxEdit.Value)
    
    GuiCtrlObj.Gui.Destroy() ; Close the GUI
    
    isRunning := true
    isFirstRun := true ; Reset the first run tracker every time you hit Start
    RunMainLoop()
}

; ==========================================
; Main Logic Loop
; ==========================================

RunMainLoop() {
    global isRunning, userPass, userPin, numChar, userChan, savedX, savedY, targetWindow, maxChar, userDelay, accs
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

        ; 2. Type password, enter
		Click(712, 425, 2)
		Sleep(10)
        Send(userPass)
        Sleep(200 * userDelay)
        Send("{Enter}")
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
		
		; 4.5 Check for fishing lagoon
		if !ImageSearch(&UpX, &UpY, 0, 0, 1366, 768, "fish.png") {
            Send("{Enter}")
			Sleep(50)
			Send("@go fish{Enter}")
			Sleep(1250 * userDelay)
        }

		Loop 3 {
			Click(savedX, savedY, 2) ; The '2' stands for Double Click
			Sleep(300)
			
			if ImageSearch(&UpX, &UpY, 0, 0, 1366, 768, "up.png") {
				Click(UpX + 5, UpY + 5) ;
				Sleep(100)
				Send("{Esc}")
				Sleep(100)
				Send("{Esc}")
				Sleep(100)
				Send("{Up}")
				Sleep(100)
				Send("{Enter}")
				Sleep(1000*userDelay) ; Wait for reset/transition before looping back
				pauseLoop := 0
				break
			}
			else if (A_Index == 3){
				if(pauseLoop == 1){
					MsgBox("Attempt to reset failed. Current time: " . FormatTime(A_Now, "HH:mm:ss"))
					SoundBeep 400, 500
					isRunning := false
					pauseLoop := false
				}
				else{
					Loop{
						Send("{Esc}")
						Sleep(500)
						if (ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog.png") || ImageSearch(&UpX, &UpY, 0, 0, 1366, 728, "relog2.png")){
							break
						}
						else if (PixelGetColor(486, 311, "RGB") == "0x000000"){
							Send("{Enter}")
							Sleep(100)
							break
						}
						if(A_Index == 3){
							MsgBox("Attempt to relog failed. Script will be reloaded. Current time: " . FormatTime(A_Now, "HH:mm:ss"))
							Reload()
						}
					}
					pauseLoop := 1
					Send("{Up}")
					Sleep(100)
					Send("{Enter}")
					Sleep(1000*userDelay)
					numChar--
					continue
				}
			}
			else {
				ToolTip("Attempt " A_Index " failed")
				SetTimer(() => ToolTip(), -200)
				SoundBeep 800, 100
			}
		}
	    if (numChar > maxChar && isRunning) {
			if(!nextAcc()){
				MsgBox("Finished: Reached character limit (" maxChar ").")
				SoundBeep 400, 500
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
	global accs, numChar, maxChar, userDelay, targetWindow, userPass, userPin
	if(accs.Length == 0){
		return false
	}
	Sleep(1000 * userDelay)
	Click(700,400)
	Sleep(100)
	Send("{Backspace 15}" accs[1][1] "{Tab}")
	numChar := 1
	
	userPass := accs[1][2]
	userPin := accs[1][3]
	maxChar := accs[1][4]
	
	accs.RemoveAt(1)
	Loop {
		val := IniRead("config.ini", "accs", A_Index, "")

		if (val != "") {
			IniDelete("config.ini", "accs", A_Index)
			break
		}
	}
	isFirstrun := true
	
	return true
}