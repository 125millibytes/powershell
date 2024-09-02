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

    # hex code for '›' to make it work with PowerShell 5 default encoding
    $promptIndicator = [string][char]0x203A
    
    #write the main prompt
    if($PSDebugContext) {
        Write-Host "[DBG]: " -NoNewLine -ForegroundColor Cyan
    }
    Write-Host "PS" -ForegroundColor $promptForegroundColor -NoNewLine # with version number: "PS$($PSVersionTable.PSVersion.Major)"

    # to make red prompt on syntax error work again. TODO: make continuatino prompt length match prompts length
    Set-PSReadLineOption -PromptText "$promptIndicator " -ExtraPromptLineCount 2 -ContinuationPrompt "..$promptIndicator "

    $promptIndicator * ($NestedPromptLevel+1) + " "
}
