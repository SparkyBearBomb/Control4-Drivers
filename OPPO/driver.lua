--[[=============================================================================
				    INDEX
=================================================================================
SECTION - LINE NUMBER START

INDEX - 1									-- This section, line number and breif description of sections job
MESSAGE CONSTRUCTION - 19					-- Important variables and settings that the driver needs to function correctly
COMMAND TABLE LOOKUP - 46					-- Table of commands used to convert Control 4 to device command language
CUSTOM REMOTE COMMANDS CONSTRUCTION - 103	-- Mapping Remote Bindings in Composer
TIMER CONSTRUCTION - 128					-- Setup and running of important in driver timers
PROXY COMMANDS - 152						-- Receives Control 4 Commands and performs table lookups, adds to buffers and starts timers
PROPERTY UPDATE FUNCTIONS - 228				-- Handles and updates the driver settings when the propeties tab is changed
DEVICE MESSAGING  FUNCTIONS - 266			-- Sending and Initial Receiving of Driver to Device messages
MESSAGE HANDLING FUNCTIONS - 363			-- Message handling from the Device before sending to Control 4
DEVICE EVENT FUNCTIONS - 413				-- Functions from the Events dropdown in composer programming
DEVICE ACTION FUNCTIONS - 477  				-- Functions from the Actions page in composer
LOGGING FUNCTIONS - 504						-- Handles what messages are displayed relative to the Log Level

=================================================================================
				    MESSAGE CONSTRUCTION
===============================================================================]]

prefix = "#"							-- Transmit Message Prefix
instruction = ""						-- Transmit Message Instruction (command) eg. Set Volume
suffix = "\r"							-- Transmit Message Suffix
payloadPrefix = " "						-- Transmit Message Payload Prefix
payload = ""							-- Transmit Message Payload (values) eg. 70%, Added to Instruction Before Buffer Insertion
receivePrefix = "@"						-- Receive Message Prefix
sendBuffer = {}						-- Buffers Messages To Device
receiveBuffer = {}						-- Buffers Messages From Device
tParams = {}							-- Holds Values For The Payload
C4:DeleteVariable("PWRTimer")				-- Timer Settings
C4:DeleteVariable("CMDTimer")				-- Timer Settings
bool1,PWRTimer = C4:AddVariable("PWRTimer", "Stopped", "STRING", false, true)
bool2,CMDTimer = C4:AddVariable("CMDTimer", "Stopped", "STRING", false, true)
logLevel = tonumber(string.sub(Properties["Log Level"],1,1))
pwrTimer = Properties["Power On Delay"]		-- Delay Pulled From Composer, Delays Commands After Power On
cmdTimer = Properties["Command Delay"]		-- Delay Pulled From Composer, Delays Commands Pulled From Send Buffer
rcvTimer = 50							-- Delay For Flushing The Recieve Buffer -- End Of Timer Settings
SVM = "SVM 3"							-- Set Verbose Mode To 3, Required For Correct Driver Operation
BindingID = 5001						-- Binding ID Of THe Proxy
port = 23								-- IP Port for TCP communications
cueSpeed = 1							-- Initial Fast-Foward Speed Multiplier
reviewSpeed = 1						-- Initial Rewind Speed Multiplier

--[[=============================================================================
				    COMMAND TABLE LOOKUP
===============================================================================]]

