<#
    .SYNOPSIS
        A class with methods that are equal for all class-based resources.

    .DESCRIPTION
        A class with methods that are equal for all class-based resources.

    .NOTES
        This class should be able to be inherited by all DSC resources. This class
        shall not contain any DSC properties, neither shall it contain anything
        specific to only a single resource.
#>

class ResourceBase
{
    # Property for holding localization strings
    hidden [System.Collections.Hashtable] $localizedData = @{}

    # Property for derived class to set properties that should not be enforced.
    hidden [System.String[]] $ExcludeDscProperties = @()

    # Property for holding the properties that are not in desired state.
    hidden [System.Collections.Hashtable[]] $PropertiesNotInDesiredState = @()

    # Property for derived class to enable Enums to be used as optional properties. The usable Enum values should start at value 1.
    hidden [System.Boolean] $FeatureOptionalEnums = $false

    # Property for derived class to not use Compare() method.
    hidden [System.Boolean] $FeatureNoCompare = $false

    # Default constructor
    ResourceBase()
    {
        $this.ImportLocalization($null)
    }

    ResourceBase([System.String] $BasePath)
    {
        $this.ImportLocalization($BasePath)
    }

    hidden [void] ImportLocalization([System.String] $BasePath)
    {
        $getLocalizedDataRecursiveParameters = @{
            ClassName = ($this | Get-ClassName -Recurse)
        }

        if (-not [System.String]::IsNullOrEmpty($BasePath))
        {
            <#
                Passing the base directory of the module that contains the
                derived class.
            #>
            $getLocalizedDataRecursiveParameters.BaseDirectory = $BasePath
        }

        <#
            TODO: When this fails, for example when the localized string file is missing
                the LCM returns the error 'Failed to create an object of PowerShell
                class SqlDatabasePermission' instead of the actual error that occurred.
        #>
        $this.localizedData = Get-LocalizedDataRecursive @getLocalizedDataRecursiveParameters
    }

    [ResourceBase] Get()
    {
        $this.Normalize()

        $this.Assert()

        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.GetCurrentState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $getCurrentStateResult = $this.GetCurrentState($keyProperty)

        $dscResourceObject = [System.Activator]::CreateInstance($this.GetType())

        # Set values returned from the derived class' GetCurrentState().
        foreach ($propertyName in $this.PSObject.Properties.Name)
        {
            if ($propertyName -in @($getCurrentStateResult.Keys) -and $null -ne $getCurrentStateResult.$propertyName)
            {
                $dscResourceObject.$propertyName = $getCurrentStateResult.$propertyName
            }
        }

        $keyPropertyAddedToCurrentState = $false

        # Set key property values unless it was returned from the derived class' GetCurrentState().
        foreach ($propertyName in $keyProperty.Keys)
        {
            if ($propertyName -notin @($getCurrentStateResult.Keys))
            {
                # Add the key value to the instance to be returned.
                $dscResourceObject.$propertyName = $this.$propertyName

                $keyPropertyAddedToCurrentState = $true
            }
        }

        if (($this | Test-DscProperty -Name 'Ensure') -and -not $getCurrentStateResult.ContainsKey('Ensure'))
        {
            # Evaluate if we should set Ensure property.
            if ($keyPropertyAddedToCurrentState)
            {
                <#
                    A key property was added to the current state, assume its because
                    the object did not exist in the current state. Set Ensure to Absent.
                #>
                $dscResourceObject.Ensure = [Ensure]::Absent
                $getCurrentStateResult.Ensure = [Ensure]::Absent
            }
            else
            {
                $dscResourceObject.Ensure = [Ensure]::Present
                $getCurrentStateResult.Ensure = [Ensure]::Present
            }
        }

        <#
            Returns all enforced properties not in desired state, or $null if
            all enforced properties are in desired state.
        #>
        $this.PropertiesNotInDesiredState = $this.Compare($getCurrentStateResult, @())

        <#
            Return the correct values for Reasons property if the derived DSC resource
            has such property and it hasn't been already set by GetCurrentState().
        #>
        if (($this | Test-DscProperty -Name 'Reasons') -and -not $getCurrentStateResult.ContainsKey('Reasons'))
        {
            # Always return an empty array if all properties are in desired state.
            $dscResourceObject.Reasons = $this.PropertiesNotInDesiredState |
                Resolve-Reason -ResourceName $this.GetType().Name |
                ConvertFrom-Reason
        }

        # Return properties.
        return $dscResourceObject
    }

