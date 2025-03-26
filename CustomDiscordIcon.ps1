If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


function Show-ModernFilePicker {
    param(
        [ValidateSet('Folder', 'File')]
        $Mode,
        [string]$fileType

    )

    if ($Mode -eq 'Folder') {
        $Title = 'Select Folder'
        $modeOption = $false
        $Filter = "Folders|`n"
    }
    else {
        $Title = 'Select File'
        $modeOption = $true
        if ($fileType) {
            $Filter = "$fileType Files (*.$fileType) | *.$fileType|All files (*.*)|*.*"
        }
        else {
            $Filter = 'All Files (*.*)|*.*'
        }
    }
    #modern file dialog
    #modified code from: https://gist.github.com/IMJLA/1d570aa2bb5c30215c222e7a5e5078fd
    $AssemblyFullName = 'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
    $Assembly = [System.Reflection.Assembly]::Load($AssemblyFullName)
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.AddExtension = $modeOption
    $OpenFileDialog.CheckFileExists = $modeOption
    $OpenFileDialog.DereferenceLinks = $true
    $OpenFileDialog.Filter = $Filter
    $OpenFileDialog.Multiselect = $false
    $OpenFileDialog.Title = $Title
    $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    $OpenFileDialogType = $OpenFileDialog.GetType()
    $FileDialogInterfaceType = $Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
    $IFileDialog = $OpenFileDialogType.GetMethod('CreateVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null)
    $null = $OpenFileDialogType.GetMethod('OnBeforeVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $IFileDialog)
    if ($Mode -eq 'Folder') {
        [uint32]$PickFoldersOption = $Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue($null)
        $FolderOptions = $OpenFileDialogType.GetMethod('get_Options', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null) -bor $PickFoldersOption
        $null = $FileDialogInterfaceType.GetMethod('SetOptions', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $FolderOptions)
    }
  
  

    $VistaDialogEvent = [System.Activator]::CreateInstance($AssemblyFullName, 'System.Windows.Forms.FileDialog+VistaDialogEvents', $false, 0, $null, $OpenFileDialog, $null, $null).Unwrap()
    [uint32]$AdviceCookie = 0
    $AdvisoryParameters = @($VistaDialogEvent, $AdviceCookie)
    $AdviseResult = $FileDialogInterfaceType.GetMethod('Advise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdvisoryParameters)
    $AdviceCookie = $AdvisoryParameters[1]
    $Result = $FileDialogInterfaceType.GetMethod('Show', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, [System.IntPtr]::Zero)
    $null = $FileDialogInterfaceType.GetMethod('Unadvise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdviceCookie)
    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        $FileDialogInterfaceType.GetMethod('GetResult', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $null)
    }

    return $OpenFileDialog.FileName
}


#simple cli menu
function Menu {
    Write-Host 'Custom Discord Icon:' -ForegroundColor Cyan
    Write-Host 'Black Icon [1]' -ForegroundColor Cyan
    Write-Host 'Custom Icon [2]' -ForegroundColor Cyan
    Write-Host 'Reset Icon [3]' -ForegroundColor Cyan
    Write-Host 
    $option = Read-Host 'Enter Option 1,2,3' 
    return $option
}

$exit = $false
#download resource hacker 
Write-Host 'Downloading Resource Hacker...'
$ProgressPreference = 'SilentlyContinue'
$uri = 'https://www.angusj.com/resourcehacker/resource_hacker.zip'
Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile "$env:TEMP\resourceHacker.zip"
New-Item "$env:TEMP\ResourceHacker" -ItemType Directory -Force | Out-Null
Expand-Archive "$env:TEMP\resourceHacker.zip" -DestinationPath "$env:TEMP\ResourceHacker" -Force
$rHackerPath = "$env:TEMP\ResourceHacker\ResourceHacker.exe"

do {
    #display menu
    $choice = Menu
    switch ($choice) {
        '1' { 
            #black icon
            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/zoicware/CustomDiscordIcon/refs/heads/main/discordBlack.ico' -OutFile "$env:TEMP\discordBlack.ico" -UseBasicParsing
            
            #find discord.exe
            $discordPath = (Get-Process Discord -ErrorAction SilentlyContinue | Select-Object Path -First 1).Path
            if (!$discordPath) {
                #find manually
                $discordPath = (Get-item "$env:LOCALAPPDATA\Discord\app-*\Discord.exe").FullName
            }

            Stop-Process -Name 'Discord' -Force -ErrorAction SilentlyContinue
            #replace icon with resource hacker
            Write-Host 'Setting Discord Icon to Black...' -ForegroundColor Cyan
            Start-Process $rHackerPath -ArgumentList "-open `"$discordPath`" -save `"$discordPath`" -action addoverwrite -res `"$env:TEMP\discordBlack.ico`" -mask ICONGROUP,1,1033" 
            Start-Sleep 3
            Stop-Process -Name ResourceHacker -Force -ErrorAction SilentlyContinue

            #clear icon cache
            $cacheDir = "$env:LocalAppData\Microsoft\Windows\Explorer"
            Get-ChildItem -Path $cacheDir -Filter 'iconcache_*.db' | Remove-Item -Force -ErrorAction SilentlyContinue
            #cleanup
            Remove-Item "$env:TEMP\ResourceHacker" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\resourceHacker.zip" -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\discordBlack.ico" -Force -ErrorAction SilentlyContinue

            $exit = $true
            break
        }
        '2' {
            #custom icon
            Write-Host 'Select Custom Icon File...' -ForegroundColor Cyan
            $iconPath = Show-ModernFilePicker -Mode File -fileType 'ico'
            #find discord.exe
            $discordPath = (Get-Process Discord -ErrorAction SilentlyContinue | Select-Object Path -First 1).Path
            if (!$discordPath) {
                #find manually
                $discordPath = (Get-item "$env:LOCALAPPDATA\Discord\app-*\Discord.exe").FullName
            }

            Stop-Process -Name 'Discord' -Force -ErrorAction SilentlyContinue
            #replace icon with resource hacker
            Write-Host 'Setting Custom Discord Icon...' -ForegroundColor Cyan
            Start-Process $rHackerPath -ArgumentList "-open `"$discordPath`" -save `"$discordPath`" -action addoverwrite -res `"$iconPath`" -mask ICONGROUP,1,1033" 
            Start-Sleep 3
            Stop-Process -Name ResourceHacker -Force -ErrorAction SilentlyContinue

            #clear icon cache
            $cacheDir = "$env:LocalAppData\Microsoft\Windows\Explorer"
            Get-ChildItem -Path $cacheDir -Filter 'iconcache_*.db' | Remove-Item -Force -ErrorAction SilentlyContinue
            #cleanup
            Remove-Item "$env:TEMP\ResourceHacker" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\resourceHacker.zip" -Force -ErrorAction SilentlyContinue
           
            $exit = $true
            break
        }
        '3' {
            #reset icon

            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/zoicware/CustomDiscordIcon/refs/heads/main/discordDefault.ico' -OutFile "$env:TEMP\discordDefault.ico" -UseBasicParsing
            
            #find discord.exe
            $discordPath = (Get-Process Discord -ErrorAction SilentlyContinue | Select-Object Path -First 1).Path
            if (!$discordPath) {
                #find manually
                $discordPath = (Get-item "$env:LOCALAPPDATA\Discord\app-*\Discord.exe").FullName
            }

            Stop-Process -Name 'Discord' -Force -ErrorAction SilentlyContinue
            #replace icon with resource hacker
            Write-Host 'Resetting Discord Icon to Default...' -ForegroundColor Cyan
            Start-Process $rHackerPath -ArgumentList "-open `"$discordPath`" -save `"$discordPath`" -action addoverwrite -res `"$env:TEMP\discordDefault.ico`" -mask ICONGROUP,1,1033" 
            Start-Sleep 3
            Stop-Process -Name ResourceHacker -Force -ErrorAction SilentlyContinue

            #clear icon cache
            $cacheDir = "$env:LocalAppData\Microsoft\Windows\Explorer"
            Get-ChildItem -Path $cacheDir -Filter 'iconcache_*.db' | Remove-Item -Force -ErrorAction SilentlyContinue
            #cleanup
            Remove-Item "$env:TEMP\ResourceHacker" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\resourceHacker.zip" -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:TEMP\discordDefault.ico" -Force -ErrorAction SilentlyContinue

            $exit = $true
            break
        }
        Default {
            Write-Host 'Option Not Valid!' -ForegroundColor Red
            break
        }
    }
}while ($exit -eq $false)