cmdMap = {
	OPEN_CLOSE = "EJT",					-- Open/Close Disc Tray
	OPEN = "EJT",						-- Open/Close Disc Tray
	CLOSE = "EJT",						-- Open/Close Disc Tray
	REQUEST_CURRENT_MEDIA_INFO = "QDT",	-- Query Disc Type
	ON = "PON",						-- Power On
	OFF = "POF",						-- Power Off
     PULSE_CH_UP = "PUP",				-- Page Up
     PULSE_CH_DOWN = "PDN",				-- Page Down
	PLAY = "PLA",						-- Play
	PAUSE = "PAU",						-- Pause
	STOP = "STP",						-- Stop
	SKIP_FWD = "NXT",					-- Next
	SCAN_FWD = "FWD",					-- Fast Forward
	SKIP_REV = "PRE",					-- Previous
	SCAN_REV = "REV",					-- Rewind
	UP = "NUP",						-- Up
	DOWN = "NDN",						-- Down
	LEFT = "NLT",						-- Left
	RIGHT = "NRT",						-- Right
	ENTER = "SEL",						-- Select
	NUMBER_0 = "NU0",					-- Number 0
	NUMBER_1 = "NU1",					-- Number 1
	NUMBER_2 = "NU2",					-- Number 2
	NUMBER_3 = "NU3",					-- Number 3
	NUMBER_4 = "NU4",					-- Number 4
	NUMBER_5 = "NU5",					-- Number 5
	NUMBER_6 = "NU6",					-- Number 6
	NUMBER_7 = "NU7",					-- Number 7
	NUMBER_8 = "NU8",					-- Number 8
	NUMBER_9 = "NU9",					-- Number 9
	DASH = "EJT",						-- Open/Close Disc Tray
	GO_TO_TRACK = "GOT",				-- Go To Chapter
     PROGRAM_A = "RED",					-- Red Button
	PROGRAM_B = "GRN",					-- Green Button
	PROGRAM_C = "YLW",					-- Yellow Button
	PROGRAM_D = "BLU",					-- Blue Button
	PVR = "",							-- Programable Button
	RECORD = "",						-- Programable Button
     POUND = "",						-- Programable Button
	STAR = "",						-- Programable Button
	CUSTOM_1 = "",						-- Programable Button
	CUSTOM_2 = "",						-- Programable Button
	CUSTOM_3 = "",						-- Programable Button
     PAGE_UP = "",						-- Programable Button
     PAGE_DOWN = "",					-- Programable Button
	INFO = "",						-- Programable Button
	MENU = "",						-- Programable Button
	GUIDE = "",						-- Programable Button
	CANCEL = "",						-- Programable Button
	RECALL = "",						-- Programable Button
}

--[[=============================================================================
			  CUSTOM REMOTE COMMANDS CONSTRUCTION
===============================================================================]]

function OnDriverInit()
     cmdMap["CUSTOM_1"] = (string.sub(Properties["Custom Button 1"],1,3))
     cmdMap["CUSTOM_2"] = (string.sub(Properties["Custom Button 2"],1,3))
     cmdMap["CUSTOM_3"] = (string.sub(Properties["Custom Button 3"],1,3))
     cmdMap["PROGRAM_A"] = (string.sub(Properties["Red"],1,3))
     cmdMap["PROGRAM_B"] = (string.sub(Properties["Green"],1,3))
     cmdMap["PROGRAM_C"] = (string.sub(Properties["Yellow"],1,3))
     cmdMap["PROGRAM_D"] = (string.sub(Properties["Blue"],1,3))
     cmdMap["STAR"] = (string.sub(Properties["Star"],1,3))
     cmdMap["POUND"] = (string.sub(Properties["Pound"],1,3))
     cmdMap["PVR"] = (string.sub(Properties["DVR"],1,3))
     cmdMap["RECORD"] = (string.sub(Properties["Record"],1,3))
     cmdMap["INFO"] = (string.sub(Properties["Info"],1,3))
     cmdMap["MENU"] = (string.sub(Properties["Menu"],1,3))
     cmdMap["CANCEL"] = (string.sub(Properties["Cancel"],1,3))
     cmdMap["GUIDE"] = (string.sub(Properties["Guide"],1,3))
     cmdMap["RECALL"] = (string.sub(Properties["Previous"],1,3))
     cmdMap["PAGE_UP"] = (string.sub(Properties["Page Up"],1,3))
     cmdMap["PAGE_DOWN"] = (string.sub(Properties["Page Down"],1,3))
end

--[[=============================================================================
				    TIMER CONSTRUCTION
===============================================================================]]

function startPWRTimer(timerDelay)
     logDebug("Power On Timer Start "..timerDelay)
	pwrTimerID = C4:AddTimer(timerDelay, "MILLISECONDS", false)
	logTrace("Set Variable - PWRTimer to Running")
	C4:SetVariable("PWRTimer", "Running")
end

function startCMDTimer(timerDelay)
     logTrace("Command Delay Timer Start "..timerDelay)
	cmdTimerID = C4:AddTimer(timerDelay, "MILLISECONDS", false)
	logTrace("Set Variable - CMDTimer to Running")
	C4:SetVariable("CMDTimer", "Running")
end

function startRCVTimer(timerDelay)
     logTrace("Receive Timer Start "..timerDelay)
	rcvTimerID = C4:AddTimer(timerDelay, "MILLISECONDS", false)
	logTrace("Set Variable - RCVTimer to Running")
end

--[[=============================================================================
				    PROXY COMMANDS
===============================================================================]]

