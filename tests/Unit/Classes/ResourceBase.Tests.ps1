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

Describe 'ResourceBase' {
    Context 'When class is instantiated' {
        It 'Should not throw an exception' {
            InModuleScope -ScriptBlock {
                { [ResourceBase]::new() } | Should -Not -Throw
            }
        }

        It 'Should have a default or empty constructor' {
            InModuleScope -ScriptBlock {
                $instance = [ResourceBase]::new()
                $instance | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should have a constructor that takes one string argument' {
            InModuleScope -ScriptBlock {
                $instance = [ResourceBase]::new($TestDrive)
                $instance | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should be the correct type' {
            InModuleScope -ScriptBlock {
                $instance = [ResourceBase]::new()
                $instance.GetType().Name | Should -Be 'ResourceBase'
            }
        }
    }
}

Describe 'ResourceBase\GetCurrentState()' -Tag 'GetCurrentState' {
    Context 'When the required methods are not overridden' {
        BeforeAll {
            $mockResourceBaseInstance = InModuleScope -ScriptBlock {
                [ResourceBase]::new()
            }
        }

        Context 'When there is no override for the method GetCurrentState' {
            It 'Should throw the correct error' {
                { $mockResourceBaseInstance.GetCurrentState(@{}) } | Should -Throw $mockResourceBaseInstance.GetCurrentStateMethodNotImplemented
            }
        }
    }
}

Describe 'ResourceBase\Modify()' -Tag 'Modify' {
    Context 'When the required methods are not overridden' {
        BeforeAll {
            $mockResourceBaseInstance = InModuleScope -ScriptBlock {
                [ResourceBase]::new()
            }
        }


        Context 'When there is no override for the method Modify' {
            It 'Should throw the correct error' {
                { $mockResourceBaseInstance.Modify(@{}) } | Should -Throw $mockResourceBaseInstance.ModifyMethodNotImplemented
            }
        }
    }
}

Describe 'ResourceBase\AssertProperties()' -Tag 'AssertProperties' {
    BeforeAll {
        $mockResourceBaseInstance = InModuleScope -ScriptBlock {
            [ResourceBase]::new()
        }
    }

    It 'Should not throw' {
        $mockDesiredState = @{
            MyProperty1 = 'MyValue1'
        }

        { $mockResourceBaseInstance.AssertProperties($mockDesiredState) } | Should -Not -Throw
    }
}

Describe 'ResourceBase\NormalizeProperties()' -Tag 'NormalizeProperties' {
    BeforeAll {
        $mockResourceBaseInstance = InModuleScope -ScriptBlock {
            [ResourceBase]::new()
        }
    }

    It 'Should not throw' {
        $mockDesiredState = @{
            MyProperty1 = 'MyValue1'
        }

        { $mockResourceBaseInstance.NormalizeProperties($mockDesiredState) } | Should -Not -Throw
    }
}

Describe 'ResourceBase\Assert()' -Tag 'Assert' {
    Context 'When the system is in the desired state' {
        BeforeAll {
            Mock -CommandName Get-ClassName -MockWith {
                # Only return localized strings for this class name.
                @('ResourceBase')
            }

            $inModuleScopeScriptBlock = @'
using module DscResource.Base

enum MyMockEnum {
Value1 = 1
Value2
Value3
Value4
}

class MyMockResource : ResourceBase
{
[DscProperty(Key)]
[System.String]
$MyResourceKeyProperty1

[DscProperty()]
[System.String]
$MyResourceProperty2

[DscProperty()]
[MyMockEnum]
$MyResourceProperty3

[DscProperty()]
[MyMockEnum]
$MyResourceProperty4 = [MyMockEnum]::Value4

[DscProperty(NotConfigurable)]
[System.String]
$MyResourceReadProperty

MyMockResource () {}

[ResourceBase] Get()
{
    # Creates a new instance of the mock instance MyMockResource.
    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())

    $currentStateInstance.MyResourceProperty2 = 'MyValue1'
    $currentStateInstance.MyResourceProperty4 = [MyMockEnum]::Value4
    $currentStateInstance.MyResourceReadProperty = 'MyReadValue1'

    return $currentStateInstance
}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        Context 'When the method is called' {
            BeforeAll {
                InModuleScope -ScriptBlock {
                    $script:assertPropertiesMethodCount = 0

                    $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'AssertProperties' -Value {
                        return $script:assertPropertiesMethodCount++
                    } -Force
                }
            }
            It 'Should execute the correct method' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance.Assert()

                    $script:assertPropertiesMethodCount | Should -Be 1
                }
            }
        }
    }
}

Describe 'ResourceBase\Normalize()' -Tag 'Normalize' {
    Context 'When the system is in the desired state' {
        BeforeAll {
            Mock -CommandName Get-ClassName -MockWith {
                # Only return localized strings for this class name.
                @('ResourceBase')
            }

            $inModuleScopeScriptBlock = @'
using module DscResource.Base

enum MyMockEnum {
Value1 = 1
Value2
Value3
Value4
}

class MyMockResource : ResourceBase
{
[DscProperty(Key)]
[System.String]
$MyResourceKeyProperty1

[DscProperty()]
[System.String]
$MyResourceProperty2

[DscProperty()]
[MyMockEnum]
$MyResourceProperty3

[DscProperty()]
[MyMockEnum]
$MyResourceProperty4 = [MyMockEnum]::Value4

[DscProperty(NotConfigurable)]
[System.String]
$MyResourceReadProperty

MyMockResource () {}

[ResourceBase] Get()
{
    # Creates a new instance of the mock instance MyMockResource.
    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())

    $currentStateInstance.MyResourceProperty2 = 'MyValue1'
    $currentStateInstance.MyResourceProperty4 = [MyMockEnum]::Value4
    $currentStateInstance.MyResourceReadProperty = 'MyReadValue1'

    return $currentStateInstance
}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        Context 'When the method is called' {
            BeforeAll {
                InModuleScope -ScriptBlock {
                    $script:normalizePropertiesMethodCount = 0

                    $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'NormalizeProperties' -Value {
                        return $script:normalizePropertiesMethodCount++
                    } -Force
                }
            }
            It 'Should execute the correct method' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance.Normalize()

                    $script:normalizePropertiesMethodCount | Should -Be 1
                }
            }
        }
    }
}

