# Custom prompt function for PowerShell 7 and PowerShell 5
# To link PS5 profile to PS7's file, run this as admin in PS5: 
# mkdir (Split-Path $PROFILE -Parent)
# ni -Type HardLink -Path $PROFILE -Target (pwsh -c `$PROFILE)

function prompt {
    # Prompt color based on admin permissions
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $promptForegroundColor = if($isAdmin) {'DarkYellow'} else {'DarkCyan'}
    
    # check history to see if previous prompt was cancelled
    $newHistoryCount = @(Get-History).Count
    $previousPromptCancelled = $global:promptHistoryCount -eq $newHistoryCount
    $global:promptHistoryCount = $newHistoryCount
    
    if(-not $previousPromptCancelled){
        # write blank line and currect directory on a separate line
        Write-Host
        Write-Host $pwd -ForegroundColor DarkGray        
    }

    # hex codes for '›' and '»' to make it work with PowerShell 5 default encoding
    $promptIndicator = if($NestedPromptLevel -lt 1) {[string][char]0x203A} else {[string][char]0x00BB}
    $promptIndicator = "$promptIndicator "

    # write the main prompt
    $promptLength = 0;
    if($PSDebugContext) {
        Write-Host "[DBG]: " -NoNewLine -ForegroundColor Cyan
        $promptLength += 7;
    }
    Write-Host "PS" -ForegroundColor $promptForegroundColor -NoNewLine # with version number: "PS$($PSVersionTable.PSVersion.Major)"
    $promptLength += 2;

    # set continuation prompt to be on same position as main prompt
    $continuationPrompt = "·" * $promptLength + "$promptIndicator"

    # to make red prompt on syntax error work again.
    Set-PSReadLineOption -PromptText "$promptIndicator" -ExtraPromptLineCount 2 -ContinuationPrompt $continuationPrompt -Colors @{ContinuationPrompt = 'Gray'}

    $promptIndicator
}
