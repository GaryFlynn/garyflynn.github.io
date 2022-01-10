# Clear Set-ExecutionPolicy errors
cls

# Clear Variables and Set Table Format properties
$VIString = ""
$VIServer = ""
$numDays = ""
$formatTable = @{Expression={$_.VM};Label="VM"},@{Expression={$_.Name};Label="Name"},@{Expression={$_.Description};Label="Description"},@{Expression={[int]$_.SizeMB};Label="Size MB"},@{Expression={[int]$_.SizeGB};Label="Size GB"},@{Expression={$_.Created};Label="Created Date"}

function showMenu {
     param (
           [string]$Title = 'Shapshot Management'
     )
     cls
     Write-Host "================ $Title ================" `n
     
     Write-Host "1: View All Snapshots: Press '1' for this option."
     Write-Host "2: View Snapshots older than x days: Press '2' for this option."
     Write-Host "3: View Snapshots older than x days, and optionally delete each one: Press '3' for this option."
     Write-Host "4: View VI Server: Press '4' for this option."
     Write-Host "5: Change VI Server: Press '5' for this option."
     Write-Host "Q: Press 'Q' to quit." `n
}

function loadPowerCLIModule {
# +------------------------------------------------------+
# |        Load VMware modules if not loaded             |
# +------------------------------------------------------+

if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
    if (Test-Path -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI' ) {
        $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI'
       
    } else {
        $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware vSphere PowerCLI'
    }
    . (join-path -path (Get-ItemProperty  $Regkey).InstallPath -childpath 'Scripts\Initialize-PowerCLIEnvironment.ps1')
}
if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
    Write-Host "VMware modules not loaded/unable to load"
    Exit 99
}
cls
}

function getSnapshotsOfAge($numDays) {
    $allSnapshots = getAllSnapshots
    $allSnapshots | Where { $_.Created -lt (Get-Date).AddDays(-$numDays) }
}

function formatGetSnapshotsOfAge($numDays) {
    $allSnapshots = getSnapshotsOfAge($numDays)
    if ($allSnapshots.Count -eq 0) {
        if ($numDays -lt 2) {
            Write-Host "No VMs found with snapshots older than $numDays day."
        }
        else {
            Write-Host "No VMs found with snapshots older than $numDays days."
        }
    }
    else {
        $allSnapshots | Format-Table $formatTable -AutoSize
    }
}

function getAllSnapshots {
    Write-Host "Loading... This may take a minute or two depending on the size of your environment."
    Get-VM | Get-Snapshot
    cls
}

function formatGetAllSnapshots {
    $allSnapshots = getAllSnapshots
    if ($allSnapshots.Count -eq 0) {
        Write-Host "No VMs found with snapshots."
    }
    else {
        $allSnapshots | Format-Table $formatTable -AutoSize
    }
}

function doDelete($allSnapshots) {
    if ($allSnapshots.Count -eq 0) {
        if ($numDays -eq 1) {
            Write-Host "No VMs found with snapshots older than $numDays day."
        }
        else {
            Write-Host "No VMs found with snapshots older than $numDays days."
        }
    }
    else {
        foreach ($snapshot in $snapshots) {
            cls
            Get-Snapshot -VM $snapshot.VM -Id $snapshot.Id | Format-Table $formatTable -AutoSize
            $doDelete = Read-Host -Prompt 'Enter "Yes" if you want to delete this snapshot (Default is "No")?'
            if ($doDelete -eq "Yes") {
                Get-Snapshot -VM $snapshot.VM -Id $snapshot.Id | Remove-Snapshot -RunAsync -Confirm:$false
                cls
            }
            elseif ($doDelete -eq "q") {
                break
            }
            cls
        }
    }
}

function connectVIServer() {
    $VIString = Read-Host -Prompt "Enter FQDN of target VI Server"
    Connect-VIServer -Server $VIString
    cls
}

function disconnectVIServer($VIString) {
    Disconnect-VIServer -Server $VIString -Confirm:$false
}

function printVIServer {
    Write-Host "Current target VI Server: $VIString"
}

loadPowerCLIModule
$VIServer = connectVIServer
$VIString = $VIServer[0]
$VIString = $VIString.ToString()
cls

do
{
     showMenu
     $input = Read-Host "Please make a selection" $VIString
     switch ($input)
     {
           '1' {
                cls
                formatGetAllSnapshots
           } '2' {
                cls
                $numDays = Read-Host -Prompt "Return snapshots older than how many days?"
                formatGetSnapshotsOfAge($numDays)
           } '3' {
                cls
                $numDays = Read-Host -Prompt "Return snapshots older than how many days?"
                $snapshots = getSnapshotsOfAge($numDays)
                doDelete($snapshots)
           } '4' {
                cls
                printVIServer
           } '5' {
                cls
                printVIServer
                disconnectVIServer($VIString)
                connectVIServer
                printVIServer
           } 'q' {
                cls
                disconnectVIServer($VIString)
                Write-Host "Your connections have been disconnected."
           }
     }
     pause
}
until ($input -eq 'q')