Describe 'ResourceBase\Get()' -Tag 'Get' {
    Context 'When the system is in the desired state' {
        Context 'When the object should be Present' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    <#
        This will test so that a key value do not need to be enforced, and still
        be returned by Get().
    #>
    MyMockResource() : base ()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'MyResourceKeyProperty1'
        )
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        <#
            This does not return the key property that is not being enforce, to let
            the base class' method Get() return that value.
        #>
        return @{
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            }

            It 'Should have correctly instantiated the resource class' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                    $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                }
            }

            It 'Should return the correct values for the properties' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'
                    $mockResourceBaseInstance.MyResourceProperty2 = 'MyValue2'

                    $getResult = $mockResourceBaseInstance.Get()

                    $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                    $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                    $getResult.Ensure | Should -Be ([Ensure]::Present)

                    Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]
                    $getResult.Reasons | Should -BeNullOrEmpty
                }
            }
        }

        Context 'When the object should be Absent' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    <#
        Tests to enforce a key property even if we do not return the key property value
        from the method GetCurrentState.
    #>
    MyMockResource() : base ()
    {
        # Test not to add the key property to the list of properties that are not enforced.
        $this.ExcludeDscProperties = @('MyResourceKeyProperty1')
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            MyResourceProperty2 = $null
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            }

            It 'Should have correctly instantiated the resource class' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                    $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                }
            }

            It 'Should return the correct values for the properties' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance.Ensure = [Ensure]::Absent
                    $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                    $getResult = $mockResourceBaseInstance.Get()

                    $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                    $getResult.MyResourceProperty2 | Should -BeNullOrEmpty
                    $getResult.Ensure | Should -Be ([Ensure]::Absent)

                    Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]
                    $getResult.Reasons | Should -BeNullOrEmpty
                }
            }
        }

        Context 'When returning Ensure property from method GetCurrentState()' {
            Context 'When the configuration should be present' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            Ensure = [Ensure]::Present
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'
                        $mockResourceBaseInstance.MyResourceProperty2 = 'MyValue2'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                        $getResult.Ensure | Should -Be ([Ensure]::Present)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]
                        $getResult.Reasons | Should -BeNullOrEmpty
                    }
                }
            }

            Context 'When the configuration should be absent' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            Ensure = [Ensure]::Absent
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = $null
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.Ensure = [Ensure]::Absent
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.MyResourceProperty2 | Should -BeNullOrEmpty
                        $getResult.Ensure | Should -Be ([Ensure]::Absent)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]
                        $getResult.Reasons | Should -BeNullOrEmpty
                    }
                }
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            Mock -CommandName Get-ClassName -MockWith {
                # Only return localized strings for this class name.
                @('ResourceBase')
            }
        }

        Context 'When the configuration should be present' {
            Context 'When a non-mandatory parameter is not in desired state' {
                BeforeAll {
                    <#
                        Must use a here-string because we need to pass 'using' which must be
                        first in a scriptblock, but if it is outside the here-string then
                        PowerShell will fail to parse the test script.
                    #>
                    $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    MyMockResource() : base ()
    {
        # Test not to add the key property to the list of properties that are not enforced.
        $this.ExcludeDscProperties = @('MyResourceKeyProperty1')
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'
                        $mockResourceBaseInstance.MyResourceProperty2 = 'NewValue2'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                        $getResult.Ensure | Should -Be ([Ensure]::Present)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]

                        $getResult.Reasons | Should -HaveCount 1
                        $getResult.Reasons[0].Code | Should -Be 'MyMockResource:MyMockResource:MyResourceProperty2'
                        $getResult.Reasons[0].Phrase | Should -Be 'The property MyResourceProperty2 should be "NewValue2", but was "MyValue2"'
                    }
                }
            }

            Context 'When the object should be Present' {
                BeforeAll {
                    <#
                        Must use a here-string because we need to pass 'using' which must be
                        first in a scriptblock, but if it is outside the here-string then
                        PowerShell will fail to parse the test script.
                    #>
                    $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    MyMockResource() : base ()
    {
        # Test not to add the key property to the list of properties that are not enforced.
        $this.ExcludeDscProperties = @('MyResourceKeyProperty1')
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.Ensure | Should -Be ([Ensure]::Absent)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]

                        $getResult.Reasons | Should -HaveCount 1
                        $getResult.Reasons[0].Code | Should -Be 'MyMockResource:MyMockResource:Ensure'
                        $getResult.Reasons[0].Phrase | Should -Be 'The property Ensure should be "Present", but was "Absent"'
                    }
                }
            }
        }

        Context 'When the object should be Absent' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    MyMockResource() : base ()
    {
        # Test not to add the key property to the list of properties that are not enforced.
        $this.ExcludeDscProperties = @('MyResourceKeyProperty1')
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            }

            It 'Should have correctly instantiated the resource class' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                    $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                }
            }

            It 'Should return the correct values for the properties' {
                InModuleScope -ScriptBlock {
                    $mockResourceBaseInstance.Ensure = [Ensure]::Absent
                    $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                    $getResult = $mockResourceBaseInstance.Get()

                    $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                    $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                    $getResult.Ensure | Should -Be ([Ensure]::Present)

                    Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]

                    $getResult.Reasons | Should -HaveCount 1
                    $getResult.Reasons[0].Code | Should -Be 'MyMockResource:MyMockResource:Ensure'
                    $getResult.Reasons[0].Phrase | Should -Be 'The property Ensure should be "Absent", but was "Present"'
                }
            }
        }

        Context 'When returning Ensure property from method GetCurrentState()' {
            Context 'When the configuration should be present' {
                BeforeAll {
                    <#
                        Must use a here-string because we need to pass 'using' which must be
                        first in a scriptblock, but if it is outside the here-string then
                        PowerShell will fail to parse the test script.
                    #>
                    $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = ([Ensure]::Present)

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            Ensure = ([Ensure]::Absent)
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'
                        $mockResourceBaseInstance.MyResourceProperty2 = 'NewValue2'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                        $getResult.Ensure | Should -Be ([Ensure]::Absent)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]

                        $getResult.Reasons | Should -HaveCount 2

                        # The order in the array was sometimes different so could not use array index ($getResult.Reasons[0]).
                        $getResult.Reasons.Code | Should -Contain 'MyMockResource:MyMockResource:MyResourceProperty2'
                        $getResult.Reasons.Code | Should -Contain 'MyMockResource:MyMockResource:Ensure'
                        $getResult.Reasons.Phrase | Should -Contain 'The property MyResourceProperty2 should be "NewValue2", but was "MyValue2"'
                        $getResult.Reasons.Phrase | Should -Contain 'The property Ensure should be "Present", but was "Absent"'
                    }
                }
            }

            Context 'When the configuration should be absent' {
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

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            Ensure = [Ensure]::Present
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

                    InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
                }

                It 'Should have correctly instantiated the resource class' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                        $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
                    }
                }

                It 'Should return the correct values for the properties' {
                    InModuleScope -ScriptBlock {
                        $mockResourceBaseInstance.Ensure = [Ensure]::Absent
                        $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                        $getResult = $mockResourceBaseInstance.Get()

                        $getResult.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                        $getResult.MyResourceProperty2 | Should -Be 'MyValue2'
                        $getResult.Ensure | Should -Be ([Ensure]::Present)

                        Should -ActualValue $getResult.Reasons -HaveType [System.Collections.Hashtable[]]

                        $getResult.Reasons | Should -HaveCount 1

                        $getResult.Reasons[0].Code | Should -Be 'MyMockResource:MyMockResource:Ensure'
                        $getResult.Reasons[0].Phrase | Should -Be 'The property Ensure should be "Absent", but was "Present"'
                    }
                }
            }
        }
    }
}

