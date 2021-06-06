# Anoik.is SKIN hunt notifier

## A convenience tool for Anoik.is SKIN treasure hunters

This is a simple tool that reads the EVE chat log and let's you know
if you have entered one of the systems loaded with a partner SKIN. It
plays a desktop notification and opens up the system page in the
browser which allows you to claim the SKIN a.s.a.p.

The tool is avaiable as a shell script for Linux and a PowerShell
script for Windows.

## Usage

Just start the script. It picks up the chat log of the last started
EVE client. On Linux you may need to adjust the path to the chat log.

### Windows

PowerShell does not allow execution of unsigned scripts by default.
You may either change the policy (not recommended) or use the following
command to start the script:

```
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\to\anoikis_skin_notifier.ps1"
```

The script requires BurntToast to show desktop notifications. Install it
with the following command:

```
Install-Module -Name BurntToast -Scope CurrentUser
```
