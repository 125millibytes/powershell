# Custom prompt function for PowerShell 7 and PowerShell 5
# Save as $PROFILE.CurrentUserAllHosts
# To link PS5's profile to PS7's file, run this in PS5: 
#   mkdir ($PROFILE.CurrentUserAllHosts | Split-Path -Parent) -ea SilentlyContinue
#   ni -Type HardLink -Path ($PROFILE.CurrentUserAllHosts) -Target (pwsh -c `$PROFILE.CurrentUserAllHosts)

$ErrorActionPreference = 'Stop'

# Store the original prompt function to allow reverting in case of errors
$script:myOriginalPrompt = (Get-Command prompt -CommandType Function -ErrorAction SilentlyContinue).ScriptBlock

# Check if the current user has admin permissions
$user = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()))
$isAdmin = $user.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# initialize history ID to non-null value to show path on first prompt
$script:lastHistoryId = -1

# Colors and fornmtting
try{
    # ANSI color codes: `e[XYm
    # X: 3 = foreground, 4 = background, 9 = bright, 10 = bright background
    # Y: 0 = Black, 1 = Red, 2 = Green, 3 = Yellow, 4 = Blue, 5 = Magenta, 6 = Cyan, 7 = White, 9 = Default
    # TODO: Workaround for dim mode (`e[2m) having the reverse effect in Windows Terminal light themes, because it makes the text darker regardless of background color.
    
    $esc = [char]27
    $resetFormat = "$esc[0m"

    # PSReadLine colors (syntax highlighting ...)
    Set-PSReadLineOption -Colors @{
        Default = "$esc[37m"
        Keyword = "$esc[95m"
        Operator="$esc[36m"
        Member = "$esc[33m"
        Variable = "$esc[96m"
        Type = "$esc[34m"
        Number = "$esc[92m"
        String = "$esc[34m"
        Command = "$esc[93m"
        Parameter = "$esc[36m"
        Error = "$esc[91m"
        Selection = "$esc[30;47m"
        Emphasis = "$esc[96m"
        
        #ContinuationPrompt ?
        #ListPredictionTooltip ?
    }
    
    # Prediction list is only available in PS7+
    if($PSVersionTable.PSVersion.Major -ge 7){
        Set-PSReadLineOption -Colors @{
            ListPrediction = "$esc[30m"
            ListPredictionSelected = "$esc[37;100m"
            InlinePrediction = "$esc[90;3m"
        }
    }

    # FileInfo colors
    $PSStyle.FileInfo.Directory = "$esc[94m"
    $PSStyle.FileInfo.SymbolicLink = "$esc[35m"
    $PSStyle.FileInfo.Executable = "$esc[93m"

    $extensionColors = @{
        "$esc[36m" = '.zip','.tgz','.gz','.tar','.7z','.rar','.iso','.vhd','.vhdx';
        "$esc[93m" = '.ps1';
        "$esc[33m" = '.psd1','.psm1','.ps1xml';
    }
    foreach ($ext in $extensionColors.GetEnumerator()){
        $ext.Value | % {$PSStyle.FileInfo.Extension[$_] = $ext.Key}
    }

    # Formatting colors
    $formattingColors = @{
        Error = "$esc[91m"
        Warning = "$esc[93m"
        Verbose = "$esc[93m"
        Debug = "$esc[93m"
        TableHeader ="$esc[92m"
        CustomTableHeaderLabel = "$esc[32m"
        FormatAccent = "$esc[32m"
    } 
    $formattingColors.GetEnumerator() | % {$PSStyle.Formatting.$($_.Key) = $_.Value}

} catch {
    Write-Output "Error setting PSReadLine and `$PSStyle colors`n$_"
}

# Prompt format (Normal, Error, Path, Debug, Continuation, Indicator)
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
        $newHistoryId = (Get-History -Count 1).Id
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

        # Configure PSReadLine for custom prompt, with error and continuation vatiants
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
