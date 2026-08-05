<#
    .SYNOPSIS
        Converts a class-based DSC resource type to a JSON schema.

    .DESCRIPTION
        Converts a class-based DSC resource type to a JSON schema that describes
        an instance of the resource. The schema is built at runtime using
        reflection over the properties that have the attribute DscProperty,
        including properties inherited from base classes in other modules.

    .PARAMETER ResourceType
        The type of the class-based DSC resource.

    .EXAMPLE
        ConvertTo-DscResourceJsonSchema -ResourceType [MyResource]

        Returns a JSON string with the schema describing an instance of the
        class-based DSC resource MyResource.

    .OUTPUTS
        [System.String]
#>
function ConvertTo-DscResourceJsonSchema
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Type]
        $ResourceType
    )

    $schemaProperties = [ordered] @{}
    $requiredList = [System.Collections.Generic.List[System.String]]::new()

    $bindingFlags = [System.Reflection.BindingFlags] 'Public, Instance'

    foreach ($property in $ResourceType.GetProperties($bindingFlags))
    {
        $dscPropertyAttribute = $property.GetCustomAttributes([System.Management.Automation.DscPropertyAttribute], $true) |
            Select-Object -First 1

        if (-not $dscPropertyAttribute)
        {
            continue
        }

        $schemaProperty = [ordered] @{}

        $validateSetAttribute = $property.GetCustomAttributes([System.Management.Automation.ValidateSetAttribute], $true) |
            Select-Object -First 1

        if ($validateSetAttribute)
        {
            $schemaProperty['type'] = 'string'
            $schemaProperty['enum'] = [System.String[]] $validateSetAttribute.ValidValues
        }
        else
        {
            $jsonType = ConvertTo-JsonSchemaTypeDefinition -Type $property.PropertyType

            foreach ($key in $jsonType.Keys)
            {
                $schemaProperty[$key] = $jsonType[$key]
            }
        }

        $schemaProperty['title'] = $property.Name

        if (-not $schemaProperty.Contains('enum'))
        {
            $validatePatternAttribute = $property.GetCustomAttributes([System.Management.Automation.ValidatePatternAttribute], $true) |
                Select-Object -First 1

            if ($validatePatternAttribute)
            {
                $schemaProperty['pattern'] = $validatePatternAttribute.RegexPattern
            }
        }

        if ($dscPropertyAttribute.NotConfigurable)
        {
            $schemaProperty['readOnly'] = $true
        }

        $schemaProperty['description'] = 'The {0} property.' -f $property.Name

        $schemaProperties[$property.Name] = $schemaProperty

        if ($dscPropertyAttribute.Key -or $dscPropertyAttribute.Mandatory)
        {
            $requiredList.Add($property.Name)
        }
    }

    $schema = [ordered] @{
        '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
        title                = $ResourceType.Name
        type                 = 'object'
        required             = @($requiredList)
        additionalProperties = $false
        properties           = $schemaProperties
    }

    return ($schema | ConvertTo-Json -Depth 10)
}
