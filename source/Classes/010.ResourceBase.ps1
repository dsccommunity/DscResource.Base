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

    # Property for holding the desired state.
    hidden [System.Collections.Hashtable] $CachedDesiredState = $null

    # Property for holding the key properties.
    hidden [System.Collections.Hashtable] $CachedKeyProperties = $null

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
        if (-not $this.CachedKeyProperties)
        {
            $this.GetKeyProperties()
        }

        $this.CachedDesiredState = $this.GetDesiredState()

        $this.Normalize()

        $this.Assert()

        Write-Verbose -Message ($this.localizedData.GetCurrentState -f $this.GetType().Name, ($this.CachedKeyProperties | ConvertTo-Json -Compress))

        $getCurrentStateResult = $this.GetCurrentState($this.CachedKeyProperties)

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
        foreach ($propertyName in $this.CachedKeyProperties.Keys)
        {
            if ($propertyName -notin @($getCurrentStateResult.Keys))
            {
                # Add the key value to the instance to be returned.
                $dscResourceObject.$propertyName = $this.$propertyName
                $getCurrentStateResult.$propertyName = $this.$propertyName

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
        if (-not $this.CachedKeyProperties)
        {
            $this.GetKeyProperties()
        }

        Write-Verbose -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name, ($this.CachedKeyProperties | ConvertTo-Json -Compress))

        if ($this.Test())
        {
            Write-Verbose -Message $this.localizedData.NoPropertiesToSet
            return
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
        if (-not $this.CachedKeyProperties)
        {
            $this.GetKeyProperties()
        }

        Write-Verbose -Message ($this.localizedData.TestDesiredState -f $this.GetType().Name, ($this.CachedKeyProperties | ConvertTo-Json -Compress))

        $null = $this.Get()

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
    hidden [System.Collections.Hashtable[]] Compare([System.Collections.Hashtable] $currentState, [System.String[]] $excludeProperties)
    {
        $CompareDscParameterState = @{
            CurrentValues     = $currentState
            DesiredValues     = $this.CachedDesiredState
            Properties        = $this.CachedDesiredState.Keys
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
        $this.AssertProperties($this.CachedDesiredState)
    }

    # This method should normally not be overridden.
    hidden [void] Normalize()
    {
        $this.NormalizeProperties($this.CachedDesiredState)
    }

    # This is a private method and should normally not be overridden.
    hidden [System.Collections.Hashtable] GetDesiredState()
    {
        $getDscPropertyParameters = @{
            Attribute           = @(
                'Key'
                'Mandatory'
                'Optional'
            )
            HasValue            = $true
            IgnoreZeroEnumValue = $true
        }

        # Get the properties that has a non-null value and is not of type Read.
        $desiredState = $this | Get-DscProperty @getDscPropertyParameters

        return $desiredState
    }

    # This is a private method and should normally not be overridden.
    hidden [void] GetKeyProperties()
    {
        <#
            Sets the key properties of the resource.
        #>
        $this.CachedKeyProperties = $this | Get-DscProperty -Attribute 'Key'
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
