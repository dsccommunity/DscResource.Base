# Welcome to the DscResource.Base wiki

<sup>*DscResource.Base v#.#.#*</sup>

Here you will find all the information you need to make use of the class
`ResourceBase`.

Please leave comments, feature requests, and bug reports for this module in
the [issues section](https://github.com/dsccommunity/DscResource.Base/issues)
for this repository.

## Getting Started

This module provides a base class for creating DSC resources.

Assuming you are using the DscCommunity Sampler template, add `DscResource.Base` to your `RequiredModules.psd1`.

Ensure that your `prefix.ps1` contains `using module .\Modules\DscResource.Base` to import the module.

Add the following into a new file (typical location `source\Classes`):

```powershell
[DscResource()]
class MyDscResource : ResourceBase
{
    <#
        PROPERTIES / PARAMETERS
    #>

    MyDscResource () : base ($PSScriptRoot)
    {
        $this.ExcludeDscProperties = @()
        $this.FeatureOptionalEnums = $false
    }

    # Required DSC Methods, these call the method in the base class.
    [MyDscResource] Get()
    {
        # Call the base method to return the properties.
        return ([ResourceBase] $this).Get()
    }

    [void] Set()
    {
        # Call the base method to enforce the properties.
        ([ResourceBase] $this).Set()
    }

    [System.Boolean] Test()
    {
        # Call the base method to test all of the properties that should be enforced.
        return ([ResourceBase] $this).Test()
    }

    # Base method Get() call this method to get the current state as a Hashtable.
    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
    }

    <#
        Base method Set() call this method with the properties that should be
        enforced and that are not in desired state.
    #>
    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
    }

    # OPTIONAL
    <#
        This method can be overridden if resource specific property asserts are
        needed. The parameter properties will contain the properties that was
        assigned a value.
    #>
    hidden [void] AssertProperties([System.Collections.Hashtable] $properties)
    {
    }

    <#
        This method can be overridden if resource specific property normalization
        is needed. The parameter properties will contain the properties that was
        assigned a value.
    #>
    hidden [void] NormalizeProperties([System.Collections.Hashtable] $properties)
    {
    }
}
```

### Parameters/Properties

Value type parameters like `Boolean`, `Int`, `UInt` must have their type made
nullable e.g. `[Nullable[System.Boolean]]`.

Reference type parameters like `String` do not have this requirement.

Enums may be used, but only for parameters marked `Key` or `Mandatory`.

There is an optional feature flag `FeatureOptionalEnums` which when enabled will
allow the use of Enums for optional properties. These do require special consideration,
the Enum must be created with a starting value of 1. Leaving 0 for uninitialized.
This is due to Enums not being Nullable in PowerShell DSC.

```powershell
enum MyEnum
{
    Square = 1
    Circle
}
```

#### Ensure

The base class ships with an `Ensure` Enum which you may use. This is typically mandatory.

```powershell
[DscProperty(Mandatory)]
[Ensure]
$Ensure
```

#### Reasons

The base class will populate the `Reasons` parameter if the actual state does not
match the current state.

To utilize this you must create your own `Reason` class for the module.
This is typically is prefixed with the module name. The example below is what is
used in `SqlServerDsc`.

```powershell
<#
    .SYNOPSIS
        The reason a property of a DSC resource is not in desired state.

    .DESCRIPTION
        A DSC resource can have a read-only property `Reasons` that the compliance
        part (audit via Azure Policy) of Azure AutoManage Machine Configuration
        uses. The property Reasons holds an array of SqlReason. Each SqlReason
        explains why a property of a DSC resource is not in desired state.
#>

class SqlReason
{
    [DscProperty()]
    [System.String]
    $Code

    [DscProperty()]
    [System.String]
    $Phrase
}
```

This is how you would declare the parameter.

```powershell
[DscProperty(NotConfigurable)]
[SqlReason[]]
$Reasons
```

### Constructor

The constructor above shows the minimum implementation required.
`$PSScriptRoot` is passed down to the base class to update the location of the
localization files. Without this you may see an error when using the resource of
not being able to find localization data.

There is a hidden variable available `ExcludeDscProperties`. Adding parameter
names as strings to this will exclude them from comparison.

Typically, optional parameters are added here that if populated would not cause
the resource to not be in the desired state.

### Methods

The two methods you must implement which are `GetCurrentState()` and `Modify()`.
There are two optional methods which you may use these are `AssertProperties()` and
`NormalizeProperties()`.

#### `GetCurrentState()`

This method is used to get the data and populate a hashtable with the resources parameters.
This is called by `Get()`.

The `$properties` argument passed into this method are a hashtable of any
properties marked `Key`.

These properties should be used for any arguments on commands called within this
method and not using `$this.ParameterName`.

The hashable only needs to return the values that are not `$null`. Any that are
`$null` can be omitted as these are added to the hashtable from the calling
method.

#### `Modify()`

This method is used to change the state of the resource being controlled.
This is called by `Set()`.

The properties passed into this method are the ones that need to be enforced and
are not in the desired state.

This function can either be used for any `Set/Add/Remove` behavior, but if this
needs breaking up then additional methods can be created within your class
and called here.

#### `AssertProperties()`

This method is used as a replacement for `[ValidateScript()]` on parameters or
parameter sets as this is not available in class-based DSC resources.

Scenarios for use are:

- Checking use of exclusive parameters.
- Validating values are correct e.g. StartTime < EndTime.

#### `NormalizeProperties()`

This method is used to Normalize any parameter values that may have been provided
by the user but can be standardized.

Scenario examples:

- Formatting a file path
- Formatting a URL

## Prerequisites

- Powershell 5.0 or higher

### Powershell

It is recommended to use Windows Management Framework (PowerShell) version 5.1.

The minimum Windows Management Framework (PowerShell) version required is 5.0,
which ships with Windows 10 or Windows Server 2016, but can also be installed
on Windows 7 SP1, Windows 8.1, Windows Server 2012, and Windows Server 2012 R2.

To use in PowerShell (v7.x) it must be configured to run class-based resources.
See other documentation resources on how to make PowerShell work with class-based
resources

## Change log

A full list of changes in each version can be found in the [change log](https://github.com/dsccommunity/DscResource.Base/blob/main/CHANGELOG.md).
