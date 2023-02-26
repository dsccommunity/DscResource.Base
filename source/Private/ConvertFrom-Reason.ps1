<#
    .SYNOPSIS
        Returns a array of the type `System.Collections.Hashtable`.

    .DESCRIPTION
        This command converts an array of [Reason] that is returned by the command
        `New-Reason`. The result is an array of the type `[System.Collections.Hashtable]`
        that can be returned as the value of a DSC resource's property **Reasons**.

    .PARAMETER Reason
       Specifies an array of `[Reason]`. Normally the result from the command `New-Reason`.

    .EXAMPLE
        New-Reason -Reason (New-Reason) -ResourceName 'MyResource'

        Returns an array of `[System.Collections.Hashtable]` with the converted
        `[Reason[]]`.

    .OUTPUTS
        [System.Collections.Hashtable[]]
#>
function ConvertFrom-Reason
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Because the rule does not understands that the command returns [System.Collections.Hashtable[]] when using , (comma) in the return statement')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseSyntacticallyCorrectExamples', '', Justification = 'Because the rule does not yet support parsing the code when the output type is not available. The ScriptAnalyzer rule UseSyntacticallyCorrectExamples will always error in the editor due to https://github.com/indented-automation/Indented.ScriptAnalyzerRules/issues/8.')]
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Reason[]]
        $Reason
    )

    begin
    {
        # Always return an empty array if there are nothing to convert.
        $reasonsAsHashtable = [System.Collections.Hashtable[]] @()
    }

    process
    {
        foreach ($currentReason in $Reason)
        {
            $reasonsAsHashtable += [System.Collections.Hashtable] @{
                Code   = $currentReason.Code
                Phrase = $currentReason.Phrase
            }
        }
    }

    end
    {
        return , [System.Collections.Hashtable[]] $reasonsAsHashtable
    }
}
