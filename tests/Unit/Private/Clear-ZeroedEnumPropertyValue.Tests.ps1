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

Describe 'Clear-ZeroedEnumPropertyValue' -Tag 'Private' {
    Context 'When the hashtable does not contain zeroed Enum properties' {
        Context 'When input is passed as a named variable' {
            It 'Should return the same amount of values' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    $testParams = @{
                        Variable1 = 'SomeString'
                        Variable2 = [System.Int32] 10
                        Variable3 = $true
                        Variable4 = New-TimeSpan -Days 8
                    }

                    $result = Clear-ZeroedEnumPropertyValue -InputObject $testParams

                    $result.Count | Should -Be $testParams.Count
                }
            }
        }

        Context 'When input is passed via pipeline' {
            It 'Should return the same amount of values' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    $testParams = @{
                        Variable1 = 'SomeString'
                        Variable2 = [System.Int32] 10
                        Variable3 = $true
                        Variable4 = New-TimeSpan -Days 8
                    }

                    $result = $testParams | Clear-ZeroedEnumPropertyValue

                    $result.Count | Should -Be $testParams.Count
                }
            }
        }
    }

    Context 'When the hashtable does contain zeroed Enum properties' {
        Context 'When input is passed as a named variable' {
            It 'Should return the same amount of values' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    enum MyMockEnum
                    {
                        Value1 = 1
                        Value2
                        Value3
                        Value4
                        Value5
                    }

                    $testParams = @{
                        Variable1 = 'SomeString'
                        Variable2 = [System.Int32] 10
                        Variable3 = $true
                        Variable4 = New-TimeSpan -Days 8
                        Variable5 = [MyMockEnum]::Value1
                        Variable6 = [MyMockEnum]::new()
                        Variable7 = [MyMockEnum]::Value3
                        Variable8 = [MyMockEnum]::new()
                    }

                    $result = Clear-ZeroedEnumPropertyValue -InputObject $testParams

                    $result.Count | Should -Be ($testParams.Count - 2)
                }
            }
        }

        Context 'When input is passed via pipeline' {
            It 'Should return the same amount of values' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    enum MyMockEnum
                    {
                        Value1 = 1
                        Value2
                        Value3
                        Value4
                        Value5
                    }

                    $testParams = @{
                        Variable1 = 'SomeString'
                        Variable2 = [System.Int32] 10
                        Variable3 = $true
                        Variable4 = New-TimeSpan -Days 8
                        Variable5 = [MyMockEnum]::Value1
                        Variable6 = [MyMockEnum]::new()
                        Variable7 = [MyMockEnum]::Value3
                        Variable8 = [MyMockEnum]::new()
                    }

                    $result = $testParams | Clear-ZeroedEnumPropertyValue

                    $result.Count | Should -Be ($testParams.Count - 2)
                }
            }
        }
    }
}
