# Notifications require BurntToast. Install with:
# PS> Install-Module -Name BurntToast -Scope CurrentUser

try {
  Import-Module BurntToast
  $canToast = $true
}
catch {
  Write-Output 'BurntToast not available. Toast notifications are disabled.'
  $canToast = $false
}

$EveLogsDir = [Environment]::GetFolderPath('MyDocuments') + '\EVE\logs\Chatlogs'

$logFile = Get-ChildItem -Path $EveLogsDir -Filter 'Local_*.txt' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

Write-Output "Monitoring $logFile"

$global:dbts = Get-Date
$global:whs = @{}

function Update-WormholeDb {
  $global:whs.Clear()
  $data = Invoke-WebRequest 'http://anoik.is/api/claimables/available' -UseBasicParsing | ConvertFrom-Json
  foreach ($system in $data.claimables) {
    $global:whs[$system.system_name] = 'SKIN'
  }
  Write-Output "$($global:whs.Count) lucky systems: $($global:whs.Keys)"
  $global:dbts = Get-Date
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

Update-WormholeDb

Get-Content -Path $logFile.FullName -Tail 0 -Wait |
  where { $_ -Match 'changed to Local : ' } |
  foreach {
    if (((Get-Date) - $dbts).TotalSeconds -gt 600) { Update-WormholeDb }
    foreach ($jnum in $whs.Keys) {
      if ($_ -Match "Local : $jnum") {
        if ($canToast) {
          New-BurntToastNotification -Sound 'Alarm' -Text "$jnum is a lucky system", "Quick, claim the $($whs[$jnum])!"
        }
        Play-ObnoxiousMelody
        Start-Process "http://anoik.is/systems/$jnum"
        break
      }
    }
  }