Describe 'ResourceBase\Test()' -Tag 'Test' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When the system is in the desired state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++
                } -Force
            }
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.Test() | Should -BeTrue
                $script:getMethodCallCount | Should -Be 1
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++
                } -Force

                $mockResourceBaseInstance.PropertiesNotInDesiredState = @(
                    @{
                        Property      = 'MyResourceProperty2'
                        ExpectedValue = 'MyValue1'
                        ActualValue   = 'MyValue'
                    }
                )
            }
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.Test() | Should -BeFalse
                $script:getMethodCallCount | Should -Be 1
            }
        }
    }
}

Describe 'ResourceBase\Set()' -Tag 'Set' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When the system is in the desired state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty()]
    [System.String]
    $MyResourceProperty3

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:testMethodCallCount = 0
                $script:modifyMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Test' -Value {
                    $script:testMethodCallCount++
                    # Test() Passed
                    return $true
                } -Force -PassThru |
                    Add-Member -MemberType ScriptMethod -Name 'Modify' -Value {
                        $script:modifyMethodCallCount++
                    } -Force
            }
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should not set any property' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.Set()

                $script:testMethodCallCount | Should -Be 1
                $script:modifyMethodCallCount | Should -Be 0
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty()]
    [System.String]
    $MyResourceProperty3

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:testMethodCallCount = 0
                $script:modifyMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Test' -Value {
                    $script:testMethodCallCount++
                    # Test() Failed
                    return $false
                } -Force -PassThru |
                    Add-Member -MemberType ScriptMethod -Name 'Modify' -Value {
                        $script:modifyMethodCallCount++
                    } -Force

                $mockResourceBaseInstance.PropertiesNotInDesiredState = @(
                    @{
                        Property      = 'MyResourceProperty2'
                        ExpectedValue = 'MyNewValue1'
                        ActualValue   = 'MyValue1'
                    }
                )
            }

            Mock -CommandName ConvertFrom-CompareResult -MockWith {
                return @{
                    MyResourceProperty2 = 'MyNewValue1'
                }
            }
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should set the correct property' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.Set()

                $script:testMethodCallCount | Should -Be 1
                $script:modifyMethodCallCount | Should -Be 1
            }
        }
    }
}

