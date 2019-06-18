$queryableDataObjects = @(
    "Get-BrokerAccessPolicyRule",
    "Get-BrokerAdminFolder",
    "Get-BrokerAppAssignmentPolicyRule",
    "Get-BrokerAppEntitlementPolicyRule",
    "Get-BrokerApplication",
    "Get-BrokerApplicationGroup",
    "Get-BrokerApplicationInstance",
    "Get-BrokerAssignmentPolicyRule",
    "Get-BrokerCatalog",
    "Get-BrokerConfigurationSlot",
    "Get-BrokerConfiguredFTA",
    "Get-BrokerConnectionLog",
    "Get-BrokerController",
    "Get-BrokerDBConnection",
    "Get-BrokerDBSchema",
    "Get-BrokerDBVersionChangeScript",
    "Get-BrokerDelayedHostingPowerAction",
    "Get-BrokerDesktop",
    "Get-BrokerDesktopGroup",
    "Get-BrokerDesktopGroupAnalysisReport",
    "Get-BrokerDesktopGroupAppDisk",
    "Get-BrokerDesktopGroupWebhook",
    "Get-BrokerDesktopUsage",
    "Get-BrokerEntitlementPolicyRule",
    "Get-BrokerHostingPowerAction",
    "Get-BrokerHypervisorAlert",
    "Get-BrokerHypervisorConnection",
    "Get-BrokerIcon",
    "Get-BrokerImportedFTA",
    "Get-BrokerInstalledDbVersion",
    "Get-BrokerLease",
    "Get-BrokerMachine",
    "Get-BrokerMachineCommand",
    "Get-BrokerMachineConfiguration",
    "Get-BrokerMachineStartMenuShortcutIcon",
    "Get-BrokerMachineStartMenuShortcuts",
    "Get-BrokerPowerTimeScheme",
    "Get-BrokerPrivateDesktop",
    "Get-BrokerRebootCycle",
    "Get-BrokerRebootSchedule",
    "Get-BrokerRebootScheduleV2",
    "Get-BrokerRemotePCAccount",
    "Get-BrokerResource",
    "Get-BrokerScopedObject",
    "Get-BrokerServiceAddedCapability",
    "Get-BrokerServiceInstance",
    "Get-BrokerServiceStatus",
    "Get-BrokerSession",
    "Get-BrokerSessionLinger",
    "Get-BrokerSessionPreLaunch",
    "Get-BrokerSharedDesktop",
    "Get-BrokerSite",
    "Get-BrokerTag",
    "Get-BrokerTagUsage",
    "Get-BrokerUnconfiguredMachine",
    "Get-BrokerUser",
    "Get-BrokerUserZonePreference")

function Get-CitrixQueryResults
{
    Param
    (     
        [string]$entity   
    )

    #Get CPU usage from system
    if ($entity -eq  "cpu") {
        $CpuLoad = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average ).Average
        return $CpuLoad
    }
    #Get ram usage from system
    elseif ($entity -match "ram") {
        $os = Get-Ciminstance Win32_OperatingSystem
        $AvaregeRam = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
        $AvaregeRam = 100 - $AvaregeRam
        return $AvaregeRam
    }
    #Get disk usage
    elseif ($entity -match "diskusage") {
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
        #trovo lo spazio utilizzato
        $diskUse = $disk.Size/1MB - $disk.FreeSpace/1MB
        return $diskUse
    }
    #Get disk io
    elseif ($entity -match "diskio") {
        #numero di operazioni per secondo
        return (Get-WmiObject Win32_PerfFormattedData_PerfProc_Process)[0].IODataOperationsPersec
    } else {
        #Aggiunge i comandi di citrix
        Add-PSSnapin Citrix*
        $res = ($queryableDataObjects -match "$entity")[0]
        if ($res -eq $null -or $res -eq "") {
            return $null
        }
        $result2 = Invoke-Expression $res
    }
    return $result2
}

# Create a listener on port 8000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8000/')
$listener.Start()
'Listening ...'
# Run until you send a GET request to /end
while ($true) {
    $context = $listener.GetContext()

    # Capture the details about the request
    $request = $context.Request

    # Setup a place to deliver a response
    $response = $context.Response

    # Break from loop if GET request sent to /end
    if ($request.Url -match '/end$') {
        break
    } else {
        # Split request URL to get command and options
        $requestvars = ([String]$request.Url).split("/");

        if (
            $requestvars[3] -ne $null -and
            $requestvars[3] -ne "") {
            # Esegui la funzione Get-HViewQueryResults con argomento in ingresso
            $result = Get-CitrixQueryResults -entity $requestvars[3]
        }
        # Convert the returned data to JSON and set the HTTP content type to JSON
        $message = ConvertTo-Json -Depth 1 -InputObject $result;
        $response.ContentType = 'application/json';

        # Return empty message if message is null
        if ($message -eq $null) { $message = "" }

        # Convert the data to UTF8 bytes
        [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
       
        # Set length of response
        $response.ContentLength64 = $buffer.length

        # Write response out and close
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.length)
        $output.Close()
    }
}

#Terminate the listener
$listener.Stop()
