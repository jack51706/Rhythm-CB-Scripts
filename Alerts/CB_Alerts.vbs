'Cb Response Alert Dump

'Copyright (c) 2020 Ryan Boyle randomrhythm@rhythmengineering.com.

'This program is free software: you can redistribute it and/or modify
'it under the terms of the GNU General Public License as published by
'the Free Software Foundation, either version 3 of the License, or
'(at your option) any later version.

'This program is distributed in the hope that it will be useful,
'but WITHOUT ANY WARRANTY; without even the implied warranty of
'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'GNU General Public License for more details.

'You should have received a copy of the GNU General Public License
'along with this program.  If not, see <http://www.gnu.org/licenses/>.

dim strCarBlackAPIKey
Dim StrCBfilePath
Dim StrCBdigSig
Dim StrCBcompanyName
Dim StrCBproductName
Dim StrCBFileSize
Dim StrCBprevalence
Dim StrCBMD5
Dim intTotalQueries
Dim IntDaysQuery
Dim strStartDateQuery
Dim strEndDateQuery
Dim strHashOutPath
Const forwriting = 2
Const ForAppending = 8
Const ForReading = 1
Dim DictIPAddresses: set DictIPAddresses = CreateObject("Scripting.Dictionary")'
Dim DictFeedInfo: set DictFeedInfo = CreateObject("Scripting.Dictionary")'
Dim DictFeedExclude: set DictFeedExclude = CreateObject("Scripting.Dictionary")'
Dim boolHeaderWritten
Dim boolEchoInfo
Dim intSleepDelay
Dim intPagesToPull
Dim intSizeLimit
Dim intReceiveTimeout
Dim boolUseSocketTools
Dim strLicenseKey
Dim boolOutputID
Dim boolOutputWID
Dim strAPIVersion
Dim objFSO: Set objFSO = CreateObject("Scripting.FileSystemObject")

'---Config Section
APIVersion = 2
strReportPath = "\Reports" 'directory to write report output
boolOutputID = True 'Alert ID
boolOutputWID = True 'Watchlist ID
IntDayStartQuery = "-9" 'days to go back for start date of query. Set to * to query all 
IntDayEndQuery = "*" 'days to go back for end date of query. Set to * for no end date
strTimeMeasurement = "d" '"h" for hours "d" for days
'DictFeedExclude.add "SRSThreat", 0 'exclude feed
'DictFeedExclude.add "NVD", 0 'exclude feed
'DictFeedExclude.add "SRSTrust", 0 'exclude feed
'DictFeedExclude.add "cbemet", 0 'exclude feed
'DictFeedExclude.add "attackframework", 0 'exclude feed due to large amounts of alerts
intSleepDelay = 90000 'delay between queries
intPagesToPull = 20 'Number of alerts to retrieve at a time
intSizeLimit = 20000 'don't dump more than this number of pages per feed
intReceiveTimeout = 120 'number of seconds for timeout
boolUseSocketTools = False 'Uses external library from SocketTools (needed when using old OS that does not support latest TLS standards)
strLicenseKey = "" 'License key is required to use SocketTools 
strIniPath="Cb_Alerts.ini"
strReportPath = "\Reports" 'directory to write report output
'---End Config section

'---Debug
BoolDebugTrace = False
boolEchoInfo = False 
'---End Debug

if objFSO.FileExists(strIniPath) = True then
'---Ini loading section
	IntDayStartQuery = ValueFromINI(strIniPath, "IntegerValues", "StartTime", IntDayStartQuery)
	IntDayEndQuery = ValueFromINI(strIniPath, "IntegerValues", "EndTime", IntDayEndQuery)
	strTimeMeasurement = ValueFromINI(strIniPath, "StringValues", "TimeMeasurement", strTimeMeasurement)
	intSleepDelay = ValueFromINI(strIniPath, "IntegerValues", "SleepDelay", intSleepDelay)
	intPagesToPull = ValueFromINI(strIniPath, "IntegerValues", "PagesToPull", intPagesToPull)
	intSizeLimit = ValueFromINI(strIniPath, "IntegerValues", "SizeLimit", intSizeLimit)
	intReceiveTimeout = ValueFromINI(strIniPath, "IntegerValues", "ReceiveTimeout", intReceiveTimeout)
	boolUseSocketTools = ValueFromINI(strIniPath, "BooleanValues", "UseSocketTools", boolUseSocketTools)
	BoolDebugTrace = ValueFromINI(strIniPath, "BooleanValues", "Debug", BoolDebugTrace)
	APIVersion = ValueFromINI(strIniPath, "IntegerValues", "APIVersion", APIVersion)	
'---End ini loading section
else
	if BoolRunSilent = False then WScript.Echo strFilePath & " does not exist. Using script configured/default settings instead"
end if

if isnumeric(IntDayStartQuery) then
  strStartDateQuery = DateAdd(strTimeMeasurement,IntDayStartQuery,now)

  ' AND server_added_timestamp:[" & strStartDateQuery & "T00:00:00 TO "
  strStartDateQuery = " AND created_time:[" & FormatDate (strStartDateQuery) & " TO "
  if IntDayEndQuery = "*" then
    strEndDateQuery = "*]"
  elseif isnumeric(IntDayEndQuery) then
    strEndDateQuery = DateAdd(strTimeMeasurement,IntDayEndQuery,now)
    strEndDateQuery = FormatDate (strEndDateQuery) & "]"
  end if