Describe 'ResourceBase\GetDesiredState()' -Tag 'GetDesiredState' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When retrieving the desired state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

enum MyMockEnum {
    Value1 = 0
    Value2 = 1
    Value3 = 2
}

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty()]
    [Nullable[System.Int32]]
    $MyResourceProperty3

    [DscProperty()]
    [Nullable[System.Boolean]]
    $MyResourceProperty4

    [DscProperty()]
    [MyMockEnum]
    $MyResourceEnumProperty = [MyMockEnum]::Value1

    [DscProperty(NotConfigurable)]
    [System.String]
    $MyResourceReadProperty

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))

            Mock -CommandName Get-DscProperty
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should call Get-DscProperty with the correct parameters' {
            InModuleScope -ScriptBlock {
                $null = $mockResourceBaseInstance.GetDesiredState()
            }

            Should -Invoke -CommandName Get-DscProperty -ParameterFilter {
                $IgnoreZeroEnumValue -eq $true -and
                $HasValue -eq $true
            } -Exactly -Times 1 -Scope It
        }
    }
}

Describe 'ResourceBase\SetCachedKeyProperties()' -Tag 'SetCachedKeyProperties' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When setting the cached key properties' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

enum MyMockEnum {
    Value1 = 0
    Value2 = 1
    Value3 = 2
}

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty()]
    [Nullable[System.Int32]]
    $MyResourceProperty3

    [DscProperty()]
    [Nullable[System.Boolean]]
    $MyResourceProperty4

    [DscProperty()]
    [MyMockEnum]
    $MyResourceEnumProperty = [MyMockEnum]::Value1

    [DscProperty(NotConfigurable)]
    [System.String]
    $MyResourceReadProperty

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))

            Mock -CommandName Get-DscProperty -MockWith {
                @{
                    MyResourceKeyProperty1 = 'AStringValue'
                }
            }
        }

        It 'Should have correctly instantiated the resource class' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance | Should -Not -BeNullOrEmpty
                $mockResourceBaseInstance.GetType().BaseType.Name | Should -Be 'ResourceBase'
            }
        }

        It 'Should return the correct result' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.SetCachedKeyProperties()

                $mockResourceBaseInstance.CachedKeyProperties.Keys | Should -Contain 'MyResourceKeyProperty1'
            }

            Should -Invoke -CommandName Get-DscProperty -ParameterFilter {
                $Attribute -eq 'Key'
            } -Exactly -Times 1 -Scope It
        }
    }
}

