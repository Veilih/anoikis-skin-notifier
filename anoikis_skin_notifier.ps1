# Notifications require BurntToast. Install with:
# PS> Install-Module -Name BurntToast -Scope CurrentUser

param(
  [int]$HistoryDays = 7,
  [switch]$AlwaysOpen = $false,
  [switch]$TestMode = $false
)

if ($TestMode) {
  $VerbosePreference = 'Continue'
  $AlwaysOpen = $true
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

  function Get-VersionFromController {
    $req = Invoke-WebRequest 'http://anoik.is/static/controller.js' -UseBasicParsing
    $m = $req.Content.Split([Environment]::NewLine) | Select-String -Pattern 'var static_expected_version = (\d+);'
    [int]$m.Matches.Groups[1].Value
  }

  function Get-StaticData {
    $staticFile = "static-data.json"
    $expectedVersion = Get-VersionFromController
    Write-Verbose "Expected static version: $expectedVersion"

    try {
      $data = Get-Content $staticFile | ConvertFrom-Json
      Write-Verbose "Cached static version: $($data.version)"
      if ($data.version -eq $expectedVersion) {
        return $data
      }
    } catch [System.IO.FileNotFoundException] {
    }

    $data = Invoke-WebRequest "http://anoik.is/static/static.json?version=$expectedVersion" -UseBasicParsing
    Set-Content $staticFile -Value $data
    $data | ConvertFrom-Json
  }

  function Update-WormholeDb {
    param([Parameter(Mandatory)]$StaticData)

    $allClasses = 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c13'

    $whs = @{}
    $classes = @{}
    foreach ($class in $allClasses) {
      $classes[$class] = @()
    }

    $data = Invoke-WebRequest 'http://anoik.is/api/claimables/available' -UseBasicParsing | ConvertFrom-Json
    foreach ($system in $data.claimables) {
      $whs[$system.system_name] = $data.claimable_types.($system.type_id).name
      $class = $StaticData.systems.($system.system_name).wormholeClass
      $classes[$class] += $system.system_name
    }

    Write-Host "$($whs.Count) lucky systems"
    foreach ($class in $allClasses) {
      if ($classes[$class].Count -gt 0) {
        Write-Host "${class}: $($classes[$class])"
      }
    }

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
    $alwaysOpen = $argList[1]
    $testMode = $argList[2]

    if ($testMode) {
      $VerbosePreference = 'Continue'
    }

    Write-Host "Monitoring $fileName"
    if ($alwaysOpen) {
      Write-Verbose "Always opening system's page"
    }

    $staticData = Get-StaticData

    $whs = Update-WormholeDb -StaticData $staticData
    $dbts = Get-Date

    Get-Content -Path $fileName -Tail 0 -Wait |
      where { $_ -match 'changed to Local : ' } |
      foreach {
        $jnum = ($_ -split ":")[-1].Trim()
        Write-Verbose "You are now in $jnum"
        if (((Get-Date) - $dbts).TotalSeconds -gt 600) {
          Write-Verbose "Updating lucky systems"
          $whs = Update-WormholeDb -StaticData $staticData
          $dbts = Get-Date
        }
        $isLucky = $whs.ContainsKey($jnum)
        if ($isLucky -or $testMode) {
          $what = $whs[$jnum]
          if ($canToast) {
            New-BurntToastNotification -Sound 'Alarm' -Text "You got lucky!", "Quick, claim the $($whs[$jnum]) in $jnum!"
          }
          Write-Host "You found a $what in $jnum!"
          Play-ObnoxiousMelody
        }
        if (($isLucky -or $alwaysOpen) -and $jnum -match '^J\d{4,}') {
          Start-Process "http://anoik.is/systems/$jnum"
        }
      }
  }
}

$character = Select-EveCharacter -DaysBack $HistoryDays

$logFile = Get-LastEveLogFile -CharacterID $character

do {
  $job = Start-Job -InitializationScript $functions -ScriptBlock {Monitor-EveLogFile} -InputObject $logFile, $AlwaysOpen, $TestMode

  do {
    Start-Sleep -Seconds 1
    Receive-Job $job
    $newLogFile = Get-LastEveLogFile -CharacterID $character
  } while ($newLogFile.Name -eq $logFile.Name)

  Stop-Job $job
  Remove-Job $job

  $logFile = $newLogFile
} while ($true)
