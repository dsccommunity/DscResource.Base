<#
    .SYNOPSIS
        Get the localization strings data from one or more localization string files.

    .DESCRIPTION
        Get the localization strings data from one or more localization string files.
        This can be used in classes to be able to inherit localization strings
        from one or more parent (base) classes.

        The order of class names passed to parameter `ClassName` determines the order
        of importing localization string files. First entry's localization string file
        will be imported first, then next entry's localization string file, and so on.
        If the second (or any consecutive) entry's localization string file contain a
        localization string key that existed in a previous imported localization string
        file that localization string key will be ignored. Making it possible for a
        child class to override localization strings from one or more parent (base)
        classes.

    .PARAMETER ClassName
        An array of class names, normally provided by `Get-ClassName -Recurse`.

    .PARAMETER BaseDirectory
        Specifies a base module path where it also searches for localization string
        files.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName $InputObject.GetType().FullName

        Returns a hashtable containing all the localized strings for the current
        instance.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName (Get-ClassName -InputObject $this -Recurse)

        Returns a hashtable containing all the localized strings for the current
        instance and any inherited (parent) classes.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function Get-LocalizedDataRecursive
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]
        $ClassName,

        [Parameter()]
        [System.String]
        $BaseDirectory
    )

    begin
    {
        $localizedData = @{}
    }

    process
    {
        foreach ($name in $ClassName)
        {
            if ($name -match '\.psd1$')
            {
                # Assume we got full file name.
                $localizationFileName = $name -replace '\.psd1$'
            }
            else
            {
                # Assume we only got class name.
                $localizationFileName = '{0}.strings' -f $name
            }

            Write-Debug -Message ($script:localizedData.DebugImportingLocalizationData -f $localizationFileName)

            if ($name -eq 'ResourceBase')
            {
                # The class ResourceBase will always be in the same module as this command.
                $path = $PSScriptRoot
            }
            elseif ($null -ne $BaseDirectory)
            {
                # Assuming derived class that is not part of this module.
                $path = $BaseDirectory
            }
            else
            {
                # Assuming derived class that is not part of this module.
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $script:localizedData.ThrowClassIsNotPartOfModule,
                        'DRB0002',
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $name
                    )
                )
            }

            # Get localized data for the class
            $classLocalizationStrings = Get-LocalizedData -DefaultUICulture 'en-US' -BaseDirectory $path -FileName $localizationFileName -ErrorAction 'Stop'

            # Append only previously unspecified keys in the localization data
            foreach ($key in $classLocalizationStrings.Keys)
            {
                if (-not $localizedData.ContainsKey($key))
                {
                    $localizedData[$key] = $classLocalizationStrings[$key]
                }
            }
        }
    }

    end
    {
        Write-Debug -Message ($script:localizedData.DebugShowAllLocalizationData -f ($localizedData | ConvertTo-JSON))

        return $localizedData
    }
}
