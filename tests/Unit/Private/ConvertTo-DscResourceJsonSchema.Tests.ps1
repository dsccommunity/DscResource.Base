[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'DscResource.Base'

    Import-Module -Name $script:dscModuleName

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'ConvertTo-DscResourceJsonSchema' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }

        <#
            Must use a here-string because we need to pass 'using' which must be
            first in a scriptblock, but if it is outside the here-string then
            PowerShell will fail to parse the test script.
        #>
        $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockIntermediateResource : ResourceBase
{
    [DscProperty()]
    [System.String]
    $MyInheritedProperty
}

class MyMockResource : MyMockIntermediateResource
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty(Mandatory)]
    [System.String]
    $MyMandatoryProperty

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty()]
    [ValidateSet('Value1', 'Value2')]
    [System.String]
    $MyValidateSetProperty

    [DscProperty()]
    [ValidatePattern('^[a-z]+$')]
    [System.String]
    $MyValidatePatternProperty

    [DscProperty()]
    [System.String[]]
    $MyArrayProperty

    [DscProperty()]
    [Nullable[System.Int32]]
    $MyNullableProperty

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    # This property must not be part of the schema.
    [System.String]
    $MyNonDscProperty

    MyMockResource () {}
}

$script:mockResourceBaseType = [MyMockResource]
'@

        InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
    }

    It 'Should return a valid JSON string' {
        InModuleScope -ScriptBlock {
            $schemaJson = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType

            { $schemaJson | ConvertFrom-Json -ErrorAction 'Stop' } | Should -Not -Throw
        }
    }

    It 'Should return the correct schema document keywords' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
            $schema.title | Should -Be 'MyMockResource'
            $schema.type | Should -Be 'object'
            $schema.additionalProperties | Should -BeFalse
        }
    }

    It 'Should add key and mandatory properties to the required keyword' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.required | Should -Contain 'MyResourceKeyProperty1'
            $schema.required | Should -Contain 'MyMandatoryProperty'
            $schema.required | Should -Not -Contain 'Ensure'
        }
    }

    It 'Should convert an enum property to a string with an enum keyword' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.Ensure.type | Should -Be 'string'
            $schema.properties.Ensure.enum | Should -Contain 'Present'
            $schema.properties.Ensure.enum | Should -Contain 'Absent'
        }
    }

    It 'Should convert the canonical DSC property _exist to a boolean' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties._exist.type | Should -Be 'boolean'
        }
    }

    It 'Should convert a property with ValidateSet to a string with an enum keyword' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyValidateSetProperty.type | Should -Be 'string'
            $schema.properties.MyValidateSetProperty.enum | Should -Contain 'Value1'
            $schema.properties.MyValidateSetProperty.enum | Should -Contain 'Value2'
        }
    }

    It 'Should convert a property with ValidatePattern to a string with a pattern keyword' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyValidatePatternProperty.type | Should -Be 'string'
            $schema.properties.MyValidatePatternProperty.pattern | Should -Be '^[a-z]+$'
        }
    }

    It 'Should convert an array property to an array with an items keyword' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyArrayProperty.type | Should -Be 'array'
            $schema.properties.MyArrayProperty.items.type | Should -Be 'string'
        }
    }

    It 'Should convert a nullable property to the underlying type' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyNullableProperty.type | Should -Be 'integer'
        }
    }

    It 'Should convert a not configurable property to a read-only property' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.Reasons.type | Should -Be 'array'
            $schema.properties.Reasons.readOnly | Should -BeTrue
        }
    }

    It 'Should include properties inherited from a base class' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyInheritedProperty.type | Should -Be 'string'
        }
    }

    It 'Should not include properties without the DscProperty attribute' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.PSObject.Properties.Name | Should -Not -Contain 'MyNonDscProperty'
        }
    }

    It 'Should set a default description for each property' {
        InModuleScope -ScriptBlock {
            $schema = ConvertTo-DscResourceJsonSchema -ResourceType $mockResourceBaseType | ConvertFrom-Json

            $schema.properties.MyResourceKeyProperty1.description | Should -Be 'The MyResourceKeyProperty1 property.'
        }
    }
}
