@{
    CustomRulePath      = @(
        './output/RequiredModules/DscResource.AnalyzerRules'
        './output/RequiredModules/Indented.ScriptAnalyzerRules'
    )
    IncludeDefaultRules = $true
    IncludeRules        = @(
        # DSC Community style guideline rules from the module ScriptAnalyzer.
        'PSAvoidDefaultValueForMandatoryParameter'
        'PSAvoidDefaultValueSwitchParameter'
        'PSAvoidInvokingEmptyMembers'
        'PSAvoidNullOrEmptyHelpMessageAttribute'
        'PSAvoidUsingCmdletAliases'
        'PSAvoidUsingComputerNameHardcoded'
        'PSAvoidUsingDeprecatedManifestFields'
        'PSAvoidUsingEmptyCatchBlock'
        'PSAvoidUsingInvokeExpression'
        'PSAvoidUsingPositionalParameters'
        'PSAvoidShouldContinueWithoutForce'
        'PSAvoidUsingWMICmdlet'
        'PSAvoidUsingWriteHost'
        'PSDSCReturnCorrectTypesForDSCFunctions'
        'PSDSCStandardDSCFunctionsInResource'
        'PSDSCUseIdenticalMandatoryParametersForDSC'
        'PSDSCUseIdenticalParametersForDSC'
        'PSMisleadingBacktick'
        'PSMissingModuleManifestField'
        'PSPossibleIncorrectComparisonWithNull'
        'PSProvideCommentHelp'
        'PSReservedCmdletChar'
        'PSReservedParams'
        'PSUseApprovedVerbs'
        'PSUseCmdletCorrectly'
        'PSUseOutputTypeCorrectly'
        'PSAvoidGlobalVars'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSDSCUseVerboseMessageInDSCResource'
        'PSShouldProcess'
        'PSUseDeclaredVarsMoreThanAssignments'
        'PSUsePSCredentialType'

        # Additional rules from the module ScriptAnalyzer
        'PSUseConsistentWhitespace'
        'UseCorrectCasing'
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'AlignAssignmentStatement'
        'AvoidUsingDoubleQuotesForConstantString'
        'UseShouldProcessForStateChangingFunctions'

        # Rules from the modules DscResource.AnalyzerRules and SqlServerDsc.AnalyzerRules
        'Measure-*'

        # Rules from the module Indented.ScriptAnalyzerRules
        'AvoidCreatingObjectsFromAnEmptyString'
        'AvoidDashCharacters'
        'AvoidEmptyNamedBlocks'
        'AvoidFilter'
        'AvoidHelpMessage'
        'AvoidNestedFunctions'
        'AvoidNewObjectToCreatePSObject'
        'AvoidParameterAttributeDefaultValues'
        'AvoidProcessWithoutPipeline'
        'AvoidSmartQuotes'
        'AvoidThrowOutsideOfTry'
        'AvoidWriteErrorStop'
        'AvoidWriteOutput'
        'UseSyntacticallyCorrectExamples'
    )

    # TODO: This is not excluded correctly, see test QA/ScriptAnalyzer.Tests.ps1 for more information.
    ExcludeRules        = @(
        'TypeNotFound'
    )

    Rules               = @{
        PSUseConsistentWhitespace  = @{
            Enable                          = $true
            CheckOpenBrace                  = $true
            CheckInnerBrace                 = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $false
            CheckSeparator                  = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $true
            CheckParameter                  = $false
        }

        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $false
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NoEmptyLineBefore  = $true
            IgnoreOneLineBlock = $false
            NewLineAfter       = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
    }
}
