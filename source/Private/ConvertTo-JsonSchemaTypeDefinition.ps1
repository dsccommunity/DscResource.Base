<#
    .SYNOPSIS
        Converts a .NET type to its JSON schema type definition.

    .DESCRIPTION
        Converts a .NET type to a hashtable describing the equivalent JSON
        schema type. Nullable types are unwrapped, enum types are converted
        to a string type with an enum keyword listing the enum names, and
        array types are converted to an array type with an items keyword.
        Unknown types fall back to the type string.

    .PARAMETER Type
        The .NET type to convert.

    .EXAMPLE
        ConvertTo-JsonSchemaTypeDefinition -Type ([System.Boolean])

        Returns an ordered dictionary with the key type set to 'boolean'.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary]
#>
function ConvertTo-JsonSchemaTypeDefinition
{
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Type]
        $Type
    )

    $underlyingType = [System.Nullable]::GetUnderlyingType($Type)

    if ($underlyingType)
    {
        $Type = $underlyingType
    }

    if ($Type.IsEnum)
    {
        return ([ordered] @{
            type = 'string'
            enum = [System.String[]] ([System.Enum]::GetNames($Type))
        })
    }

    if ($Type.IsArray)
    {
        return ([ordered] @{
            type  = 'array'
            items = (ConvertTo-JsonSchemaTypeDefinition -Type $Type.GetElementType())
        })
    }

    $typeDefinition = switch ($Type.FullName)
    {
        'System.String'
        {
            [ordered] @{
                type = 'string'
            }
        }

        'System.Boolean'
        {
            [ordered] @{
                type = 'boolean'
            }
        }

        { $_ -in @('System.Byte', 'System.SByte', 'System.Int16', 'System.UInt16', 'System.Int32', 'System.UInt32', 'System.Int64', 'System.UInt64') }
        {
            [ordered] @{
                type = 'integer'
            }
        }

        { $_ -in @('System.Single', 'System.Double', 'System.Decimal') }
        {
            [ordered] @{
                type = 'number'
            }
        }

        'System.DateTime'
        {
            [ordered] @{
                type   = 'string'
                format = 'date-time'
            }
        }

        'System.Collections.Hashtable'
        {
            [ordered] @{
                type = 'object'
            }
        }

        default
        {
            # Default to string for unknown types.
            [ordered] @{
                type = 'string'
            }
        }
    }

    return $typeDefinition
}
