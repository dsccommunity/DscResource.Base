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

Describe 'ConvertTo-JsonSchemaTypeDefinition' -Tag 'Private' {
    Context 'When converting simple types' {
        It 'Should convert the type <TypeName> to the JSON schema type <ExpectedType>' -ForEach @(
            @{ TypeName = [System.String]; ExpectedType = 'string' }
            @{ TypeName = [System.Boolean]; ExpectedType = 'boolean' }
            @{ TypeName = [System.Byte]; ExpectedType = 'integer' }
            @{ TypeName = [System.Int16]; ExpectedType = 'integer' }
            @{ TypeName = [System.Int32]; ExpectedType = 'integer' }
            @{ TypeName = [System.Int64]; ExpectedType = 'integer' }
            @{ TypeName = [System.UInt32]; ExpectedType = 'integer' }
            @{ TypeName = [System.Single]; ExpectedType = 'number' }
            @{ TypeName = [System.Double]; ExpectedType = 'number' }
            @{ TypeName = [System.Decimal]; ExpectedType = 'number' }
            @{ TypeName = [System.Collections.Hashtable]; ExpectedType = 'object' }
        ) {
            InModuleScope -Parameters $_ -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type $TypeName

                $result.type | Should -Be $ExpectedType
            }
        }
    }

    Context 'When converting the type DateTime' {
        It 'Should convert to a string with the format date-time' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([System.DateTime])

                $result.type | Should -Be 'string'
                $result.format | Should -Be 'date-time'
            }
        }
    }

    Context 'When converting an enum type' {
        It 'Should convert to a string with an enum keyword' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([Ensure])

                $result.type | Should -Be 'string'
                $result.enum | Should -Contain 'Present'
                $result.enum | Should -Contain 'Absent'
            }
        }
    }

    Context 'When converting an array type' {
        It 'Should convert to an array with an items keyword' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([System.String[]])

                $result.type | Should -Be 'array'
                $result.items.type | Should -Be 'string'
            }
        }

        It 'Should convert the element type of the array' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([System.Collections.Hashtable[]])

                $result.type | Should -Be 'array'
                $result.items.type | Should -Be 'object'
            }
        }
    }

    Context 'When converting a nullable type' {
        It 'Should convert to the underlying type' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([System.Nullable[System.Int32]])

                $result.type | Should -Be 'integer'
            }
        }
    }

    Context 'When converting an unknown type' {
        It 'Should fall back to the type string' {
            InModuleScope -ScriptBlock {
                $result = ConvertTo-JsonSchemaTypeDefinition -Type ([System.Guid])

                $result.type | Should -Be 'string'
            }
        }
    }
}
