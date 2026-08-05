@{
    RootModule        = 'DscResourceBaseTestResource.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'f3a1c8d2-6b4e-4f9a-9c2d-8e7b5a0d1c3f'
    Author            = 'DSC Community'
    CompanyName       = 'DSC Community'
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'
    Description       = 'Test fixture module with a class-based DSC resource that derives from ResourceBase in the module DscResource.Base. Used by the integration tests.'
    PowerShellVersion = '5.0'
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    DscResourcesToExport = @(
        'DscBaseTestResource'
    )

    PrivateData       = @{
        PSData = @{
            # Capabilities fallback used by the DSC PowerShell adapter.
            DscCapabilities = @(
                'get'
                'set'
                'test'
                'delete'
                'export'
            )
        }
    }
}