function ReceivedFromProxy (idBinding, sCommand, tParams)
     logTrace("Check Authentication Status")
     authKey = Properties["Key"]
	authToken = (C4:GetUniqueMAC().."JFK")
	if authKey ~= authToken then
	    logFatal("Authentication = FAILED")
	    return true
     else
	    logTrace("Authentication = OKAY")
	end
     
	logDebug("command ".. sCommand)
	
	if tParams ~= nil then
	    for i=1, #tParams do
		   logDebug(tParams)
	    end
     end
     
     if sCommand ~= nil then
	    cmd = cmdMap[sCommand]
     else
	    logFatal("Proxy Command is Invalid")
	    return true
     end
     
	
     if cmd == nil then
	    logFatal("Command "..sCommand.." is Not Mapped")
	    return true
     else
	    logInfo("command "..cmd)
     end
     
     if cmd == "PON" then
	    startPWRTimer(pwrTimer)
	    SendToDevice(idBinding, cmd)
	    logTrace("Power On Send To Device")
	    table.insert(sendBuffer,SVM)
	    cueSpeed = 1
	    reviewSpeed = 1
     elseif cmd == "FWD" then
	    payload = cueSpeed
	    cueSpeed = cueSpeed + 1
	    reviewSpeed = 1
	    cmd = cmd..payloadPrefix..payload
	    table.insert(sendBuffer,cmd)
	    deviceBuffer()
	    logTrace(cmd.." Added To Buffer")
	elseif cmd == "REV" then
	    payload = reviewSpeed
	    cueSpeed = 1
	    reviewSpeed = reviewSpeed + 1
	    cmd = cmd..payloadPrefix..payload
	    table.insert(sendBuffer,cmd)
	    deviceBuffer()
	    logTrace(cmd.." Added To Buffer")
     else
	    table.insert(sendBuffer,cmd)
	    cueSpeed = 1
	    reviewSpeed = 1
	    deviceBuffer()
	    logTrace(cmd.." Added To Buffer")
     end
end

function proxyMessage(strCommand)
     logInfo("Sending to Proxy "..strCommand)
     C4:SendToProxy(BindingID, strCommand, {})
end

--[[=============================================================================
				 PROPERTY UPDATE FUNCTIONS
===============================================================================]]

function OnPropertyChanged(property)
     if property == "Power On Delay" then
	    pwrTimer = Properties["Power On Delay"]
	    logTrace("Power On Delay Changed to "..pwrTimer)
	elseif property == "Command Delay" then
	    cmdTimer = Properties["Command Delay"]
	    logTrace("Command Delay Changed to "..cmdTimer)
	elseif property == "Log Level" then 
	    logLevel = tonumber(string.sub(Properties["Log Level"],1,1))
	    logMessage = Properties["Log Level"]
	    print("Log Level Changed to "..logMessage)
     else
	    cmdMap["CUSTOM_1"] = (string.sub(Properties["Custom Button 1"],1,3))
	    cmdMap["CUSTOM_2"] = (string.sub(Properties["Custom Button 2"],1,3))
	    cmdMap["CUSTOM_3"] = (string.sub(Properties["Custom Button 3"],1,3))
	    cmdMap["PROGRAM_A"] = (string.sub(Properties["Red"],1,3))
	    cmdMap["PROGRAM_B"] = (string.sub(Properties["Green"],1,3))
	    cmdMap["PROGRAM_C"] = (string.sub(Properties["Yellow"],1,3))
	    cmdMap["PROGRAM_D"] = (string.sub(Properties["Blue"],1,3))
	    cmdMap["STAR"] = (string.sub(Properties["Star"],1,3))
	    cmdMap["POUND"] = (string.sub(Properties["Pound"],1,3))
	    cmdMap["PVR"] = (string.sub(Properties["DVR"],1,3))
	    cmdMap["RECORD"] = (string.sub(Properties["Record"],1,3))
	    cmdMap["INFO"] = (string.sub(Properties["Info"],1,3))
	    cmdMap["MENU"] = (string.sub(Properties["Menu"],1,3))
	    cmdMap["CANCEL"] = (string.sub(Properties["Cancel"],1,3))
	    cmdMap["GUIDE"] = (string.sub(Properties["Guide"],1,3))
	    cmdMap["RECALL"] = (string.sub(Properties["Previous"],1,3))
	    cmdMap["PAGE_UP"] = (string.sub(Properties["Page Up"],1,3))
	    cmdMap["PAGE_DOWN"] = (string.sub(Properties["Page Down"],1,3))     
	    logInfo("Remote Mapping Changed")
	end
end

--[[=============================================================================
				 DEVICE MESSAGING FUNCTIONS
===============================================================================]]

function OnDriverLateInit()
     SendToDevice(BindingID,SVM)
end

function OnDriverUpdate()
     SendToDevice(BindingID,SVM)
end

