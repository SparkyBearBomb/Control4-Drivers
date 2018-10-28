


function OnDriverLateInit()
     sendBuffer = {}
     logLevel = tonumber(string.sub(Properties["Log Level"],1,1))
     C4:DeleteVariable("CMDTimer")
     bool2,CMDTimer = C4:AddVariable("CMDTimer", "Stopped", "STRING", false, true)
	C4:RegisterVariableListener(Properties["Device Monitor"], 1000)
	print("Register Device")
	if (C4:PersistGetValue("delayTimer")) ~= nil then
	    cmdTimer = C4:PersistGetValue("delayTimer")
	    C4:UpdateProperty("Command Delay", cmdTimer)
	else
	    cmdTimer = Properties["Command Delay"]
	end
     if (C4:PersistGetValue("deviceMonitorID")) ~= nil then
	    deviceMonitor = C4:PersistGetValue("deviceMonitorID")
	    C4:UpdateProperty("Device Monitor", deviceMonitor)
	    C4:RegisterVariableListener(deviceMonitor, 1000)
	else
	    deviceMonitor = Properties["Device Monitor"]
	    C4:RegisterVariableListener(deviceMonitor, 1000)
	end
    	if (C4:PersistGetValue("relayDirection")) ~= nil then
	    invertRelay = C4:PersistGetValue("relayDirection")
	    C4:UpdateProperty("Invert Direction Relay", invertRelay)
	else
	    invertRelay = Properties["Invert Direction Relay"]
	end
end

function startCMDTimer(timerDelay)
     if timerDelay == nil then
	    logWarn("Invalid Delay Timer, Grabbing New Timer")
	    timerDelay = Properties["Command Delay"]
	end
     logTrace("Command Delay Timer Start "..timerDelay)
	cmdTimerID = C4:AddTimer(timerDelay, "MILLISECONDS", false)
	logTrace("Set Variable - CMDTimer to Running")
	C4:SetVariable("CMDTimer", "Running")
end

function OnPropertyChanged(property)
     if property == "Command Delay" then
	    cmdTimer = Properties["Command Delay"]
	    logTrace("Command Delay Changed to "..cmdTimer)
	    C4:PersistSetValue("delayTimer", cmdTimer)
	elseif property == "Log Level" then 
	    logLevel = tonumber(string.sub(Properties["Log Level"],1,1))
	    logMessage = Properties["Log Level"]
	    print("Log Level Changed to "..logMessage)
     elseif property == "Device Monitor" then
	    deviceMonitor = Properties["Device Monitor"]
	    C4:PersistSetValue("deviceMonitorID", deviceMonitor)
	    if deviceMonitor ~= "" then
		   deviceName = C4:GetDeviceDisplayName(deviceMonitor)
		   logTrace("Monitoring Device = "..deviceName.." "..deviceMonitor)
		   if oldDeviceMonitor ~= nil then
			  C4:UnregisterVariableListener(oldDeviceMonitor,1000)
		   end
		   oldDeviceMonitor = deviceMonitor
		   C4:RegisterVariableListener(deviceMonitor, 1000)
	    else
		   if oldDeviceMonitor ~= nil then
			  C4:UnregisterVariableListener(oldDeviceMonitor,1000)
		   end
		   logTrace("End Monitoring")
	    end
     elseif property == "Invert Direction Relay" then
	    invertRelay = Properties["Invert Direction Relay"]
	    C4:PersistSetValue("relayDirection", invertRelay)
	    logTrace("Relay Inversion Set")
     end
end

function OnWatchedVariableChanged (dev,var,val)
     logTrace("Variable Monitoring "..dev.." "..var.." "..val)
	var = tonumber(var)	
	val = tonumber(val)
	if var == 1000 and val == 1 then
	    open(5001)
	    logInfo("The "..(C4:GetDeviceDisplayName(deviceMonitor)).." Has Powered On")
	elseif var == 1000 and val == 0 then
	    close(5001)
	    logInfo("The "..(C4:GetDeviceDisplayName(deviceMonitor)).." Has Powered Off")
	end	
