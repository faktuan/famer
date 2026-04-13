#Requires AutoHotkey v2.0
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

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
    global isRunning
    isRunning := false
    MsgBox("Script stopped.", "Status")
    Reload() ; Instantly stops all loops and sleeps by reloading the script
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
    global isRunning, userPass, userPin, numChar, userChan, savedX, savedY, targetWindow, maxChar, userDelay

    ; 6. Repeat until stopped or numChar reaches maxChar
    while (isRunning && numChar <= maxChar) {
        
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

        ; 2. Type password, enter
        Send(userPass)
        Sleep(200)
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
        if ImageSearch(&FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, "pin.png") {
            Send(userPin)
            Sleep(200)
            Send("{Enter}")
        }
		
        Sleep(2250 * userDelay)
		
		; 4.5 Check for fishing lagoon
		if !ImageSearch(&UpX, &UpY, 0, 0, A_ScreenWidth, A_ScreenHeight, "fish.png") {
            Send("{Enter}")
			Sleep(50)
			Send("@go fish{Enter}")
			Sleep(1250 * userDelay)
        }

		; 5. If it finds "up.png", click the center of it, press esc, up, enter
		Loop 3 {
			Click(savedX, savedY, 2) ; The '2' stands for Double Click
			Sleep(300)
			
			if ImageSearch(&UpX, &UpY, 0, 0, A_ScreenWidth, A_ScreenHeight, "up.png") {
				Click(UpX + 10, UpY + 10) ; Adjust +10 if you need to click further into the center of the image
				Sleep(100)
				Send("{Esc}")
				Sleep(100)
				Send("{Esc}")
				Sleep(100)
				Send("{Up}")
				Sleep(100)
				Send("{Enter}")
				Sleep(1000*userDelay) ; Wait for reset/transition before looping back
				break
			}
			else if (A_Index == 3){
				MsgBox("Pausing.")
				SoundBeep 400, 500
				isRunning := false
			}
			else {
				ToolTip("Attempt " A_Index " failed")
				SoundBeep 800, 100
			}
		}
    }
    if (numChar > maxChar) {
        MsgBox("Finished: Reached character limit (" maxChar ").")
		SoundBeep 400, 500
        isRunning := false
    }
}

; ==========================================
; User Provided Functions (v2 Corrected)
; ==========================================

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
    downPresses := inputVal // 5
    
    ; Prevent negative numbers if inputVal is 0
    rightMath := inputVal - 1
    if (rightMath < 0)
        rightMath := 0
    rightPresses := Mod(rightMath, 5) 

    Loop downPresses {
        Send("{Down}")
        Sleep(10 * userDelay)
    }

    Loop rightPresses {
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