function deviceBuffer()
     devID = C4:GetDeviceID()
     cmdTimerCheck = C4:GetVariable(devID,CMDTimer)
	pwrTimerCheck = C4:GetVariable(devID,PWRTimer)
	logTrace("CMD Timer "..CMDTimer.." "..cmdTimerCheck)
	logTrace("PWR Timer "..PWRTimer.." "..pwrTimerCheck)
     if cmdTimerCheck == "Running" or pwrTimerCheck == "Running" then
	    logInfo("Timer is running")
	    -- do nothing
     else
	    logInfo("Timer is not running, Starting Timer")
	    startCMDTimer(cmdTimer)
     end
end

function OnTimerExpired(idTimer)
     if idTimer == cmdTimerID then
	    logDebug("CMD Timer Delay Elapsed")
	    local var = C4:SetVariable("CMDTimer", "Stopped")
	elseif idTimer == pwrTimerID then
	    logDebug("PWR Timer Delay Elapsed")
	    local var = C4:SetVariable("PWRTimer", "Stopped")
     elseif idTimer == rcvTimerID then
	    logDebug("RCV Timer Delay Elapsed")
	    processMessage()
	else
	    logWarn("UNK Timer Delay Elapsed")
	end
     if idTimer == cmdTimerID or idTimer == pwrTimerID then
	    C4:KillTimer(idTimer)
	    Instruction = table.remove(sendBuffer,1)
	    if Instruction ~= nil then
		   logInfo("Pulled From Device Buffer "..Instruction)
		   SendToDevice(BindingID, Instruction)
		   if next(sendBuffer) ~= nil then
			  startCMDTimer(cmdTimer)
		   end
	    end
     end
end

function SendToDevice(BindingID, instruction)
     logInfo("Sending command to device ".. instruction..payload)
	C4:SendToSerial("1", prefix..instruction..suffix)
	C4:SendToNetwork("6001",port, prefix..instruction..suffix)
	logDebug("Sending to network/serial "..prefix..instruction..suffix)
end

function ReceivedFromNetwork(idBinding, nPort, strData)
	ReceivedFromSerial(idBinding, strData)
end

function ReceivedFromSerial(idBinding, receivedMessage)
     logTrace("Check Authentication Status")
     authKey = Properties["Key"]
	authToken = (C4:GetUniqueMAC().."JFK")
	if authKey ~= authToken then
	    logFatal("Authentication = FAILED")
	    return true
     else
	    logTrace("Authentication = OKAY")
	end
	
	logTrace("Received Message "..receivedMessage)
	tMessage = string.match(receivedMessage,receivePrefix)
	if tMessage ~= nil and tMessage == receivePrefix then
	    processMessage()
	    if rcvTimerID ~= nil then
		   C4:KillTimer(rcvTimerID)
	    end
	    logDebug("add to receive buffer ".. receivedMessage)
	    table.insert(receiveBuffer,receivedMessage)
	    startRCVTimer(rcvTimer)
	else
	    if rcvTimerID ~= nil then
	        C4:KillTimer(rcvTimerID)
	    end
	    logDebug("add to receive buffer ".. receivedMessage)
	    table.insert(receiveBuffer,receivedMessage)
	    startRCVTimer(rcvTimer)
     end
end

--[[=============================================================================
				 MESSAGE HANDLING FUNCTIONS
===============================================================================]]

function processMessage()
     logDebug("Concat Table Message")
     tableMessage = table.concat(receiveBuffer)
     handleMessage(tableMessage)
     receiveBuffer = {}
     tableMessage = nil
end

function handleMessage(receiveMessage)
     receivedMessage = string.sub(receiveMessage,2)
	
	if (string.sub(receivedMessage,1,3)) == "UTC" then
	    C4:UpdateProperty("Time Code", receivedMessage)
     elseif receivedMessage ~= "" then
	    C4:UpdateProperty("MSG", receivedMessage)
     end
	 
     if receivedMessage == "UPL PLAY\r" then
	    proxyMessage("PLAY")
     elseif receivedMessage == "UPL PAUS\r" then
	    proxyMessage("PAUSE")
	elseif receivedMessage == "UPL STOP\r" then
	    proxyMessage("STOP")
     elseif receivedMessage == ("UPW 0\r") then
	    proxyMessage("OFF")
     elseif receivedMessage == "UPW 1\r" then
	    proxyMessage("ON")
     elseif (string.sub(receivedMessage,1,3)) == "UDT" then
	    logDebug(receivedMessage)
	    discDetection(receivedMessage)
     elseif receivedMessage == "OK 0\r" then
	   logError("Verbose Mode NOT Set")
     elseif receivedMessage == "SVM OK 3\r" or receivedMessage == "QVM OK 3\r" then
	    logDebug("Verbose Mode Set")
     elseif (string.sub(receivedMessage,1,3)) == "UPL" then
	    logDebug(receivedMessage)
	    playerDetection(receivedMessage)
     elseif (string.sub(receivedMessage,1,3)) == "UTC" then
	    logInfo(receivedMessage)
     elseif receivedMessage == "" then
	    --do nothing
	else
	    logWarn(receivedMessage)
     end