    [void] Set()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        # Use new logic
        if ($this.FeatureNoCompare)
        {
            if ($this.Test())
            {
                Write-Verbose -Message $this.localizedData.NoPropertiesToSet
                return
            }
        }
        else # Use old logic
        {
            $null = $this.Compare()

            if (-not $this.PropertiesNotInDesiredState)
            {
                Write-Verbose -Message $this.localizedData.NoPropertiesToSet
                return
            }
        }

        $propertiesToModify = $this.PropertiesNotInDesiredState | ConvertFrom-CompareResult

        $propertiesToModify.Keys |
            ForEach-Object -Process {
                Write-Verbose -Message ($this.localizedData.SetProperty -f $_, $propertiesToModify.$_)
            }

        <#
            Call the Modify() method with the properties that should be enforced
            and are not in desired state.
        #>
        $this.Modify($propertiesToModify)
    }

    [System.Boolean] Test()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.TestDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        <#
            Returns all enforced properties not in desired state, or $null if
            all enforced properties are in desired state.
            Will call Get().
        #>
        if ($this.FeatureNoCompare)
        {
            $null = $this.Get()
        }
        else
        {
            $this.Compare()
        }

        if ($this.PropertiesNotInDesiredState)
        {
            Write-Verbose -Message $this.localizedData.NotInDesiredState
            return $false
        }

        Write-Verbose -Message $this.localizedData.InDesiredState
        return $true
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare()
    {
        # Get the current state, all properties except Read properties .
        $currentState = $this.Get() | Get-DscProperty -Attribute @('Key', 'Mandatory', 'Optional')

        return $this.Compare($currentState, @())
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare([System.Collections.Hashtable] $currentState, [System.String[]] $excludeProperties)
    {
        $desiredState = $this.GetDesiredState()

        $CompareDscParameterState = @{
            CurrentValues     = $currentState
            DesiredValues     = $desiredState
            Properties        = $desiredState.Keys
            ExcludeProperties = ($excludeProperties + $this.ExcludeDscProperties) | Select-Object -Unique
            IncludeValue      = $true
            # This is needed to sort complex types.
            SortArrayValues   = $true
        }

        <#
            Returns all enforced properties not in desired state, or $null if
            all enforced properties are in desired state.
        #>
        return (Compare-DscParameterState @CompareDscParameterState)
    }

    # This method should normally not be overridden.
    hidden [void] Assert()
    {
        $this.AssertProperties($this.GetDesiredState())
    }

    # This method should normally not be overridden.
    hidden [void] Normalize()
    {
        $this.NormalizeProperties($this.GetDesiredState())
    }

    # This is a private method and should normally not be overridden.
    hidden [System.Collections.Hashtable] GetDesiredState()
    {
        $getDscPropertyParameters = @{
            Attribute = @(
                'Key'
                'Mandatory'
                'Optional'
            )
            HasValue  = $true
        }

        if ($this.FeatureOptionalEnums)
        {
            $getDscPropertyParameters.IgnoreZeroEnumValue = $true
        }

        # Get the properties that has a non-null value and is not of type Read.
        $desiredState = $this | Get-DscProperty @getDscPropertyParameters

        return $desiredState
    }

    <#
        This method can be overridden if resource specific property asserts are
        needed. The parameter properties will contain the properties that are
        assigned a value.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidEmptyNamedBlocks', '')]
    hidden [void] AssertProperties([System.Collections.Hashtable] $properties)
    {
    }

    <#
        This method can be overridden if resource specific property normalization
        is needed. The parameter properties will contain the properties that are
        assigned a value.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidEmptyNamedBlocks', '')]
    hidden [void] NormalizeProperties([System.Collections.Hashtable] $properties)
    {
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the properties that should be enforced and that are not in desired
        state.
    #>
    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.ModifyMethodNotImplemented
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the key properties.
    #>
    hidden [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.GetCurrentStateMethodNotImplemented
    }
}
