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
        $this.SetCachedKeyProperties()

        $this.CachedDesiredState = $this.GetDesiredState()

        $this.Normalize()

        $this.Assert()

        Write-Verbose -Message ($this.localizedData.GetCurrentState -f $this.GetType().Name, ($this.CachedKeyProperties | ConvertTo-Json -Compress))

        $getCurrentStateResult = $this.GetCurrentState($this.CachedKeyProperties)

        $dscResourceObject = [System.Activator]::CreateInstance($this.GetType())

        $currentStateResultKeys = @($getCurrentStateResult.Keys)

        # Set values returned from the derived class' GetCurrentState().
        foreach ($propertyName in $this.PSObject.Properties.Name)
        {
            if ($propertyName -in $currentStateResultKeys -and $null -ne $getCurrentStateResult.$propertyName)
            {
                $dscResourceObject.$propertyName = $getCurrentStateResult.$propertyName
            }
        }

        $keyPropertyAddedToCurrentState = $false

        # Set key property values unless it was returned from the derived class' GetCurrentState().
        foreach ($propertyName in $this.CachedKeyProperties.Keys)
        {
            if ($propertyName -notin $currentStateResultKeys)
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
            Evaluate if we should set the canonical DSC property _exist. A key
            property added to the current state means the object was assumed to
            not exist in the current state.
        #>
        if (($this | Test-DscProperty -Name '_exist') -and -not $getCurrentStateResult.ContainsKey('_exist'))
        {
            $dscResourceObject._exist = -not $keyPropertyAddedToCurrentState
            $getCurrentStateResult._exist = -not $keyPropertyAddedToCurrentState
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
        Write-Debug -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name)

        if ($this.Test())
        {
            Write-Debug -Message $this.localizedData.NoPropertiesToSet
            return
        }

        # $this.PropertiesNotInDesiredState was set by the Get() method.
        # The Get() method is called by Test().
        $propertiesToModify = $this.PropertiesNotInDesiredState | ConvertFrom-CompareResult

        foreach ($property in $propertiesToModify.Keys)
        {
            Write-Verbose -Message ($this.localizedData.SetProperty -f $property, $propertiesToModify.$property)
        }

        <#
            Call the Modify() method with the properties that should be enforced
            and are not in desired state.
        #>
        $this.Modify($propertiesToModify)
    }

    [System.Boolean] Test()
    {
        Write-Debug -Message ($this.localizedData.TestDesiredState -f $this.GetType().Name)

        $null = $this.Get()

        # $this.PropertiesNotInDesiredState was set by the Get() method.
        if ($this.PropertiesNotInDesiredState)
        {
            Write-Verbose -Message $this.localizedData.NotInDesiredState
            return $false
        }

        Write-Verbose -Message $this.localizedData.InDesiredState
        return $true
    }

    <#
        Returns the DSC test result for the resource as a strongly typed tuple of
        type [System.Tuple[System.Boolean, <DerivedClass>, System.String[]]] where:

        Item1 - $true if the resource is in the desired state, otherwise $false.
        Item2 - An instance of the derived class representing the actual state.
        Item3 - The names of the properties that are not in the desired state.

        This method should normally not be overridden. It is meant to be called
        by the derived class static method Test([<DerivedClass>] $instance) that
        participates in the semantics of Microsoft DSC.
    #>
    hidden [System.Object] GetTestResult()
    {
        $actualState = $this.Get()

        # $this.PropertiesNotInDesiredState was set by the Get() method.
        $inDesiredState = -not $this.PropertiesNotInDesiredState

        [System.String[]] $differingProperties = @()

        if (-not $inDesiredState)
        {
            $differingProperties = [System.String[]] @($this.PropertiesNotInDesiredState.Property)
        }

        return (New-DscResultTuple -Type @([System.Boolean], $this.GetType(), [System.String[]]) -Value @($inDesiredState, $actualState, $differingProperties))
    }

    <#
        Enforces the desired state and returns the DSC set result as a strongly
        typed tuple of type [System.Tuple[<DerivedClass>, System.String[]]] where:

        Item1 - An instance of the derived class representing the state after the
                set operation, or the predicted state in what-if mode.
        Item2 - The names of the properties that were (or would be) changed.

        This method should normally not be overridden. It is meant to be called
        by the derived class static methods Set([<DerivedClass>] $instance) and
        Set([<DerivedClass>] $instance, [System.Boolean] $whatIf) that participate
        in the semantics of Microsoft DSC.
    #>
    hidden [System.Object] GetSetResult()
    {
        return $this.GetSetResult($false)
    }

    hidden [System.Object] GetSetResult([System.Boolean] $WhatIf)
    {
        Write-Debug -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name)

        $currentState = $this.Get()

        # $this.PropertiesNotInDesiredState was set by the Get() method.
        if (-not $this.PropertiesNotInDesiredState)
        {
            Write-Debug -Message $this.localizedData.NoPropertiesToSet

            return (New-DscResultTuple -Type @($this.GetType(), [System.String[]]) -Value @($currentState, [System.String[]] @()))
        }

        [System.String[]] $changedProperties = [System.String[]] @($this.PropertiesNotInDesiredState.Property)

        if ($WhatIf)
        {
            Write-Verbose -Message ($this.localizedData.WhatIfDesiredState -f $this.GetType().Name)

            $afterState = $this.GetPredictedState($currentState)
        }
        else
        {
            $propertiesToModify = $this.PropertiesNotInDesiredState | ConvertFrom-CompareResult

            foreach ($property in $propertiesToModify.Keys)
            {
                Write-Verbose -Message ($this.localizedData.SetProperty -f $property, $propertiesToModify.$property)
            }

            <#
                Call the Modify() method with the properties that should be enforced
                and are not in desired state.
            #>
            $this.Modify($propertiesToModify)

            # Get the authoritative state after the modification.
            $afterState = $this.Get()
        }

        return (New-DscResultTuple -Type @($this.GetType(), [System.String[]]) -Value @($afterState, $changedProperties))
    }

    <#
        Returns a new instance of the derived class representing the predicted
        state after a set operation, without modifying the system. The predicted
        state is the current state with the expected value applied to each
        property that is not in the desired state.

        This method should normally not be overridden.
    #>
    hidden [ResourceBase] GetPredictedState([ResourceBase] $currentState)
    {
        $predictedState = [System.Activator]::CreateInstance($this.GetType())

        # Copy the DSC properties from the current state.
        $currentStateProperties = $currentState | Get-DscProperty

        foreach ($propertyName in @($currentStateProperties.Keys))
        {
            if ($null -ne $currentStateProperties.$propertyName)
            {
                $predictedState.$propertyName = $currentStateProperties.$propertyName
            }
        }

        # Apply the desired value for each property that is not in the desired state.
        foreach ($property in $this.PropertiesNotInDesiredState)
        {
            $predictedState.($property.Property) = $property.ExpectedValue
        }

        # The predicted state is by definition in the desired state.
        if ($predictedState | Test-DscProperty -Name 'Reasons')
        {
            $predictedState.Reasons = @()
        }

        return $predictedState
    }

    <#
        Deletes the resource instance from the system. The default implementation
        requires the resource to have the canonical DSC property _exist, or the
        property Ensure as a fallback, and enforces the desired state with _exist
        set to $false (or Ensure set to Absent). Resources without either property
        must override this method to support the Microsoft DSC delete operation.

        This method is meant to be called by the derived class static method
        Delete([<DerivedClass>] $instance) that participates in the semantics
        of Microsoft DSC.
    #>
    hidden [void] DeleteInstance()
    {
        if ($this | Test-DscProperty -Name '_exist')
        {
            Write-Verbose -Message ($this.localizedData.DeleteInstance -f $this.GetType().Name)

            $this._exist = $false
        }
        elseif ($this | Test-DscProperty -Name 'Ensure')
        {
            Write-Verbose -Message ($this.localizedData.DeleteInstance -f $this.GetType().Name)

            $this.Ensure = [Ensure]::Absent
        }
        else
        {
            throw ($this.localizedData.DeleteInstanceNotSupported -f $this.GetType().Name)
        }

        $this.Set()
    }

    <#
        This method can be overridden by a resource to support the Microsoft DSC export
        operation. It must return every instance of the resource on the system, or,
        when the parameter filteringInstance is not $null, only the matching
        instances. The override must use the exact same method signature; the
        returned array can hold instances of the derived class.

        This method is meant to be called by the derived class static methods
        Export() and Export([<DerivedClass>] $filteringInstance) that participate
        in the semantics of Microsoft DSC.
    #>
    hidden [ResourceBase[]] ExportInstances([ResourceBase] $filteringInstance)
    {
        throw ($this.localizedData.ExportInstancesMethodNotImplemented -f $this.GetType().Name)
    }

    <#
        Returns the JSON schema for an instance of the derived resource class,
        built at runtime using reflection over the DSC properties. Reflection
        sees properties inherited from base classes in other modules, which
        build-time AST tooling cannot.

        This method is meant to be called by the derived class static method
        InstanceJsonSchema() that participates in the semantics of Microsoft DSC.
    #>
    hidden [System.String] GetInstanceJsonSchema()
    {
        return (ConvertTo-DscResourceJsonSchema -ResourceType $this.GetType())
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.

        This method is only used by Get().
    #>
    hidden [System.Collections.Hashtable[]] Compare([System.Collections.Hashtable] $currentState, [System.String[]] $excludeProperties)
    {
        # $this.CachedDesiredState was set by the Get() method.
        $CompareDscParameterState = @{
            CurrentValues     = $currentState
            DesiredValues     = $this.CachedDesiredState
            Properties        = $this.CachedDesiredState.Keys
            ExcludeProperties = @(($excludeProperties + $this.ExcludeDscProperties) | Sort-Object -Unique)
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
    hidden [void] SetCachedKeyProperties()
    {
        # Sets the key properties of the resource.
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