end

--[[=============================================================================
				    DEVICE EVENT FUNCTIONS
===============================================================================]]

function discDetection(receivedMessage)
     discMessage = string.sub(receivedMessage,5,9)
     logInfo(discMessage)
     if discMessage == "BDMV\r" then
	     C4:FireEvent("DISC - BDMV")
	     logTrace("Disc Detection = BDMV")
     elseif discMessage == "UHBD\r" then
	    -- C4:FireEvent("Disc - UHBD")
	    -- logTrace("Disc Detection = UHBD")
     elseif discMessage == "DVDV\r" then
	    C4:FireEvent("DISC - DVDV")
	    logTrace("Disc Detection = DVDV")
     elseif discMessage == "DVDA\r" then
	    C4:FireEvent("DISC - DVDA")
	    logTrace("Disc Detection = DVDA")
     elseif discMessage == "SACD\r" then
	    C4:FireEvent("DISC - SACD")
	    logTrace("Disc Detection = SACD")
     elseif discMessage == "CDDA\r" then
	    C4:FireEvent("DISC - CDDA")
	    logTrace("Disc Detection = CDDA")
     elseif discMessage == "DATA\r" then
	    C4:FireEvent("DISC - DATA")
	    logTrace("Disc Detection = DATA")
     elseif discMessage == "VCD2\r" then
	    C4:FireEvent("DISC - VCD2")
	   logTrace("Disc Detection = VCD2")
     elseif discMessage == "SVCD\r" then
	    C4:FireEvent("DISC - VCD")
	    logTrace("Disc Detection = SVCD")
     else
	    C4:FireEvent("DISC - OTHER")
	    logTrace("Disc Detection = OTHER")
     end
end

function playerDetection(receivedMessage)
     playerMessage = string.sub(receivedMessage,5,9)
     logInfo(playerMessage)
	if playerMessage == "Player - LOAD\r" then
	    C4:FireEvent("LOAD")
	    logTrace("Player Message = LOAD")
     elseif playerMessage == "OPEN\r" then
	    C4:FireEvent("Player - OPEN")
	    logTrace("Player Message = OPEN")
     elseif playerMessage == "CLOS\r" then
	    C4:FireEvent("Player - CLOSE")
	    logTrace("Player Message = CLOSE")
     elseif playerMessage == "HOME\r" then
	    C4:FireEvent("Player - HOME")
	    logTrace("Player Message = HOME")
     elseif playerMessage == "DISC\r" then
	    C4:FireEvent("Player - EMPTY")
	    logTrace("Player Message = EMPTY")
     elseif playerMessage == "SCSV\r" then
	    C4:FireEvent("Player - SCREEN SAVER")
	    logTrace("Player Message = SCREEN SAVER")
     end
end

--[[=============================================================================
				    DEVICE ACTION FUNCTIONS
===============================================================================]]

function ExecuteCommand (strCommand, tParams)
     if strCommand == "LUA_ACTION" then
	    if tParams ~= nil then
		   for ParamName, ParamValue in pairs(tParams) do 
			  Action(ParamValue)
		   end
	    end
     end
end

function Action(Command)
     if Command == "SETSVM" then
	    logTrace("Setting Verbose Mode")
	    SendToDevice(BindingID,SVM)
	elseif Command == "QVM" then
	    SendToDevice(BindingID,"QVM")
	elseif Command == "PrintCmdMap" then
	    for ParamName, ParamValue in pairs(cmdMap) do 
		   print(cmdMap[ParamName])
	    end
     end
end

--[[=============================================================================
				    LOGGING FUNCTIONS
===============================================================================]]

function logFatal(comment)
	if logLevel >= 1 then
	    print("FATAL - "..comment)
	end
end

function logError(comment)
	if logLevel >= 2 then
	    print("ERROR - "..comment)
	end
end

function logWarn(comment)
	if logLevel >= 3 then
	    print("WARNING - "..comment)
	end
end

function logInfo(comment)
	if logLevel >= 4 then
	    print("INFO - "..comment)
	end
end

function logDebug(comment)
	if logLevel >= 5 then
	    print("DEBUG - "..comment)
	end
end

function logTrace(comment)
	if logLevel >= 6 then
	    print("TRACE - "..comment)
	end
end