Describe 'ResourceBase\GetTestResult()' -Tag 'GetTestResult' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }

        $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource () {}

    static [System.Tuple[System.Boolean, MyMockResource, System.String[]]] Test([MyMockResource] $instance)
    {
        return $instance.GetTestResult()
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
$script:mockResourceBaseType = [MyMockResource]
'@
    }

    Context 'When the system is in the desired state' {
        BeforeAll {
            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++

                    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())
                    $currentStateInstance.MyResourceKeyProperty1 = 'MyValue1'
                    $currentStateInstance.MyResourceProperty2 = 'MyValue2'

                    return $currentStateInstance
                } -Force
            }
        }

        It 'Should return a tuple closed over the derived class type' {
            InModuleScope -ScriptBlock {
                $testResult = $mockResourceBaseInstance.GetTestResult()

                $genericArguments = $testResult.GetType().GetGenericArguments()

                $genericArguments[0].Name | Should -Be 'Boolean'
                $genericArguments[1].Name | Should -Be 'MyMockResource'
                $genericArguments[2].Name | Should -Be 'String[]'
            }
        }

        It 'Should return the correct tuple values' {
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0

                $testResult = $mockResourceBaseInstance.GetTestResult()

                $testResult.Item1 | Should -BeTrue
                $testResult.Item2.MyResourceProperty2 | Should -Be 'MyValue2'
                $testResult.Item3 | Should -HaveCount 0

                $script:getMethodCallCount | Should -Be 1
            }
        }

        It 'Should return the tuple through the derived class static method Test()' {
            InModuleScope -ScriptBlock {
                $testResult = $mockResourceBaseType::Test($mockResourceBaseInstance)

                $testResult.Item1 | Should -BeTrue
                $testResult.Item2.GetType().Name | Should -Be 'MyMockResource'
                $testResult.Item3 | Should -HaveCount 0
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++

                    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())
                    $currentStateInstance.MyResourceKeyProperty1 = 'MyValue1'
                    $currentStateInstance.MyResourceProperty2 = 'MyValue2'

                    return $currentStateInstance
                } -Force

                $mockResourceBaseInstance.PropertiesNotInDesiredState = @(
                    @{
                        Property      = 'MyResourceProperty2'
                        ExpectedValue = 'MyNewValue2'
                        ActualValue   = 'MyValue2'
                    }
                )
            }
        }

        It 'Should return the correct tuple values' {
            InModuleScope -ScriptBlock {
                $testResult = $mockResourceBaseInstance.GetTestResult()

                $testResult.Item1 | Should -BeFalse
                $testResult.Item3 | Should -HaveCount 1
                $testResult.Item3 | Should -Contain 'MyResourceProperty2'

                $script:getMethodCallCount | Should -Be 1
            }
        }

        It 'Should return the tuple through the derived class static method Test()' {
            InModuleScope -ScriptBlock {
                $testResult = $mockResourceBaseType::Test($mockResourceBaseInstance)

                $testResult.Item1 | Should -BeFalse
                $testResult.Item3 | Should -Contain 'MyResourceProperty2'
            }
        }
    }
}

