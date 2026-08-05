<#
    .SYNOPSIS
        Creates a strongly typed tuple from the specified types and values.

    .DESCRIPTION
        Creates a strongly typed tuple from the specified types and values. The
        tuple is closed over the exact types that are passed in the parameter
        Type, in the same order as the values passed in the parameter Value.

        The class ResourceBase uses this function to build the return values for
        the DSC operation methods, for example the test result tuple
        [System.Tuple[System.Boolean, <DerivedClass>, System.String[]]].

    .PARAMETER Type
        The types to close the tuple over, in element order.

    .PARAMETER Value
        The values for each tuple element, in the same order as the parameter
        Type.

    .EXAMPLE
        New-DscResultTuple -Type @([System.Boolean], [System.String]) -Value @($true, 'MyValue')

        Returns a tuple of type [System.Tuple[System.Boolean, System.String]].

    .OUTPUTS
        [System.Object]

    .NOTES
        Tuples are invariant classes, so a tuple closed over a base class type
        does not convert to a declared return type that is closed over a derived
        class type. The caller must always close the tuple over the runtime type
        of the instance, e.g. $this.GetType(), so that a derived class static
        method declared with the derived class type can return the tuple.

        The explicit MakeGenericType() call is used instead of
        [System.Tuple]::Create() because generic type inference infers the type
        System.Object for null arguments.
#>
function New-DscResultTuple
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'The function does not change state, it only creates and returns a tuple object.')]
    [CmdletBinding()]
    [OutputType([System.Object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Type[]]
        $Type,

        <#
            AllowNull() is required because a mandatory parameter is implicitly
            validated as not null, and that validation rejects a collection that
            contains a null element. A tuple element is allowed to be null.
        #>
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.Object[]]
        $Value
    )

    if ($Type.Count -ne $Value.Count)
    {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                ($script:localizedData.NewDscResultTuple_CountMismatch -f $Type.Count, $Value.Count),
                'DRB0004',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Type
            )
        )
    }

    $openTupleType = [System.Type] ('System.Tuple`{0}' -f $Type.Count)

    $closedTupleType = $openTupleType.MakeGenericType($Type)

    $argumentList = [System.Object[]]::new($Value.Count)

    for ($i = 0; $i -lt $Value.Count; $i++)
    {
        if ($null -eq $Value[$i])
        {
            $argumentList[$i] = $null
        }
        else
        {
            $argumentList[$i] = $Value[$i].PSObject.BaseObject
        }
    }

    return [System.Activator]::CreateInstance($closedTupleType, $argumentList)
}