end if

if cint(APIVersion) > 2 then
  msgbox "API version " & APIVersion & " is not supported. Changing to V2"
  APIVersion = 2
end if

CurrentDirectory = GetFilePath(wscript.ScriptFullName)
strDebugPath = CurrentDirectory & "\Debug\"
strSSfilePath = CurrentDirectory & "\CBIP_" & udate(now) & ".csv"

strRandom = "4bv3nT9vrkJpj3QyueTvYFBMIvMOllyuKy3d401Fxaho6DQTbPafyVmfk8wj1bXF" 'encryption key. Change if you want but can only decrypt with same key

if BoolDebugTrace = False and objFSO.folderexists(strDebugPath) = False then _
objFSO.createfolder(strDebugPath)
if instr(strReportPath, ":") = 0 then 
	strReportPath = CurrentDirectory & "\" & strReportPath
end if
if objFSO.folderexists(strReportPath) = False then _
objFSO.createfolder(strReportPath)

strFile= CurrentDirectory & "\cb.dat"
strAPIproduct = "Carbon Black" 


strData = ""
if objFSO.fileexists(strFile) then
  Set objFile = objFSO.OpenTextFile(strFile)
  if not objFile.AtEndOfStream then 'read file
      On Error Resume Next
      strData = objFile.ReadLine 
      StrBaseCBURL = objFile.ReadLine

      on error goto 0
  end if
  if strData <> "" then
    strData = Decrypt(strData,strRandom)
      strTempAPIKey = "apikey=" & strData
      strData = ""
  end if
end if

if not objFSO.fileexists(strFile) and strData = "" then
  strTempAPIKey = inputbox("Enter your " & strAPIproduct & " api key")
  if strTempAPIKey <> "" then
  strTempEncryptedAPIKey = strTempAPIKey
    strTempEncryptedAPIKey = encrypt(strTempEncryptedAPIKey,strRandom)
    logdata strFile,strTempEncryptedAPIKey,False
    strTempEncryptedAPIKey = ""
    StrBaseCBURL = inputbox("Enter your " & strAPIproduct & " base URL (example: https://ryancb-example.my.carbonblack.io")
    logdata strFile,StrBaseCBURL,False
  end if
end if  
if strTempAPIKey = "" then

    msgbox "invalid api key"
    wscript.quit(999)
end if

if instr(strTempAPIKey,"apikey=") then
  strCarBlackAPIKey = replace(strTempAPIKey,"apikey=","")
else
  strCarBlackAPIKey = strTempAPIKey
end if

if strCarBlackAPIKey <> "" and StrBaseCBURL <> "" then BoolUseCarbonBlack = True   

on error resume next
objFile.close
on error goto 0
strTempAPIKey = ""




intTotalQueries = 50
'get feed info  
DumpCarBlack 0, False, intTotalQueries, "/api/v1/feed"
'get watchlist info
DumpCarBlack 0, False, intTotalQueries, "/api/v1/watchlist"

for each strCBFeedID in DictFeedInfo
  'msgbox "DictFeedExclude.exists(" & DictFeedInfo.item(strCBFeedID) & ")=" & DictFeedExclude.exists(strCBFeedID)
  if DictFeedExclude.exists(DictFeedInfo.item(strCBFeedID)) = False Then
  	If InStr(strCBFeedID, "watchlist_id:") > 0 Then
  		strTmpWatchName = DictFeedInfo.item(strCBFeedID)
  		If InStr(strTmpWatchName," ") > 0 Then strTmpWatchName = Chr(34) & strTmpWatchName & Chr(34) 'contains whitespace
  		strQueryFeed = "/api/v" & APIVersion & "/alert?q=" & strCBFeedID & strStartDateQuery & strEndDateQuery
  	Else	
    	strQueryFeed = "/api/v" & APIVersion & "/alert?q=feed_name:" & DictFeedInfo.item(strCBFeedID)  & strStartDateQuery & strEndDateQuery
    End if	
   
    if strQueryFeed <> "" then
      wscript.sleep 10
      intCBcount = 10
      boolHeaderWritten = False
      strHashOutPath = strReportPath & "\CBalert_" & DictFeedInfo.item(strCBFeedID) & "_" & udate(now) & ".csv"
      intTotalQueries = DumpCarBlack(0, True, intCBcount, strQueryFeed)
      wscript.sleep intSleepDelay
      logdata CurrentDirectory & "\CB_Alerts.log", date & " " & time & ": " & "Total number of items being retrieved for feed " & DictFeedInfo.item(strCBFeedID) & ": " & intTotalQueries ,boolEchoInfo
      
      if clng(intTotalQueries) > 0 then
        				'still have pages to pull    OR   initial amount is less than intCBcount
        do while (intCBcount < clng(intTotalQueries) Or clng(intTotalQueries) < intCBcount And intCBcount < CLng(intPagesToPull)) and intCBcount < intSizeLimit

          If BoolDebugTrace = True Then logdata strDebugPath & "\follow_queries.log" , date & " " & time & " " & DictFeedInfo.item(strCBFeedID) & ": " & intCBcount & " < " & intTotalQueries & " and " & intCBcount & " < " & intSizeLimit, false
          DumpCarBlack intCBcount, True, intPagesToPull, strQueryFeed
          intCBcount = intCBcount + intPagesToPull
          wscript.sleep intSleepDelay
        loop
      end if
      strSSfilePath = strReportPath & "\CBIP_" & DictFeedInfo.item(strCBFeedID) & "_" & udate(now) & ".csv"
      For each item in DictIPAddresses
        LogData strSSfilePath, item & "|" & DictIPAddresses.item(item), False
      next
      DictIPAddresses.RemoveAll
     
    else
      msgbox "Parser not configured for " & DictFeedInfo.item(strCBFeedID)
    end if
  end if
