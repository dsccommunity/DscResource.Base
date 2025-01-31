# Welcome to the DscResource.Base wiki

<sup>*DscResource.Base v#.#.#*</sup>

Here you will find all the information you need to make use of the class
`ResourceBase`.

Please leave comments, feature requests, and bug reports for this module in
the [issues section](https://github.com/dsccommunity/DscResource.Base/issues)
for this repository.

## Getting started

This module provides a base class for creating DSC resources.

Assuming you are using the DscCommunity Sampler template, add `DscResource.Base` to your `RequiredModules.psd1`.

Ensure that your `prefix.ps1` contains `using module .\Modules\DscResource.Base` to import the module.

Add the following to a new file:

```powershell
[DscResource()]
class MyDscResource : ResourceBase
{
    <#
    PROPERTIES / PARAMETERS
    #>

    MyDscResource () : base ($PSScriptRoot)
    {
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
}
```

### Parameters

Value type parameters like `Boolean`, `Int`, `UInt` must have their type made
nullable e.g. `[Nullable[System.Boolean]]`.

Reference type parameters like `String` do not have this requirement.

Enums may be used, but only for parameters marked `Key` or `Mandatory`.

### Constructor

The constructor above shows the minimum implementation required.
`$PSScriptRoot` is passed down to the base class to update the location of the
localization files. Without this you may see an error when using the resource of
not being able to find localization data.

There is a hidden variable available `ExcludeDscProperties`. Adding parameter
names as strings to this will exclude them from comparison and not cause the
`Set()` method to be run.

Typically, optional parameters are added here that if populated would not cause
the resource to not be in the desired state.

### Methods

The only two methods you must implement are `GetCurrentState()` and `Modify()`.

An optional method `Assert-Properties` is available as a replacement of
PowerShell `[ValidateScript()]` functionality as this is not available to
parameters with a `[DscProperty()]` attribute.

#### GetCurrentState()

This method is used to get the data and populate a hashtable with the resources parameters.
This is called by `.Get()`.

The properties passed into this method are a hashtable of any properties marked `Key`.
These properties should be used for any arguments on commands called within this
 method and not using `$this.ParameterName`

The hashable only needs to return the values that are not `$null`. Any that are
`$null` can be omitted as these are added to the hashtable from the calling
method.

#### Modify()

This method is used to change the state of the resource being controlled.
This is called by `.Set()`.

The properties passed into this method are the ones that need to be enforced and
are not in the desired state.

This function can either be used for any `Set/Add/Remove` behaviour, but if this
needs breaking up then additional methods can be created and called from here.

#### Assert-Properties()

This method is used as a replacement for `[ValidateScript()]` on parameters or
parameter sets as this is not available in class-based DSC resources.

Scenarios for use are:

- Checking use of exclusive parameters.
- Validating values are correct e.g. StartTime < EndTime.

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
