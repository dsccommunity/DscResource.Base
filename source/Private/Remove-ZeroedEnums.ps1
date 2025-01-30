function Remove-ZeroedEnums
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Hashtable]
        $InputObject
    )

    process
    {
        $result = @{}

        foreach ($property in $InputObject.Keys)
        {
            $value = $InputObject.$property
            if ($value -is [System.Enum] -and [System.Int32]$value.value__ -eq 0)
            {
                continue
            }

            $result.$property = $value
        }

        return $result
    }
}
