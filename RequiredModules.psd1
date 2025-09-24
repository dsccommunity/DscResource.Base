@{
    PSDependOptions                = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    # Build dependencies needed for using the module
    'DscResource.Common'           = @{
        Version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }

    # Build dependencies for the pipeline
    InvokeBuild                    = 'latest'
    PSScriptAnalyzer               = 'latest'
    Pester                         = 'latest'
    Plaster                        = 'latest'
    ModuleBuilder                  = 'latest'
    ChangelogManagement            = 'latest'
    Sampler                        = 'latest'
    'Sampler.GitHubTasks'          = 'latest'
    MarkdownLinkCheck              = 'latest'
    'DscResource.Test'             = @{
        Version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }

    'DscResource.DocGenerator'     = 'latest'
    PlatyPS                        = 'latest'

    # Analyzer rules
    'DscResource.AnalyzerRules'    = 'latest'
    'Indented.ScriptAnalyzerRules' = 'latest'
}
