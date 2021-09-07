# Anoik.is SKIN notifier

## A convenience tool for Anoik.is SKIN treasure hunters

This is a simple tool that reads the EVE chat log and lets you know
if you have entered one of the systems loaded with a partner SKIN. It
plays a desktop notification and opens up the system page in the
browser which allows you to claim the SKIN a.s.a.p.

The tool is avaiable as a shell script for Linux and a PowerShell
script for Windows.

**EVE client languages other than English are not supported.**

## Usage

### Linux

Just start the script **after you've started the EVE client and selected
your character**. It picks up the chat log of the last started EVE client.
You may need to adjust the path to the chat log.

### Windows

Start the script and select the correct character. By default, the logs from
the past 7 days are examined for character names. You can change the number
of days with `-HistoryDays #days`, e.g.:

```ps1
-HistoryDays 14
```

The script monitors for newer log files for the selected character and
switches automatically.

PowerShell does not allow execution of unsigned scripts by default. You may
either change the policy (not recommended) or temporarily bypass it by using
the following command to start the script:

```cmd
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\to\anoikis_skin_notifier.ps1"
```

The script requires BurntToast to show desktop notifications. Install it
with the following PowerShell command:

```ps1
Install-Module -Name BurntToast -Scope CurrentUser
```

### Test Mode (Windows only)

To make sure that everything works as expected and that notifications are
audible, you may enable test mode with `-TestMode`. This turns on verbose
output and will notify and sound the alarm on every jump no matter if is into
a lucky system or not.

```cmd
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\to\anoikis_skin_notifier.ps1" -TestMode
```

## Acknowledgements

I would like to thank CCP for making such a wealth of in-game information
easily accessible to external tools. I would also like to thank my school
teachers for letting my laziness flourish–I would've never written those
scripts if Alt-Tab-ing all the time wasn't that much work.