Describe 'ResourceBase\GetSetResult()' -Tag 'GetSetResult' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }

        $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource () {}

    static [System.Tuple[MyMockResource, System.String[]]] Set([MyMockResource] $instance, [System.Boolean] $whatIf)
    {
        return $instance.GetSetResult($whatIf)
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
$script:mockResourceBaseType = [MyMockResource]
'@
    }

    Context 'When the system is in the desired state' {
        BeforeAll {
            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0
                $script:modifyMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++

                    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())
                    $currentStateInstance.MyResourceKeyProperty1 = 'MyValue1'
                    $currentStateInstance.MyResourceProperty2 = 'MyValue2'

                    return $currentStateInstance
                } -Force -PassThru |
                    Add-Member -MemberType ScriptMethod -Name 'Modify' -Value {
                        $script:modifyMethodCallCount++
                    } -Force
            }
        }

        It 'Should not modify anything and return the current state with no changed properties' {
            InModuleScope -ScriptBlock {
                $setResult = $mockResourceBaseInstance.GetSetResult()

                $setResult.Item1.MyResourceProperty2 | Should -Be 'MyValue2'
                $setResult.Item2 | Should -HaveCount 0

                $script:getMethodCallCount | Should -Be 1
                $script:modifyMethodCallCount | Should -Be 0
            }
        }

        It 'Should return a tuple closed over the derived class type' {
            InModuleScope -ScriptBlock {
                $setResult = $mockResourceBaseInstance.GetSetResult()

                $genericArguments = $setResult.GetType().GetGenericArguments()

                $genericArguments[0].Name | Should -Be 'MyMockResource'
                $genericArguments[1].Name | Should -Be 'String[]'
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            Mock -CommandName ConvertFrom-CompareResult -MockWith {
                return @{
                    MyResourceProperty2 = 'MyNewValue2'
                }
            }
        }

        BeforeEach {
            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:getMethodCallCount = 0
                $script:modifyMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Get' -Value {
                    $script:getMethodCallCount++

                    $currentStateInstance = [System.Activator]::CreateInstance($this.GetType())
                    $currentStateInstance.MyResourceKeyProperty1 = 'MyValue1'
                    $currentStateInstance.MyResourceProperty2 = 'MyValue2'

                    return $currentStateInstance
                } -Force -PassThru |
                    Add-Member -MemberType ScriptMethod -Name 'Modify' -Value {
                        $script:modifyMethodCallCount++
                    } -Force

                $mockResourceBaseInstance.PropertiesNotInDesiredState = @(
                    @{
                        Property      = 'MyResourceProperty2'
                        ExpectedValue = 'MyNewValue2'
                        ActualValue   = 'MyValue2'
                    }
                )
            }
        }

        It 'Should modify the properties and return the state after the modification' {
            InModuleScope -ScriptBlock {
                $setResult = $mockResourceBaseInstance.GetSetResult($false)

                $setResult.Item2 | Should -HaveCount 1
                $setResult.Item2 | Should -Contain 'MyResourceProperty2'

                $script:modifyMethodCallCount | Should -Be 1

                # One call to get the current state and one call to get the state after the modification.
                $script:getMethodCallCount | Should -Be 2
            }
        }

        It 'Should not modify anything in what-if mode and return the predicted state' {
            InModuleScope -ScriptBlock {
                $setResult = $mockResourceBaseInstance.GetSetResult($true)

                $setResult.Item1.MyResourceProperty2 | Should -Be 'MyNewValue2'
                $setResult.Item1.MyResourceKeyProperty1 | Should -Be 'MyValue1'
                $setResult.Item2 | Should -HaveCount 1
                $setResult.Item2 | Should -Contain 'MyResourceProperty2'

                $script:modifyMethodCallCount | Should -Be 0
                $script:getMethodCallCount | Should -Be 1
            }
        }

        It 'Should return the tuple through the derived class static method Set()' {
            InModuleScope -ScriptBlock {
                $setResult = $mockResourceBaseType::Set($mockResourceBaseInstance, $true)

                $setResult.Item1.GetType().Name | Should -Be 'MyMockResource'
                $setResult.Item2 | Should -Contain 'MyResourceProperty2'

                $script:modifyMethodCallCount | Should -Be 0
            }
        }
    }
}

