# Notifications require BurntToast. Install with:
# PS> Install-Module -Name BurntToast -Scope CurrentUser

param(
  [switch]$TestMode = $false,
  [int]$HistoryDays = 7
)

if ($TestMode) {
  $VerbosePreference = 'Continue'
}

$EveLogsDir = [Environment]::GetFolderPath('MyDocuments') + '\EVE\logs\Chatlogs'

function Select-EveCharacter {
  param([Parameter(Mandatory)][int]$DaysBack)

  $logFiles = Get-ChildItem -Path $EveLogsDir -Filter 'Local_*.txt' -File |
    Sort-Object LastWriteTime -Descending |
    where { ($_.LastWriteTime -ge (Get-Date).AddDays(-$DaysBack)) }

  $characters = @{}

  foreach ($file in $logFiles) {
    Write-Verbose "Processing log file $file"
    $charID = ($file.Name -split "_|\.")[3]
    Get-Content -Path $file.FullName -TotalCount 11 |
      where { $_ -Match '(?<=Listener: ).*' } | ForEach-Object {
        $characterName = ($_ -split ":")[1].Trim()
        Write-Verbose "Found character $charID $characterName"
        $characters[$charID] = $characterName
      }
  }

  $keys = $characters.Keys
  do {
    $i = 1
    foreach ($key in $keys) {
      Write-Host "[$i] $($characters[$key])"
      $i++
    }
    [int]$idx = Read-Host "Select character"
  } while ($idx -lt 1 -or $idx -gt $keys.Count)
  $idx--
  $keys | Select-Object -Index $idx
}

function Get-LastEveLogFile {
  param([Parameter(Mandatory)][string]$CharacterID)

  Get-ChildItem -Path $EveLogsDir -Filter "Local_*_$CharacterID.txt" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

$functions = {
  try {
    Import-Module BurntToast
    $canToast = $true
  }
  catch {
    Write-Host 'BurntToast not available. Toast notifications are disabled.'
    $canToast = $false
  }

  function Update-WormholeDb {
    $whs = @{}
    $data = Invoke-WebRequest 'http://anoik.is/api/claimables/available' -UseBasicParsing | ConvertFrom-Json
    foreach ($system in $data.claimables) {
      $whs[$system.system_name] = 'SKIN'
    }
    Write-Host "$($whs.Count) lucky systems: $($whs.Keys)"
    $whs
  }

  function Play-ObnoxiousMelody {
    try {
      $player = New-Object System.Media.SoundPlayer
      $player.SoundLocation = [Environment]::GetFolderPath("Windows") + '\Media\Alarm01.wav'
      $player.playsync()
    }
    catch {
      [console]::beep(440,500)      
      [console]::beep(440,500)
      [console]::beep(440,500)       
      [console]::beep(349,350)       
      [console]::beep(523,150)       
      [console]::beep(440,500)       
      [console]::beep(349,350)       
      [console]::beep(523,150)       
      [console]::beep(440,800)
    }
  }

  function Monitor-EveLogFile {
    $argList = $input.Clone()

    $fileName = $argList[0].FullName
    $testMode = $argList[1]

    if ($testMode) {
      $VerbosePreference = 'Continue'
    }

    Write-Host "Monitoring $fileName"

    $whs = Update-WormholeDb
    $dbts = Get-Date

    Get-Content -Path $fileName -Tail 0 -Wait |
      where { $_ -Match 'changed to Local : ' } |
      foreach {
        $jnum = ($_ -split ":")[-1].Trim()
        Write-Verbose "You are now in $jnum"
        if (((Get-Date) - $dbts).TotalSeconds -gt 600) {
          Write-Verbose "Updating lucky systems"
          $whs = Update-WormholeDb
          $dbts = Get-Date
        }
        $isLucky = $whs.ContainsKey($jnum)
        if ($isLucky -or $testMode) {
          $msg = "You are lucky!"
          if ($canToast) {
            New-BurntToastNotification -Sound 'Alarm' -Text $msg, "Quick, claim the $($whs[$jnum]) in $jnum!"
          }
          Write-Host $msg
          Play-ObnoxiousMelody
          if ($isLucky) {
            Start-Process "http://anoik.is/systems/$jnum"
          }
        }
      }
  }
}

$character = Select-EveCharacter -DaysBack $HistoryDays

$logFile = Get-LastEveLogFile -CharacterID $character

do {
  $job = Start-Job -InitializationScript $functions -ScriptBlock {Monitor-EveLogFile} -InputObject $logFile, $TestMode

  do {
    Start-Sleep -Seconds 1
    Receive-Job $job
    $newLogFile = Get-LastEveLogFile -CharacterID $character
  } while ($newLogFile.Name -eq $logFile.Name)

  Stop-Job $job
  Remove-Job $job

  $logFile = $newLogFile
} while ($true)