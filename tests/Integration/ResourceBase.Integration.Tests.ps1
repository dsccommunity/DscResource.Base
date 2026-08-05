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
                & "$PSScriptRoot/../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }

    $script:skipDscExe = -not [System.Boolean] (Get-Command -Name 'dsc' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
}

BeforeAll {
    $script:originalPSModulePath = $env:PSModulePath

    # Make the fixture module and the built module discoverable, also for child processes (dsc.exe).
    $script:fixturePath = Join-Path -Path $PSScriptRoot -ChildPath 'Fixtures'
    $env:PSModulePath = '{0}{1}{2}' -f $script:fixturePath, [System.IO.Path]::PathSeparator, $env:PSModulePath

    Import-Module -Name 'DscResourceBaseTestResource' -Force -ErrorAction 'Stop'

    $script:fixtureModule = Get-Module -Name 'DscResourceBaseTestResource'
    $script:resourceType = & $script:fixtureModule { [DscBaseTestResource] }
}

AfterAll {
    Get-Module -Name 'DscResourceBaseTestResource' -All | Remove-Module -Force

    $env:PSModulePath = $script:originalPSModulePath
}

Describe 'ResourceBase' {
    Context 'When using the Microsoft DSC static method Get()' {
        It 'Should return the current state of an existing instance' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance1'

            $getResult = $script:resourceType::Get($instance)

            $getResult.Name | Should -Be 'Instance1'
            $getResult.Value | Should -Be 'Value1'
            $getResult._exist | Should -BeTrue
        }

        It 'Should return _exist as $false for an instance that does not exist' {
            $instance = $script:resourceType::new()
            $instance.Name = 'MissingInstance'

            $getResult = $script:resourceType::Get($instance)

            $getResult.Name | Should -Be 'MissingInstance'
            $getResult._exist | Should -BeFalse
        }
    }

    Context 'When using the Microsoft DSC static method Test()' {
        It 'Should return a tuple with $true when the instance is in the desired state' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance1'
            $instance.Value = 'Value1'

            $testResult = $script:resourceType::Test($instance)

            $testResult.Item1 | Should -BeTrue
            $testResult.Item2.GetType().Name | Should -Be 'DscBaseTestResource'
            $testResult.Item3 | Should -HaveCount 0
        }

        It 'Should return a tuple with the differing properties when the instance is not in the desired state' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance1'
            $instance.Value = 'NewValue1'

            $testResult = $script:resourceType::Test($instance)

            $testResult.Item1 | Should -BeFalse
            $testResult.Item3 | Should -Contain 'Value'
        }
    }

    Context 'When using the Microsoft DSC static method Export()' {
        It 'Should return every instance' {
            $exportResult = $script:resourceType::Export()

            $exportResult | Should -HaveCount 2
            $exportResult[0].Name | Should -Be 'Instance1'
            $exportResult[1].Name | Should -Be 'Instance2'
        }

        It 'Should return only the matching instances when passing a filtering instance' {
            $filteringInstance = $script:resourceType::new()
            $filteringInstance.Name = 'Instance2'

            $exportResult = $script:resourceType::Export($filteringInstance)

            $exportResult | Should -HaveCount 1
            $exportResult[0].Name | Should -Be 'Instance2'
            $exportResult[0].Value | Should -Be 'Value2'
        }
    }

    Context 'When using the Microsoft DSC static method Set()' {
        It 'Should return the predicted state without modifying anything in what-if mode' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance2'
            $instance.Value = 'NewValue2'

            $setResult = $script:resourceType::Set($instance, $true)

            $setResult.Item1.Value | Should -Be 'NewValue2'
            $setResult.Item2 | Should -Contain 'Value'

            # The system (in-memory store) must not have been modified.
            $verifyInstance = $script:resourceType::new()
            $verifyInstance.Name = 'Instance2'

            $script:resourceType::Get($verifyInstance).Value | Should -Be 'Value2'
        }

        It 'Should enforce the desired state and return the state after the modification' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance2'
            $instance.Value = 'NewValue2'

            $setResult = $script:resourceType::Set($instance)

            $setResult.Item1.Value | Should -Be 'NewValue2'
            $setResult.Item2 | Should -Contain 'Value'

            $verifyInstance = $script:resourceType::new()
            $verifyInstance.Name = 'Instance2'

            $script:resourceType::Get($verifyInstance).Value | Should -Be 'NewValue2'
        }
    }

    Context 'When using the Microsoft DSC static method Delete()' {
        It 'Should delete the instance' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance1'

            $script:resourceType::Delete($instance)

            $verifyInstance = $script:resourceType::new()
            $verifyInstance.Name = 'Instance1'

            $script:resourceType::Get($verifyInstance)._exist | Should -BeFalse

            $script:resourceType::Export() | Should -HaveCount 1
        }
    }

    Context 'When using the Microsoft DSC static method InstanceJsonSchema()' {
        It 'Should return a valid JSON schema for the resource' {
            $schemaJson = $script:resourceType::InstanceJsonSchema()

            $schema = $schemaJson | ConvertFrom-Json -ErrorAction 'Stop'

            $schema.title | Should -Be 'DscBaseTestResource'
            $schema.required | Should -Contain 'Name'
            $schema.properties.Name.type | Should -Be 'string'
            $schema.properties.Value.type | Should -Be 'string'
            $schema.properties._exist.type | Should -Be 'boolean'
            $schema.properties.Reasons.readOnly | Should -BeTrue
        }
    }

    Context 'When using the Microsoft DSC instance methods' {
        It 'Should support Get(), Test() and Set()' {
            $instance = $script:resourceType::new()
            $instance.Name = 'Instance2'
            $instance.Value = 'NewValue2'

            $instance.Test() | Should -BeTrue

            $getResult = $instance.Get()

            $getResult.Value | Should -Be 'NewValue2'
            $getResult.Reasons | Should -HaveCount 0
        }
    }
}

Describe 'ResourceBase with dsc.exe' -Tag 'RequiresDsc' -Skip:$script:skipDscExe {
    Context 'When invoking operations through the DSC PowerShell adapter' {
        It 'Should return the current state for the get operation' {
            $result = dsc resource get --resource 'DscResourceBaseTestResource/DscBaseTestResource' --input '{"Name":"Instance1"}' 2> $null |
                ConvertFrom-Json

            $LASTEXITCODE | Should -Be 0
            $result.actualState.Name | Should -Be 'Instance1'
            $result.actualState.Value | Should -Be 'Value1'
        }

        It 'Should return inDesiredState as $false for the test operation with a differing value' {
            $result = dsc resource test --resource 'DscResourceBaseTestResource/DscBaseTestResource' --input '{"Name":"Instance1","Value":"OtherValue"}' 2> $null |
                ConvertFrom-Json

            $LASTEXITCODE | Should -Be 0
            $result.inDesiredState | Should -BeFalse
            $result.differingProperties | Should -Contain 'Value'
        }

        It 'Should return every instance for the export operation' {
            $result = dsc resource export --resource 'DscResourceBaseTestResource/DscBaseTestResource' 2> $null |
                ConvertFrom-Json

            $LASTEXITCODE | Should -Be 0
            $result.resources | Should -HaveCount 2
        }
    }
}