end

function ReceivedFromProxy (id, sCommand, tParams)
	logTrace("Received From Proxy, ID:"..id.." Command:"..sCommand)
     if sCommand == "BLINDS_STOP" then
	    stop(id)
	elseif sCommand == "BLINDS_OPEN" then
	    close(id)
	elseif sCommand == "BLINDS_CLOSE" then
	    open(id)
	elseif sCommand == "BLINDS_TOGGLE" then
	    toggle(id)
     elseif id == 1 then
	    C4:UpdateProperty("POWER RELAY STATE", sCommand)
	elseif id == 2 then
	    C4:UpdateProperty("DIRECTION RELAY STATE", sCommand)
	else
	    logError("Unknown Command",sCommand)
	end
end

function open(id)
     table.insert(sendBuffer,((string.format(1)).."OPEN"))
	if Properties["Invert Direction Relay"] == "TRUE" then
	    table.insert(sendBuffer,((string.format(2)).."OPEN"))
	else
	    table.insert(sendBuffer,((string.format(2)).."CLOSE"))
	end
	table.insert(sendBuffer,((string.format(1)).."CLOSE"))
	table.insert(sendBuffer,((string.format(1)).."OPEN"))
	table.insert(sendBuffer,((string.format(2)).."OPEN"))
     name = (C4:GetDeviceID()).."Relay"
     state = C4:Base64Encode("OPEN")
     C4:PersistSetValue(name, state)
     logDebug("Relay Open")
	deviceBuffer()
     C4:SendToProxy(id, "OPEN",{})
end



function close(id)
     table.insert(sendBuffer,((string.format(1)).."OPEN"))
	if Properties["Invert Direction Relay"] == "TRUE" then
	    table.insert(sendBuffer,((string.format(2)).."CLOSE"))
	else
	    table.insert(sendBuffer,((string.format(2)).."OPEN"))
	end
	table.insert(sendBuffer,((string.format(1)).."CLOSE"))
	table.insert(sendBuffer,((string.format(1)).."OPEN"))
	table.insert(sendBuffer,((string.format(2)).."OPEN"))
	name = (C4:GetDeviceID()).."Relay"
	state = C4:Base64Encode("CLOSE")
	C4:PersistSetValue(name, state)
	logDebug("Relay Close")
	deviceBuffer()
	C4:SendToProxy(id, "CLOSE",{})
end

function stop(id)

     logDebug("STOP")
     C4:SendToProxy(id, "STOP",{})
end

function toggle(id)
     name = (C4:GetDeviceID()).."Relay"
     state = C4:PersistGetValue(name)
     if state ~= nil then
	    state = C4:Base64Decode(state)
	    if state == "OPEN" then
		   close(id)
	    elseif state == "CLOSE" then
		   open(id)
	    else
		   logError("Unknown State")
	    end
     end
     
end  

function deviceBuffer()
     devID = C4:GetDeviceID()
     cmdTimerCheck = C4:GetVariable(devID,CMDTimer)
	logTrace("CMD Timer "..CMDTimer.." "..cmdTimerCheck)
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
	else
	    logWarn("UNK Timer Delay Elapsed")
	end
     if idTimer == cmdTimerID then
	    C4:KillTimer(idTimer)
	    message = table.remove(sendBuffer,1)
	    if message ~= nil then
		   logDebug("Pulled From Device Buffer "..message)
		   state = string.sub(message,2)
		   relayID = string.sub(message,1,1)
		   relayControl(relayID, state)
		   if next(sendBuffer) ~= nil then
			  startCMDTimer(cmdTimer)
		   end
	    end
     end
end

function relayControl(relayID, state)
     logTrace("Send To Proxy "..relayID.." "..state)
     C4:SendToProxy (relayID, state,"")
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
