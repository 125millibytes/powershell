# Custom prompt function for PowerShell 7 and PowerShell 5
# Save as $PROFILE.CurrentUserAllHosts
# To link PS5's profile to PS7's file, run this in PS5: 
#   mkdir ($PROFILE.CurrentUserAllHosts | Split-Path -Parent) -ea SilentlyContinue
#   ni -Type HardLink -Path ($PROFILE.CurrentUserAllHosts) -Target (pwsh -c `$PROFILE.CurrentUserAllHosts)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Store the original prompt function to allow reverting in case of errors
$script:myOriginalPrompt = (Get-Command prompt -CommandType Function -ErrorAction SilentlyContinue).ScriptBlock

# Check if the current user has admin permissions
$user = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()))
$isAdmin = $user.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# initialize history ID to non-null value to show path on first prompt
$script:lastHistoryId = -1

$esc = [char]27
$resetFormat = "$esc[0m"

# Colors
# ANSI color codes: Black=30, Red=31, Green=32, Yellow=33, Blue=34, Magenta=35, Cyan=36, White=37, Default=39
# TODO: Workaround for dim mode (`e[2m) having the reverse effect in light theme, because it makes the text darker regardless of background color.

# PSReadLine syntax highlighting colors
Set-PSReadLineOption -Colors @{
    Default = "$esc[37m";
    Keyword = "$esc[95m";
    Operator="$esc[96m";
    Member = "$esc[33m";
    Variable="$esc[36m";
    Type = "$esc[34m";
    Number = "$esc[92m";
    String = "$esc[34m";
    Command = "$esc[93m";
    Parameter="$esc[36m";
    
    Error = "$esc[91m";
    Selection = "$esc[30;47m";
    Emphasis = "$esc[96m";
    InlinePrediction = "$esc[90;3m";
    ListPrediction = "$esc[30m";
    ListPredictionSelected = "$esc[37;100m";`

    #ContinuationPrompt ?
    #ListPredictionTooltip ?
}


# Prompt format ANSI escape codes (Normal, Error, Path, Debug, Continuation, Indicator)
$pfNor = if($isAdmin) {"$esc[1;33m"} else {"$esc[1;34m"}
$pfErr = "$esc[1;31m"
$pfCon = $pfNor # "$esc[90m"
$pfPwd = "$esc[30;3m"
$pfDeb = "$esc[35m"
$pfInd = "$esc[1;39m"
$pfIndErr = "$esc[1;31m"
$pfIndCon = "$esc[1;39m"

# Custom prompt function
function prompt {
    try{
        # check history to see if previous prompt was cancelled
        $lastCommand = Get-History -Count 1
        if($lastCommand) {
            $newHistoryId = $lastCommand.Id
        } else {
            $newHistoryId = $null
        }
        $previousPromptCancelled = $script:lastHistoryId -eq $newHistoryId
        $script:lastHistoryId = $newHistoryId

        if(-not $previousPromptCancelled){
            # write blank line and currect directory on a separate line
            Write-Host
            Write-Host "$pfPwd$pwd$resetFormat"
        }

        # use hex codes for special character because PowerShell 5 doesn't use Unicode by default
        # 0x003E >, 0x226B ≫, 0x203A ›, 0x00BB », 0x00B7 ·, 0x2014 —

        $promptIndicator = "{0} " -f $(if($NestedPromptLevel -lt 1) {[string][char]0x203A} else {[string][char]0x00BB})

        # create the main prompt

        if(Get-Variable PSDebugContext -ea SilentlyContinue) {
            # debug mode indicator
            $promptDebugTag = "DBG:"
        }else {
            $promptDebugTag = ""
        }
        # PowerShell (PS) prompt with version number
        $promptText = "PS{0}" -f $PSVersionTable.PSVersion.Major
        
        $promptNormal = "$pfDeb$promptDebugTag$resetFormat$pfNor$promptText$resetFormat$pfInd$promptIndicator$resetFormat"
        $promptError = "$pfDeb$promptDebugTag$resetFormat$pfErr$promptText$resetFormat$pfIndErr$promptIndicator$resetFormat"

        # Set continuation prompt to be on same position as main prompt.
        $promptlength = $promptDebugTag.Length + $promptText.Length
        $continuationPrompt = "$pfCon{0}$resetFormat$pfIndCon{1}$resetFormat" -f ([string][char]0x00B7 * $promptlength), $promptIndicator

        #Set-PSReadLineOption -PromptText "$promptText$promptIndicator" -ExtraPromptLineCount 2 -ContinuationPrompt "$continuationPrompt" -Colors @{ContinuationPrompt = 'Gray'}
        
        # Configure PSReadLine with custom prompt for error and continuation vatiants
        Set-PSReadLineOption -PromptText $promptNormal,$promptError -ContinuationPrompt $continuationPrompt

        # Return prompt
        $promptNormal

    } catch {
        Write-Host "Error during custom prompt, reverting to original.`n$_" -ForegroundColor Red
        #restore default prompt
        Set-Item Function:prompt $script:myOriginalPrompt
        return prompt
    }
}

# Key combinations
if($PSVersionTable.PSVersion.Major -ge 7){
    Set-PSReadLineKeyHandler -Chord 'Ctrl+q' -Function SwitchPredictionView # F2 does the same by default
    set-PSReadLineKeyHandler -Chord 'Ctrl+B' -Function GotoBrace # Ctrl-Shift+B because the default Ctrl+] is not a thing on German keyboards
}

# Custom functions
function Watch-Connection {
    param (
        [string]$ComputerName
    )

    Test-Connection -ComputerName $ComputerName -Continuous | 
      Select-Object @{Label='Time';Expression={Get-Date}},Ping,Address,Status,Latency
}

sal dauerping Watch-Connection

