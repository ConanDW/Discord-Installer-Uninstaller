
<#
    .SYNOPSIS
        
    .DESCRIPTION
        
    .NOTES
       
#>
#region - DECLORATIONS
$script:diag                = $null
$script:blnWARN             = $false
$script:blnBREAK            = $false
$script:mode                = $env:mode
$pkg                        = "C:\IT\DiscordSetup.exe"
$discordDownloadLink        = "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x86"
$discordPath                = "C:\Users\$($Env:UserName)\AppData\Local\Discord"
#endregion - DECLORATIONS

#region - FUNCTIONS
function write-DRMMDiag ($messages) {
  write-output "<-Start Diagnostic->"
  foreach ($message in $messages) { $message }
  write-output "<-End Diagnostic->"
} ## write-DRMMDiag

function write-DRMMAlert ($message) {
  write-output "<-Start Result->"
  write-output "Alert=$($message)"
  write-output "<-End Result->"
} ## write-DRMMAlert

function StopClock {
  #Stop script execution time calculation
  $script:sw.Stop()
  $Days = $sw.Elapsed.Days
  $Hours = $sw.Elapsed.Hours
  $Minutes = $sw.Elapsed.Minutes
  $Seconds = $sw.Elapsed.Seconds
  $Milliseconds = $sw.Elapsed.Milliseconds
  $script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
}

function logERR ($intSTG, $strModule, $strErr) {
  $script:blnWARN = $true
  #CUSTOM ERROR CODES
  switch ($intSTG) {
    1 {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - NO ARGUMENTS PASSED, END SCRIPT`r`n"
    }
    2 {
      #'ERRRET'=2 - END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - ($($strModule)) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - ($($strModule)) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
    }
    3 {
      #'ERRRET'=3
      $script:blnWARN = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
    default {
      #'ERRRET'=4+
      $script:blnBREAK = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Discord_Installer - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
  }
}

function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
  if (-not (test-path -path "C:\temp")) { new-item -path "C:\temp" -itemtype directory -force }
  if (-not (test-path -path "C:\IT")) { new-item -path "C:\IT" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Log")) { new-item -path "C:\IT\Log" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Scripts")) { new-item -path "C:\IT\Scripts" -itemtype directory -force }
  if (test-path -path "$($discordPath)") {logERR 2 "dir-Check" "Discord is already installed!`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"}
}
function run-Deploy {
  try {
    logERR 4 "run-Deploy" "Attempting to download via Invoke-WebRequest"
    Invoke-WebRequest -uri "$($discordDownloadLink)" -OutFile "$($pkg)"
  } catch {
    try {
      logERR 3 "run-Deploy" "Error with Invoke-WebRequest : `r`nAttempting BITS transfer" "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      Start-BitsTransfer -Source "$($discordDownloadLink)" -Destination "$($pkg)"
    } catch { logERR 2 "Could not download Discord : `r`nScript will end" "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"; $script:blnWARN = $true}
  }
  cd "C:\IT\"
  try { .\DiscordSetup.exe -s } catch { logERR 2 "run-Deploy" "Could not install Discord : `r`nScript will end `r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"; $script:blnWARN = $true}
}
function run-Remove {
  try {
    cd "$($discordPath)" 
    .\Update.exe --uninstall -s
    try {
      rm "C:\Users\$($Env:UserName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc" -Recurse
      rm "C:\Users\$($Env:UserName)\Desktop\Discord.lnk" -Recurse
    } catch { logERR 3 "run-Remove" "Could not remove Discord shortcuts :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)" }
  } catch { logERR 2 "run-Remove" "Could not uninstall Discord : `r`nScript will end `r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"; $script:blnWARN = $true }
}
#endregion - FUNCTIONS
#region - Script 
$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
dir-Check
if ($script:mode -eq "Install") { run-Deploy } elseif ($script:mode -eq "Uninstall") { run-Remove }
$script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not ($script:blnWARN) -and $script:mode -eq "Install") { 
  write-DRMMAlert "Discord was installed successfully :`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 0 
} elseif (-not ($script:blnWARN) -and $script:mode -eq "Uninstall") {
  write-DRMMAlert "Discord was uninstalled successfully :`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnWARN -and $script:mode -eq "Uninstall") {
  write-DRMMAlert "Discord was not uninstalled successfully : This may require manual removal`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif ($script:blnWARN -and $script:mode -eq "Install") { 
  write-DRMMAlert "Discord was not installed successfully : This may require manual install`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)" 
  exit 1 
}

#endregion - Script