Describe 'ResourceBase\GetPredictedState()' -Tag 'GetPredictedState' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }

        $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

        InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        InModuleScope -ScriptBlock {
            $mockResourceBaseInstance.PropertiesNotInDesiredState = @(
                @{
                    Property      = 'MyResourceProperty2'
                    ExpectedValue = 'MyNewValue2'
                    ActualValue   = 'MyValue2'
                }
            )

            $script:mockCurrentStateInstance = [System.Activator]::CreateInstance($mockResourceBaseInstance.GetType())
            $script:mockCurrentStateInstance.MyResourceKeyProperty1 = 'MyValue1'
            $script:mockCurrentStateInstance.MyResourceProperty2 = 'MyValue2'
            $script:mockCurrentStateInstance.Reasons = @(
                @{
                    Code   = 'MyMockResource:MyMockResource:MyResourceProperty2'
                    Phrase = 'The property MyResourceProperty2 should be "MyNewValue2", but was "MyValue2"'
                }
            )
        }
    }

    It 'Should return the current state with the expected values applied' {
        InModuleScope -ScriptBlock {
            $predictedState = $mockResourceBaseInstance.GetPredictedState($mockCurrentStateInstance)

            $predictedState.GetType().Name | Should -Be 'MyMockResource'
            $predictedState.MyResourceKeyProperty1 | Should -Be 'MyValue1'
            $predictedState.MyResourceProperty2 | Should -Be 'MyNewValue2'
        }
    }

    It 'Should return an empty Reasons property' {
        InModuleScope -ScriptBlock {
            $predictedState = $mockResourceBaseInstance.GetPredictedState($mockCurrentStateInstance)

            $predictedState.Reasons | Should -HaveCount 0
        }
    }

    It 'Should not modify the passed current state instance' {
        InModuleScope -ScriptBlock {
            $null = $mockResourceBaseInstance.GetPredictedState($mockCurrentStateInstance)

            $mockCurrentStateInstance.MyResourceProperty2 | Should -Be 'MyValue2'
        }
    }
}

Describe 'ResourceBase\DeleteInstance()' -Tag 'DeleteInstance' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When the resource has the canonical DSC property _exist' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:setMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Set' -Value {
                    $script:setMethodCallCount++
                } -Force
            }
        }

        It 'Should set _exist to $false and enforce the desired state' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.DeleteInstance()

                $mockResourceBaseInstance._exist | Should -BeFalse
                $script:setMethodCallCount | Should -Be 1
            }
        }
    }

    Context 'When the resource has the property Ensure' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:setMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Set' -Value {
                    $script:setMethodCallCount++
                } -Force
            }
        }

        It 'Should set Ensure to Absent and enforce the desired state' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.DeleteInstance()

                $mockResourceBaseInstance.Ensure | Should -Be ([Ensure]::Absent)
                $script:setMethodCallCount | Should -Be 1
            }
        }
    }

    Context 'When the resource has both the property _exist and the property Ensure' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
            InModuleScope -ScriptBlock {
                $script:setMethodCallCount = 0

                $mockResourceBaseInstance | Add-Member -MemberType ScriptMethod -Name 'Set' -Value {
                    $script:setMethodCallCount++
                } -Force
            }
        }

        It 'Should use the canonical DSC property _exist' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.DeleteInstance()

                $mockResourceBaseInstance._exist | Should -BeFalse
                $mockResourceBaseInstance.Ensure | Should -Be ([Ensure]::Present)
                $script:setMethodCallCount | Should -Be 1
            }
        }
    }

    Context 'When the resource has neither the property _exist nor the property Ensure' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    MyMockResource () {}
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should throw the correct error' {
            InModuleScope -ScriptBlock {
                { $mockResourceBaseInstance.DeleteInstance() } | Should -Throw -ExpectedMessage '*does not support the delete operation*'
            }
        }
    }
}

Describe 'ResourceBase\ExportInstances()' -Tag 'ExportInstances' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When the method ExportInstances() is not overridden' {
        BeforeAll {
            $mockResourceBaseInstance = InModuleScope -ScriptBlock {
                [ResourceBase]::new()
            }
        }

        It 'Should throw the correct error' {
            { $mockResourceBaseInstance.ExportInstances($null) } | Should -Throw -ExpectedMessage '*ExportInstances()*'
        }
    }

    Context 'When the method ExportInstances() is overridden' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    MyMockResource () {}

    hidden [ResourceBase[]] ExportInstances([ResourceBase] $filteringInstance)
    {
        $instance1 = [MyMockResource]::new()
        $instance1.MyResourceKeyProperty1 = 'Instance1'

        $instance2 = [MyMockResource]::new()
        $instance2.MyResourceKeyProperty1 = 'Instance2'

        if ($null -ne $filteringInstance)
        {
            return @($instance1)
        }

        return @($instance1, $instance2)
    }

    static [MyMockResource[]] Export()
    {
        return [MyMockResource]::new().ExportInstances($null)
    }

    static [MyMockResource[]] Export([MyMockResource] $filteringInstance)
    {
        return [MyMockResource]::new().ExportInstances($filteringInstance)
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
$script:mockResourceBaseType = [MyMockResource]
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should return every instance through the derived class static method Export()' {
            InModuleScope -ScriptBlock {
                $exportResult = $mockResourceBaseType::Export()

                $exportResult | Should -HaveCount 2
                $exportResult[0].GetType().Name | Should -Be 'MyMockResource'
                $exportResult[0].MyResourceKeyProperty1 | Should -Be 'Instance1'
                $exportResult[1].MyResourceKeyProperty1 | Should -Be 'Instance2'
            }
        }

        It 'Should return the matching instances through the derived class static method Export() with a filtering instance' {
            InModuleScope -ScriptBlock {
                $exportResult = $mockResourceBaseType::Export($mockResourceBaseInstance)

                $exportResult | Should -HaveCount 1
                $exportResult[0].MyResourceKeyProperty1 | Should -Be 'Instance1'
            }
        }
    }
}