next


Function DumpCarBlack(intCBcount,BoolProcessData, intCBrows, strURLQuery)

Set objHTTP = CreateObject("MSXML2.ServerXMLHTTP")
Dim strAVEurl
Dim strReturnURL
dim strAssocWith
Dim strCBresponseText
Dim strtmpCB_Fpath
Dim StrTmpFeedIP

strAVEurl = StrBaseCBURL & strURLQuery 

if BoolProcessData = True then strAVEurl = strAVEurl & "&start=" & intCBcount & "&rows=" & intCBrows

if boolUseSocketTools = False then
	objHTTP.SetTimeouts 600000, 600000, 600000, 900000 
	objHTTP.open "GET", strAVEurl, True

	objHTTP.setRequestHeader "X-Auth-Token", strCarBlackAPIKey 
	  

	on error resume next
	  objHTTP.send
	  If objHTTP.waitForResponse(intReceiveTimeout) Then 'response ready
			'success!
		Else 'wait timeout exceeded
			logdata CurrentDirectory & "\CB_Error.log", Date & " " & Time & " CarBlack lookup failed due to timeout", False
			exit function  
		End If 
	  if err.number <> 0 then
		logdata CurrentDirectory & "\CB_Error.log", Date & " " & Time & " CarBlack lookup failed with HTTP error. - " & err.description,False 
		logdata CurrentDirectory & "\CB_Error.log", Date & " " & Time & " HTTP status code - " & objHTTP.status,False 
		exit function 
	  end if
	on error goto 0  
	'creates a lot of data. Don't uncomment next line unless your going to disable it again
	if BoolDebugTrace = True then logdata strDebugPath & "\CarBlack" & "" & ".txt", objHTTP.responseText & vbcrlf & vbcrlf,BoolEchoLog 
	strCBresponseText = objHTTP.responseText
else
  strCBresponseText = SocketTools_HTTP(strAVEurl)
end if

if instr(strCBresponseText, "b Response Cloud is currently undergoing maintenance and will be back shortly") > 0 then
  wscript.sleep 240000 
  DumpCarBlack = DumpCarBlack(intCBcount,BoolProcessData, intCBrows, strURLQuery)
  exit function
end If
boolNoSpaces = False
'msgbox strCBresponseText
if instr(strCBresponseText, vblf & "    {") Then 'response contains alert data
  strArrayCBresponse = split(strCBresponseText, vblf & "    {")
elseif instr(strCBresponseText, vblf & "  {") Then 'response contains feed data
  strArrayCBresponse = split(strCBresponseText, vblf & "  {")
else  'response contains watchlist data or empty alert data
  strArrayCBresponse = split(strCBresponseText, "{")
  boolNoSpaces = True
end if
for each strCBResponseEntry in strArrayCBresponse

  if len(strCBResponseEntry) > 1 then
    'logdata strDebugPath & "cbresponse.log", strCBResponseEntry, True

      if instr(strCBResponseEntry, "provider_url" & Chr(34) & ":") > 0 and instr(strCBresponseText, "id" & Chr(34) & ":") > 0 Then
        strTmpFeedID = getdata(strCBResponseEntry, ",", "id" & Chr(34) & ": ")
        strTmpFeedName = getdata(strCBResponseEntry, Chr(34), Chr(34) & "name" & Chr(34) & ": " & Chr(34))
        If strTmpFeedID <> "" Then strTmpFeedID = "feed_name:" & strTmpFeedID
        if DictFeedInfo.exists(strTmpFeedID) = false then DictFeedInfo.add strTmpFeedID, lcase(strTmpFeedName)
      elseif instr(strCBresponseText, "search_query" & Chr(34) & ":") > 0 And instr(strCBresponseText, "id" & Chr(34) & ":") > 0 Then
        spaceOrNone = ""
        If boolNoSpaces = False Then spaceOrNone = " "
        strTmpwatchlistID = getdata(strCBResponseEntry, Chr(34), Chr(34) & "id" & Chr(34) & ":" & spaceOrNone & Chr(34))
        strTmpWLName = getdata(strCBResponseEntry, Chr(34), Chr(34) & "name" & Chr(34) & ":" & spaceOrNone & Chr(34))
        strTmpActualWatchlistQuery = getdata(strCBResponseEntry, Chr(34), Chr(34) & "search_query" & Chr(34) & ":" & spaceOrNone & Chr(34))
        strTmpWatchlistQuery = "/api/v1/process?q=watchlist_" & strTmpwatchlistID & ":*"
      	If strTmpwatchlistID <> "" Then 
      		strTmpwatchlistID = "watchlist_id:" & strTmpwatchlistID
      		If DictFeedInfo.exists(strTmpwatchlistID) = false then DictFeedInfo.add strTmpwatchlistID, strTmpWLName
      	End if	
      elseif BoolProcessData = True then 
        if instr(strCBresponseText, "total_results" & Chr(34) & ": ") > 0 then
          DumpCarBlack = getdata(strCBresponseText, ",", "total_results" & Chr(34) & ": ")
        
          if instr(strCBResponseEntry, "ioc_value") > 0 Or instr(strCBResponseEntry, "ioc_type") > 0 then
            LogIOCdata strCBResponseEntry, True, boolNoSpaces
          else
            If BoolDebugTrace = True Then LogData currentdirectory & "\ioc_value.log", "Debug - did not contain ioc_value: " & strCBResponseEntry, False
          end if
        else
             If BoolDebugTrace = True Then logdata currentdirectory & "\total_results.log" , "Debug - did not contain total_results: " & strCBresponseText, False
        end if
      end if

  end if

