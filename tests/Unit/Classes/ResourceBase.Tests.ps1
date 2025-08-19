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
