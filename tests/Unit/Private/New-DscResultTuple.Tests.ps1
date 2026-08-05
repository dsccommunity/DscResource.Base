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

Describe 'New-DscResultTuple' -Tag 'Private' {
    Context 'When creating a tuple with two elements' {
        It 'Should return a tuple closed over the correct types' {
            InModuleScope -ScriptBlock {
                $result = New-DscResultTuple -Type @([System.String], [System.String[]]) -Value @('MyValue', [System.String[]] @('MyProperty'))

                $genericArguments = $result.GetType().GetGenericArguments()

                $genericArguments | Should -HaveCount 2
                $genericArguments[0].Name | Should -Be 'String'
                $genericArguments[1].Name | Should -Be 'String[]'

                $result.Item1 | Should -Be 'MyValue'
                $result.Item2 | Should -Contain 'MyProperty'
            }
        }
    }

    Context 'When creating a tuple with three elements' {
        It 'Should return a tuple closed over the correct types' {
            InModuleScope -ScriptBlock {
                $result = New-DscResultTuple -Type @([System.Boolean], [System.String], [System.String[]]) -Value @($true, 'MyValue', [System.String[]] @())

                $genericArguments = $result.GetType().GetGenericArguments()

                $genericArguments | Should -HaveCount 3
                $genericArguments[0].Name | Should -Be 'Boolean'
                $genericArguments[1].Name | Should -Be 'String'
                $genericArguments[2].Name | Should -Be 'String[]'

                $result.Item1 | Should -BeTrue
                $result.Item3 | Should -HaveCount 0
            }
        }
    }

    Context 'When creating a tuple closed over a class type' {
        It 'Should return a tuple closed over the class type' {
            InModuleScope -ScriptBlock {
                $instance = [ResourceBase]::new()

                $result = New-DscResultTuple -Type @([System.Boolean], $instance.GetType(), [System.String[]]) -Value @($false, $instance, [System.String[]] @('MyProperty'))

                $result.GetType().GetGenericArguments()[1].Name | Should -Be 'ResourceBase'
                $result.Item2 | Should -Be $instance
            }
        }
    }

    Context 'When an element value is null' {
        It 'Should return a tuple with the null element' {
            InModuleScope -ScriptBlock {
                $result = New-DscResultTuple -Type @([System.String], [System.String[]]) -Value @($null, [System.String[]] @())

                $result.Item1 | Should -BeNullOrEmpty
                $result.GetType().GetGenericArguments()[0].Name | Should -Be 'String'
            }
        }
    }

    Context 'When the number of types does not match the number of values' {
        It 'Should throw the correct error' {
            InModuleScope -ScriptBlock {
                { New-DscResultTuple -Type @([System.String]) -Value @('MyValue', 'MySecondValue') } |
                    Should -Throw -ExpectedMessage '*does not match the number of values*'
            }
        }
    }
}
