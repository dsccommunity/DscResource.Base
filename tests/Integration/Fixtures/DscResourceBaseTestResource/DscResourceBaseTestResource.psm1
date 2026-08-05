using module DscResource.Base

<#
    In-memory store representing the system state for the test resource.
    Each key is the name of an instance and the value is the instance value.
#>
$script:testResourceCurrentState = @{
    'Instance1' = 'Value1'
    'Instance2' = 'Value2'
}

<#
    .SYNOPSIS
        A class-based DSC resource used by the integration tests.

    .DESCRIPTION
        A class-based DSC resource that derives from ResourceBase in the module
        DscResource.Base. The resource is backed by an in-memory store so the
        integration tests never modify the system.

    .PARAMETER Name
        The name of the instance.

    .PARAMETER Value
        The value of the instance.

    .PARAMETER _exist
        Canonical DSC property specifying whether the instance should exist.

    .PARAMETER Reasons
        Returns the reason a property is not in the desired state.
#>
[DscResource()]
class DscBaseTestResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $Name

    [DscProperty()]
    [System.String]
    $Value

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    DscBaseTestResource () : base ($PSScriptRoot)
    {
        # The key property is returned by Get() but not enforced.
        $this.ExcludeDscProperties = @(
            'Name'
        )
    }

    #region PSDSC overrides
    hidden [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        $currentState = @{}

        if ($script:testResourceCurrentState.ContainsKey($properties.Name))
        {
            $currentState.Name = $properties.Name
            $currentState.Value = $script:testResourceCurrentState[$properties.Name]
        }

        return $currentState
    }

    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        if ($properties.ContainsKey('_exist') -and -not $properties.'_exist')
        {
            $script:testResourceCurrentState.Remove($this.Name)

            return
        }

        $script:testResourceCurrentState[$this.Name] = $this.Value
    }

    hidden [ResourceBase[]] ExportInstances([ResourceBase] $filteringInstance)
    {
        $instances = [System.Collections.Generic.List[ResourceBase]]::new()

        foreach ($instanceName in ($script:testResourceCurrentState.Keys | Sort-Object))
        {
            if ($null -ne $filteringInstance -and -not [System.String]::IsNullOrEmpty($filteringInstance.Name) -and $instanceName -ne $filteringInstance.Name)
            {
                continue
            }

            $instance = [DscBaseTestResource]::new()
            $instance.Name = $instanceName
            $instance.Value = $script:testResourceCurrentState[$instanceName]
            $instance._exist = $true

            $instances.Add($instance)
        }

        return $instances.ToArray()
    }
    #endregion PSDSC overrides

    #region DSC (v3) static methods
    static [DscBaseTestResource] Get([DscBaseTestResource] $instance)
    {
        return $instance.Get()
    }

    static [System.Tuple[System.Boolean, DscBaseTestResource, System.String[]]] Test([DscBaseTestResource] $instance)
    {
        return $instance.GetTestResult()
    }

    static [System.Tuple[DscBaseTestResource, System.String[]]] Set([DscBaseTestResource] $instance)
    {
        return $instance.GetSetResult($false)
    }

    static [System.Tuple[DscBaseTestResource, System.String[]]] Set([DscBaseTestResource] $instance, [System.Boolean] $whatIf)
    {
        return $instance.GetSetResult($whatIf)
    }

    static [void] Delete([DscBaseTestResource] $instance)
    {
        $instance.DeleteInstance()
    }

    static [DscBaseTestResource[]] Export()
    {
        return [DscBaseTestResource]::new().ExportInstances($null)
    }

    static [DscBaseTestResource[]] Export([DscBaseTestResource] $filteringInstance)
    {
        return [DscBaseTestResource]::new().ExportInstances($filteringInstance)
    }

    static [System.String] InstanceJsonSchema()
    {
        return [DscBaseTestResource]::new().GetInstanceJsonSchema()
    }
    #endregion DSC (v3) static methods
}