next

set objHTTP = nothing
end function

Function GetData(contents, ByVal EndOfStringChar, ByVal MatchString)
MatchStringLength = Len(MatchString)
x= instr(contents, MatchString)

  if X >0 then
    strSubContents = Mid(contents, x + MatchStringLength, len(contents) - MatchStringLength - x +1)
    if instr(strSubContents,EndOfStringChar) > 0 then
      GetData = Mid(contents, x + MatchStringLength, instr(strSubContents,EndOfStringChar) -1)
      exit function
    else
      GetData = Mid(contents, x + MatchStringLength, len(contents) -x -1)
      exit function
    end if
    
  end if
GetData = ""
end Function


Sub LogIOCdata(strCBresponseText, boolLogAll, boolNoSpaces)
spaceValue = ""
If boolNoSpaces = True Then spaceValue = " "
if instr(strCBresponseText, "ioc_value") > 0 or instr(strCBresponseText, "ioc_type") > 0 then 

  strCBfilePath = getdata(strCBresponseText, Chr(34), "process_path" & Chr(34) & ": " & Chr(34))
  strioc_value = getdata(strCBresponseText, Chr(34), "ioc_value" & Chr(34) & ": " & Chr(34))
  if strioc_value = "" then 
    strioc_value = getdata(strCBresponseText, "}", "ioc_value" & Chr(34) & ": " & Chr(34) & "{")
  end If
  if strioc_value = "" then 
  	strIOCval = getdata(strCBresponseText, Chr(34), "ioc_type" & Chr(34) & ": " & Chr(34))
  	If strIOCval = "query" Then
  		strioc_value = getdata(strCBresponseText, "}", "ioc_attr" & Chr(34) & ": " & Chr(34) & "{")
  	End If	
  End if
  boolQueryIOC = False
  if strioc_value = "{\" then 'gets query string for alert (behavior)
	strioc_value = getdata(strCBresponseText, "}", "ioc_value" & Chr(34) & ": " & Chr(34) & "{")
	boolQueryIOC = True
  end if
  interface_ip = getdata(strCBresponseText, Chr(34), "interface_ip" & Chr(34) & ": " & Chr(34))
  sensor_id = getdata(strCBresponseText, Chr(34), "sensor_id" & Chr(34) & ": " & Chr(34))
  strdescription = getdata(strCBresponseText, Chr(34), "description" & Chr(34) & ": " & Chr(34))
  search_query = getdata(strCBresponseText, Chr(34), "search_query" & Chr(34) & ": " & Chr(34))
  StrCBMD5 = getdata(strCBresponseText, Chr(34), "md5" & Chr(34) & ": " & Chr(34))
  strCBprevalence = getdata(strCBresponseText, ",", "hostCount" & Chr(34) & ": ")
  strCBHostname = getdata(strCBresponseText, Chr(34), "hostname" & Chr(34) & ": " & Chr(34))
  strstatus = getdata(strCBresponseText, Chr(34), "status" & Chr(34) & ": " & Chr(34)) '"status": "Unresolved"
  created_time = getdata(strCBresponseText, Chr(34), "created_time" & Chr(34) & ": " & Chr(34))
  resolved_time= getdata(strCBresponseText, Chr(34), "resolved_time" & Chr(34) & ": " & Chr(34))
  process_name = getdata(strCBresponseText, Chr(34), "process_name" & Chr(34) & ": " & Chr(34))
  process_id = getdata(strCBresponseText, Chr(34), "process_id" & Chr(34) & ": " & Chr(34))
  segment_id = getdata(strCBresponseText, ",", "segment_id" & Chr(34) & ": " )
  netconn_count = getdata(strCBresponseText, ",", "netconn_count" & Chr(34) & ": ")
  unique_id = getdata(strCBresponseText, Chr(34), "unique_id" & Chr(34) & ": " & Chr(34))
  watchlist_id = getdata(strCBresponseText, Chr(34), "watchlist_id" & Chr(34) & ": " & Chr(34))
  if instr(strCBresponseText,"ioc_attr") Then 'might want to add this And strIOCval <> "query"
    iocSection = getdata(strCBresponseText, "}", "ioc_attr" & Chr(34) & ": " & Chr(34) & "{")
    strDirection = getdata(iocSection, "\", "direction\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strprotocol = getdata(iocSection, "\", "protocol\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strlocal_port = getdata(iocSection, "\", "local_port\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strdns_name = getdata(iocSection, "\", "dns_name\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strlocal_ip = getdata(iocSection, "\", "local_ip\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strport = getdata(iocSection, "\", "remote_port\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
    strremote_ip = getdata(iocSection, "\", "remote_ip\" & Chr(34) & ":" & spaceValue & "\" & Chr(34))
  end if  
  if strCBHostname = "" then
    strTmpCBHostname = getdata(strCBresponseText, "]", "hostnames" & Chr(34) & ": [" & vblf & "        " & Chr(34))
    if instr(strTmpCBHostname, "|") then
      arrayCBHostName = split(strTmpCBHostname, "|")
      for each CBNames in arrayCBHostName
        arrayCBnames = split(CBNames, vbLf)
        for each CBhostName in arrayCBnames
          strTmpCBHostname = replace(CBhostName, Chr(34), "")
          strTmpCBHostname = replace(strTmpCBHostname, " ","" )
          if isnumeric(strTmpCBHostname) = False and strTmpCBHostname <> "" then
            'msgbox strTmpCBHostname
            if strCBHostname = "" then
              strCBHostname = strTmpCBHostname
            else
              strCBHostname= strCBHostname & "/" & strTmpCBHostname
            end if
          end if
        next
      next
    end if
  end if

  alert_severity = getdata(strCBresponseText, ",", "alert_severity" & Chr(34) & ": ")

  strtmpCB_Fpath = getfilepath(strCBfilePath)
  'RecordPathVendorStat strtmpCB_Fpath 'record path vendor statistics
end if


if IsHash(strioc_value) = True then 
	logdata strReportPath & "\IOC_MD5.txt", strioc_value, false
elseif IsIPaddress(strioc_value) = True then
	logdata strReportPath & "\IOC_IP.txt", strioc_value, false
elseif boolQueryIOC = True then
	logdata strReportPath & "\IOC_Query.txt", strioc_value, false
elseif instr(strioc_value, "$") = 0 And strioc_value <> "" then
	logdata strReportPath & "\IOC_Domain.txt", strioc_value, false
ElseIf  strioc_value <> "" then
	logdata strReportPath & "\IOCs.txt", strioc_value, false
end if

if strioc_value = "" and BoolDebugTrace = True then 
	logdata strDebugPath & "\ioc_value.log", "Debug - did not contain ioc_value: " & strCBresponseText, False
end If
If strIOCval = "query" Then strioc_value = "query"
If strioc_value <> "" then
  strioc_value = replace(strioc_value, Chr(34), "") 'value provided can contain characters that mess with CSV output
  strioc_value = replace(strioc_value, ",", "")
  strCBfilePath = AddPipe(strCBfilePath) 'CB File Path
  process_name = AddPipe(process_name) 'CB Digital Sig
  netconn_count = AddPipe(netconn_count)'CB Company Name
  strstatus = AddPipe(strstatus) 'Product Name        
  strCBFileSize = AddPipe(strCBFileSize)  
  strCBprevalence = AddPipe(strCBprevalence)
  strCBHostname = AddPipe(strCBHostname)
  interface_ip = AddPipe(interface_ip)
  strdescription = AddPipe(strdescription)
  sensor_id = AddPipe(sensor_id)
  alert_severity = AddPipe(strCBcmdline)
  StrCBMD5 = AddPipe(StrCBMD5)
  
  IOC_Entries = ""
  IOC_Head = ""

  if instr(strCBresponseText,"ioc_attr") then
    strDirection = AddPipe(strDirection)
    strprotocol = AddPipe(strprotocol)
    strlocal_port = AddPipe(strlocal_port)
    strdns_name = AddPipe(strdns_name)
    strlocal_ip = AddPipe(strlocal_ip)
    strport = AddPipe(strport)
    strremote_ip = AddPipe(strremote_ip)
    search_query = AddPipe(search_query)
    created_time = AddPipe(created_time)
    resolved_time = AddPipe(resolved_time)
    process_id = AddPipe(process_id)
    segment_id = AddPipe(segment_id)
    IOC_Entries = strDirection & strprotocol & strlocal_port & strdns_name & strlocal_ip & strport & strremote_ip & created_time & resolved_time & search_query & process_id & segment_id
    IOC_Head = ",Direction, Protocol, Local Port, DNS Name, Local IP, Port, Report IP, Creation Time, Resolve Time, search_query, Process ID, Segment ID"
  end if
  endHead = ",Host Name"
  if boolOutputID = True then 
	endHead = endHead & ", AlertID"
	unique_id = addPipe(unique_id)
  else
	unique_id = ""
  end if	
    if boolOutputWID = True then 
	endHead = endHead & ", WatchlistID"
	watchlist_id = addPipe(watchlist_id)
  else
	watchlist_id = ""
  end if	
  

  if boolHeaderWritten = False then
      strSSrow = "IOC,MD5,Path," & "process_name," & "netconn_count," & "Status," & "CB Prevalence,interface_ip, sensor_id, Description, Severity" & IOC_Head & endHead
      logdata strHashOutPath, strSSrow, False
      boolHeaderWritten = True
  END IF

  strSSrow = strioc_value & StrCBMD5 & strCBfilePath & process_name & netconn_count & strstatus & strCBprevalence & interface_ip  & sensor_id & strdescription & alert_severity & IOC_Entries & strCBHostname & unique_id & watchlist_id
  strTmpSSlout = Chr(34) & replace(strSSrow, "|",Chr(34) & "," & Chr(34)) & Chr(34)
  logdata strHashOutPath, strTmpSSlout, False
end if
strCBfilePath = ""
strCBdigSig = ""
strCBcompanyName = ""
strCBproductName = ""
strCBFileSize = ""
strCBprevalence = "" 
StrCBMD5 = "" 
strCBHostname = ""
strCBInfoLink = ""
strCBcmdline = ""
parent_name = ""
end sub




function LogData(TextFileName, TextToWrite,EchoOn)
Set fsoLogData = CreateObject("Scripting.FileSystemObject")
If InStr(TextFileName, "/") > 0 Then TextFileName = Replace(TextFileName, "/", "_")
if EchoOn = True then wscript.echo TextToWrite
  If fsoLogData.fileexists(TextFileName) = False Then
      'Creates a replacement text file 
      on error resume next
      fsoLogData.CreateTextFile TextFileName, True
      if err.number <> 0 and err.number <> 53 then msgbox "can't create file " & Chr(34) & TextFileName & Chr(34) & ": " & err.number & " " & err.description & vbcrlf & TextFileName
      on error goto 0
  End If
if TextFileName <> "" then


  Set WriteTextFile = fsoLogData.OpenTextFile(TextFileName,ForAppending, False)
  on error resume next
  WriteTextFile.WriteLine TextToWrite
  if err.number <> 0 then 
    on error goto 0
    WriteTextFile.Close
  Dim objStream
  Set objStream = CreateObject("ADODB.Stream")
  objStream.CharSet = "utf-16"
  objStream.Open
  objStream.WriteText TextToWrite
  on error resume next
  objStream.SaveToFile TextFileName, 2
  if err.number <> 0 then msgbox err.number & " - " & err.message & " Problem writting to " & TextFileName
  if err.number <> 0 then msgbox "problem writting text: " & TextToWrite
  on error goto 0
  Set objStream = nothing
  end if
end if
Set fsoLogData = Nothing
End Function

Function GetFilePath (ByVal FilePathName)
found = False

Z = 1

Do While found = False and Z < Len((FilePathName))

 Z = Z + 1

         If InStr(Right((FilePathName), Z), "\") <> 0 And found = False Then
          mytempdata = Left(FilePathName, Len(FilePathName) - Z)
          
             GetFilePath = mytempdata

             found = True

        End If      

Loop

end Function
function UDate(oldDate)
    UDate = DateDiff("s", "01/01/1970 00:00:00", oldDate)
end function

Sub ExitExcel()
if BoolUseExcel = True then
  objExcel.DisplayAlerts = False
  objExcel.quit
end if
end sub
Function RemoveTLS(strTLS)
dim strTmpTLS
if len(strTLS) > 0 then
  for rmb = 1 to len(strTLS)
    if mid(strTLS, rmb, 1) <> " " then
      strTmpTLS = right(strTLS,len(strTLS) - RMB +1)
      exit for
    end if
  next
end if

if len(strTmpTLS) > 0 then
  for rmb = len(strTmpTLS)  to 1 step -1

    if mid(strTmpTLS, rmb, 1) <> " " then
      strTmpTLS = left(strTmpTLS,len(strTmpTLS) - (len(strTmpTLS) - RMB))
      exit for
    end if
  next
end if

RemoveTLS = strTmpTLS
end Function

Function AddPipe(strpipeless)
dim strPipeAdded

if len(strpipeless) > 0 then
  if left(strpipeless, 1) <> "|" then 
    strPipeAdded = "|" & strpipeless

  else
    strPipeAdded = strpipeless
  end if  
else
  strPipeAdded = "|"
end if

AddPipe = strPipeAdded 
end function




Function encrypt(StrText, key) 
  Dim lenKey, KeyPos, LenStr, x, Newstr 
   
  Newstr = "" 
  lenKey = Len(key) 
  KeyPos = 1 
  LenStr = Len(StrText) 
  StrText = StrReverse(StrText) 
  For x = 1 To LenStr 
       Newstr = Newstr & Chr(asc(Mid(StrText,x,1)) + Asc(Mid(key,KeyPos,1))) 
       KeyPos = keypos+1 
       If KeyPos > lenKey Then KeyPos = 1 
       'if x = 4 then msgbox "error with char " & Chr(34) & asc(Mid(StrText,x,1)) - Asc(Mid(key,KeyPos,1)) & Chr(34) & " At position " & KeyPos & vbcrlf & Mid(StrText,x,1) & Mid(key,KeyPos,1) & vbcrlf & asc(Mid(StrText,x,1)) & asc(Mid(key,KeyPos,1))
  Next 
  encrypt = Newstr 
 End Function 
  
Function Decrypt(StrText,key) 
  Dim lenKey, KeyPos, LenStr, x, Newstr 
   
  Newstr = "" 
  lenKey = Len(key) 
  KeyPos = 1 
  LenStr = Len(StrText) 
   
  StrText=StrReverse(StrText) 
  For x = LenStr To 1 Step -1 
       on error resume next
       Newstr = Newstr & Chr(asc(Mid(StrText,x,1)) - Asc(Mid(key,KeyPos,1))) 
       if err.number <> 0 then
        msgbox "error with char " & Chr(34) & asc(Mid(StrText,x,1)) - Asc(Mid(key,KeyPos,1)) & Chr(34) & " At position " & KeyPos & vbcrlf & Mid(StrText,x,1) & Mid(key,KeyPos,1) & vbcrlf & asc(Mid(StrText,x,1)) & asc(Mid(key,KeyPos,1))
        wscript.quit(011)
       end if
       on error goto 0
       KeyPos = KeyPos+1 
       If KeyPos > lenKey Then KeyPos = 1 
       Next 
       Newstr=StrReverse(Newstr) 
       Decrypt = Newstr 
 End Function 
Function FormatDate(strFDate) 
Dim strTmpMonth
Dim strTmpDay
strTmpMonth = datepart("m",strFDate)
strTmpDay = datepart("d",strFDate)
if len(strTmpMonth) = 1 then strTmpMonth = "0" & strTmpMonth
if len(strTmpDay) = 1 then strTmpDay = "0" & strTmpDay

FormatDate = datepart("yyyy",strFDate) & "-" & strTmpMonth & "-" & strTmpDay


end function


Function ValueFromIni(strFpath, iniSection, iniKey, currentValue)
returniniVal = ReadIni( strFpath, iniSection, iniKey)
if returniniVal = " " then 
	returniniVal = currentValue
end if 
if TypeName(returniniVal) = "String" then
	returniniVal = stringToBool(returniniVal)'convert type to boolean if needed
elseif TypeName(returniniVal) = "Integer" then
	returniniVal = int(returniniVal)'convert type to int if needed
end if
ValueFromIni = returniniVal
end function

Function stringToBool(strBoolean)
if lcase(strBoolean) = "true" then 
	returnBoolean = True
elseif lcase(strBoolean) = "false" then 
	returnBoolean = False
else
	returnBoolean = strBoolean
end if
stringToBool = returnBoolean
end function

Function ReadIni( myFilePath, mySection, myKey ) 'http://www.robvanderwoude.com/vbstech_files_ini.php
    ' This function returns a value read from an INI file
    '
    ' Arguments:
    ' myFilePath  [string]  the (path and) file name of the INI file
    ' mySection   [string]  the section in the INI file to be searched
    ' myKey       [string]  the key whose value is to be returned
    '
    ' Returns:
    ' the [string] value for the specified key in the specified section
    '
    ' CAVEAT:     Will return a space if key exists but value is blank
    '
    ' Written by Keith Lacelle
    ' Modified by Denis St-Pierre and Rob van der Woude

    Dim intEqualPos
    Dim objFSO, objIniFile
    Dim strFilePath, strKey, strLeftString, strLine, strSection

    Set objFSO = CreateObject( "Scripting.FileSystemObject" )

    ReadIni     = ""
    strFilePath = Trim( myFilePath )
    strSection  = Trim( mySection )
    strKey      = Trim( myKey )

    If objFSO.FileExists( strFilePath ) Then
        Set objIniFile = objFSO.OpenTextFile( strFilePath, ForReading, False )
        Do While objIniFile.AtEndOfStream = False
            strLine = Trim( objIniFile.ReadLine )

            ' Check if section is found in the current line
            If LCase( strLine ) = "[" & LCase( strSection ) & "]" Then
                strLine = Trim( objIniFile.ReadLine )

                ' Parse lines until the next section is reached
                Do While Left( strLine, 1 ) <> "["
                    ' Find position of equal sign in the line
                    intEqualPos = InStr( 1, strLine, "=", 1 )
                    If intEqualPos > 0 Then
                        strLeftString = Trim( Left( strLine, intEqualPos - 1 ) )
                        ' Check if item is found in the current line
                        If LCase( strLeftString ) = LCase( strKey ) Then
                            ReadIni = Trim( Mid( strLine, intEqualPos + 1 ) )
                            ' In case the item exists but value is blank
                            If ReadIni = "" Then
                                ReadIni = " "
                            End If
                            ' Abort loop when item is found
                            Exit Do
                        End If
                    End If

                    ' Abort if the end of the INI file is reached
                    If objIniFile.AtEndOfStream Then Exit Do

                    ' Continue with next line
                    strLine = Trim( objIniFile.ReadLine )
                Loop
            Exit Do
            End If
        Loop
        objIniFile.Close
    Else
        if BoolRunSilent = False then WScript.Echo strFilePath & " does not exist. Using script configured/default settings instead"
    End If
End Function




Function SocketTools_HTTP(strRemoteURL)
' SocketTools 9.3 ActiveX Edition
' Copyright 2018 Catalyst Development Corporation
' All rights reserved
'
' This file is licensed to you pursuant to the terms of the
' product license agreement included with the original software,
' and is protected by copyright law and international treaties.
' Unauthorized reproduction or distribution may result in severe
' criminal penalties.
'

'
' Retrieve the specified page from a web server and write the
' contents to standard output. The parameter should specify the
' URL of the page to display


Const httpTransferDefault = 0
Const httpTransferConvert = 1

Dim objArgs
Dim objHttp
Dim strBuffer
Dim nLength
Dim nArg, nError


'
' Create an instance of the control
'
Set objHttp = WScript.CreateObject("SocketTools.HttpClient.9")

'
' Initialize the object using the specified runtime license key;
' if the key is not specified, the development license will be used
'

nError = objHttp.Initialize(strLicenseKey) 
If nError <> 0 Then
    WScript.Echo "Unable to initialize SocketTools component"
    WScript.Quit(1)
End If

objHttp.HeaderField = "X-Auth-Token"
objHttp.HeaderValue = strCarBlackAPIKey 
    
' Setup error handling since the component will throw an error
' if an invalid URL is specified

On Error Resume Next: Err.Clear
objHttp.URL = strRemoteURL

' Check the Err object to see if an error has occurred, and
' if so, let the user know that the URL is invalid

If Err.Number <> 0 Then
    WScript.echo "The specified URL is invalid"
    WScript.Quit(1)
End If

' Reset error handling and connect to the server using the
' default property values that were updated when the URL
' property was set (ie: HostName, RemotePort, UserName, etc.)
On Error GoTo 0
nError = objHttp.Connect()

If nError <> 0 Then
    WScript.echo "Error connecting to " & strRemoteURL & ". " & objHttp.LastError & ": " & objHttp.LastErrorString
    WScript.Quit(1)
End If
objHttp.timeout = 90
' Download the file to the local system
nError = objHttp.GetData(objHttp.Resource, strBuffer, nLength, httpTransferConvert)

If nError = 0 Then
    SocketTools_HTTP = strBuffer
Else
    WScript.echo "Error " & objHttp.LastError & ": " & objHttp.LastErrorString
	SocketTools_HTTP = objHttp.ResultString
End If

objHttp.Disconnect
objHttp.Uninitialize
end function

Function IsHash(TestString)
    Dim sTemp
    Dim iLen
    Dim iCtr
    Dim sChar

    
    sTemp = TestString
    iLen = Len(sTemp)
    If iLen > 0 Then
        For iCtr = 1 To iLen
            sChar = Mid(sTemp, iCtr, 1)
            if isnumeric(sChar) or "a"= lcase(sChar) or "b"= lcase(sChar) or "c"= lcase(sChar) or "d"= lcase(sChar) or "e"= lcase(sChar) or "f"= lcase(sChar)  then
              'allowed characters for hash (hex)
            else
              IsHash = False
              exit function
            end if
        Next
    
    IsHash = True
    else
      IsHash = False
    End If
    
End Function


Function isIPaddress(strIPaddress)
DIm arrayTmpquad
Dim boolReturn_isIP
boolReturn_isIP = True
if instr(strIPaddress,".") then
  arrayTmpquad = split(strIPaddress,".")
  for each item in arrayTmpquad
    if isnumeric(item) = false then boolReturn_isIP = false
  next
else
  boolReturn_isIP = false
end if
if boolReturn_isIP = false then
	boolReturn_isIP = isIpv6(strIPaddress)
end if
isIPaddress = boolReturn_isIP
End Function




Function IsIPv6(TestString)

    Dim sTemp
    Dim iLen
    Dim iCtr
    Dim sChar
    
    if instr(TestString, ":") = 0 then 
		IsIPv6 = false
		exit function
	end if
    
    sTemp = TestString
    iLen = Len(sTemp)
    If iLen > 0 Then
        For iCtr = 1 To iLen
            sChar = Mid(sTemp, iCtr, 1)
            if isnumeric(sChar) or "a"= lcase(sChar) or "b"= lcase(sChar) or "c"= lcase(sChar) or "d"= lcase(sChar) or "e"= lcase(sChar) or "f"= lcase(sChar) or ":" = sChar then
              'allowed characters for hash (hex)
            else
              IsIPv6 = False
              exit function
            end if
        Next
    
    IsIPv6 = True
    else
      IsIPv6 = False
    End If
    
End Function

function escapeSpecials(strSpecialQuery)
newQuery = replace(strSpecialQuery, "*", "\*")
newQuery = replace(newQuery, Chr(34), "\" & Chr(34))
newQuery = replace(newQuery, "&", "\&")
'need to perform encoding for pound sign
escapeSpecials = newQuery
end Function