Describe 'ResourceBase\GetInstanceJsonSchema()' -Tag 'GetInstanceJsonSchema' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }

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

    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty(NotConfigurable)]
    [System.Collections.Hashtable[]]
    $Reasons

    MyMockResource () {}

    static [System.String] InstanceJsonSchema()
    {
        return [MyMockResource]::new().GetInstanceJsonSchema()
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
$script:mockResourceBaseType = [MyMockResource]
'@

        InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
    }

    It 'Should return a valid JSON string through the derived class static method InstanceJsonSchema()' {
        InModuleScope -ScriptBlock {
            $schemaJson = $mockResourceBaseType::InstanceJsonSchema()

            { $schemaJson | ConvertFrom-Json -ErrorAction 'Stop' } | Should -Not -Throw
        }
    }

    It 'Should return the correct schema' {
        InModuleScope -ScriptBlock {
            $schema = $mockResourceBaseType::InstanceJsonSchema() | ConvertFrom-Json

            $schema.title | Should -Be 'MyMockResource'
            $schema.type | Should -Be 'object'
            $schema.required | Should -Contain 'MyResourceKeyProperty1'
            $schema.additionalProperties | Should -BeFalse

            $schema.properties.MyResourceKeyProperty1.type | Should -Be 'string'
            $schema.properties.Ensure.type | Should -Be 'string'
            $schema.properties.Ensure.enum | Should -Contain 'Present'
            $schema.properties.Ensure.enum | Should -Contain 'Absent'
            $schema.properties._exist.type | Should -Be 'boolean'
            $schema.properties.Reasons.type | Should -Be 'array'
            $schema.properties.Reasons.readOnly | Should -BeTrue
        }
    }

    It 'Should include properties inherited from a base class' {
        InModuleScope -ScriptBlock {
            $schema = $mockResourceBaseType::InstanceJsonSchema() | ConvertFrom-Json

            $schema.properties.MyInheritedProperty.type | Should -Be 'string'
        }
    }
}

Describe 'ResourceBase\Get() canonical DSC property _exist' -Tag 'Get' {
    BeforeAll {
        Mock -CommandName Get-ClassName -MockWith {
            # Only return localized strings for this class name.
            @('ResourceBase')
        }
    }

    Context 'When the object exists in the current state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource() : base ()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'MyResourceKeyProperty1'
        )
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        return @{
            MyResourceKeyProperty1 = 'MyValue1'
            MyResourceProperty2 = 'MyValue2'
        }
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should return _exist as $true' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'
                $mockResourceBaseInstance.MyResourceProperty2 = 'MyValue2'

                $getResult = $mockResourceBaseInstance.Get()

                $getResult._exist | Should -BeTrue
            }
        }
    }

    Context 'When the object does not exist in the current state' {
        BeforeAll {
            $inModuleScopeScriptBlock = @'
using module DscResource.Base

class MyMockResource : ResourceBase
{
    [DscProperty(Key)]
    [System.String]
    $MyResourceKeyProperty1

    [DscProperty()]
    [System.Boolean]
    $_exist = $true

    [DscProperty()]
    [System.String]
    $MyResourceProperty2

    MyMockResource() : base ()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'MyResourceKeyProperty1'
        )
    }

    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        # The object does not exist in the current state.
        return @{}
    }
}

$script:mockResourceBaseInstance = [MyMockResource]::new()
'@

            InModuleScope -ScriptBlock ([Scriptblock]::Create($inModuleScopeScriptBlock))
        }

        It 'Should return _exist as $false' {
            InModuleScope -ScriptBlock {
                $mockResourceBaseInstance.MyResourceKeyProperty1 = 'MyValue1'

                $getResult = $mockResourceBaseInstance.Get()

                $getResult._exist | Should -BeFalse
            }
        }
    }
}
