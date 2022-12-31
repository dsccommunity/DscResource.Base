# Contributing to DscResource.Base

If you are keen to make DscResource.Base better, why not consider contributing your work
to the project? Every little change helps us make a better resource for everyone
to use, and we would love to have contributions from the community.

## Core contribution guidelines

Please check out common DSC Community [contributing guidelines](https://dsccommunity.org/guidelines/contributing).

## Documentation with Markdown

The following table is a guideline on when to use markdown code in parameter
description. There can be other usages that are not described here. Backslash
must always be escaped (using `\`, e.g `\\`).

<!-- markdownlint-disable MD013 - Line length -->
Type | Markdown syntax | Example
-- | -- | --
**Parameter reference** | `**ParameterName**` (bold) | **ParameterName**
**Parameter value reference** | `` `'String1'` ``, `` `$true` ``, `` `50` `` (inline code-block) | `'String1'`, `$true`, `50`
**Name reference** (resource, modules, products, or features, etc.) | `_Microsoft SQL Server Database Engine_` (Italic) | _Microsoft SQL Server Database Engine_
**Path reference** | `` `C:\\Program Files\\SSRS` `` | `C:\\Program Files\\SSRS`
**Filename reference** | `` `log.txt` `` | `log.txt`

<!-- markdownlint-enable MD013 - Line length -->

If using Visual Studio Code to edit Markdown files it can be a good idea
to install the markdownlint extension. It will help to do style checking.
The file [.markdownlint.json](/.markdownlint.json) is prepared with a default
set of rules which will automatically be used by the extension.

## Automatic formatting with VS Code

There is a VS Code workspace settings file within this project with formatting
settings matching the style guideline. That will make it possible inside VS Code
to press SHIFT+ALT+F, or press F1 and choose 'Format document' in the list. The
PowerShell code will then be formatted according to the Style Guideline
(although maybe not complete, but would help a long way).

## Script Analyzer rules

There are several Script Analyzer rules to help with the development and review
process. Rules come from the modules **ScriptAnalyzer**, **DscResource.AnalyzerRules**,
**Indented.ScriptAnalyzerRules**, and **DscResource.Base.AnalyzerRules**.

Some rules (but not all) are allowed to be overridden with a justification.

This is an example how to override a rule from the module **DscResource.Base.AnalyzerRules**.

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.Base.AnalyzerRules\Measure-CommandsNeededToLoadSMO', '', Justification='The command Connect-Sql is called when Get-TargetResource is called')]
param ()
```

This is an example how to override a rule from the module **ScriptAnalyzer**.

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification='Because $global:DSCMachineStatus is used to trigger a Restart, either by force or when there are pending changes')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Because $global:DSCMachineStatus is only set, never used (by design of Desired State Configuration)')]
param ()
```

This is an example how to override a rule from the module **Indented.ScriptAnalyzerRules**.

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidThrowOutsideOfTry', '', Justification='Because the code throws based on an prior expression')]
param ()
```

## Design patterns

### Localization

In each resource folder there should be, at least, a localization folder for
english language 'en-US'.

Read more about this in the [localization style guideline](https://dsccommunity.org/styleguidelines/localization/).

### Private functions

Private functions that is only used by classes or public commands shall be added
to a script file in the `source/Private` folder. Each file in the Private folder
should contain one function and the file name should be named the same as the
function name (Verb-Noun).

### Public commands

Public commands shall be added to a script file in the `source/Private` folder.
Each file in the Public folder should contain one command and the
file name should be named the same as the command name (Verb-Noun).
Each command in the folder Public will be publicly exported.

### Unit tests

For a review of a Pull Request (PR) to start, all tests must pass without error.
If you need help to figure why some test don't pass, just write a comment in the
Pull Request (PR), or submit an issue, and somebody will come along and assist.

If want to know how to run this module's tests you can look at the [Testing Guidelines](https://dsccommunity.org/guidelines/testing-guidelines/#running-tests)

### Class-based DSC resource

#### Terminating Error

A terminating error is an error that prevents the resource to continue further.
If a DSC resource shall throw an terminating error the commands of the module
**DscResource.Common** shall be used primarily; [`New-InvalidArgumentException`](https://github.com/dsccommunity/DscResource.Common#new-invalidargumentexception),
[`New-InvalidDataExcpetion`](https://github.com/dsccommunity/DscResource.Common#new-invaliddataexception),
[`New-InvalidOperationException`](https://github.com/dsccommunity/DscResource.Common#new-invalidoperationexception),
[`New-InvalidResultException`](https://github.com/dsccommunity/DscResource.Common#new-invalidresultexception),
or [`New-NotImplementedException`](https://github.com/dsccommunity/DscResource.Common#new-notimplementedexception).
If neither of those commands works in the scenarion then `throw` shall be used.

### Commands

Commands are publicly exported commands from the module, and the source for
commands are located in the folder `./source/Public`.

#### Non-Terminating Error

A non-terminating error should only be used when a command shall be able to
handle (ignoring) an error and continue processing and still give the user
an expected outcome.

With a non-terminating error the user is able to decide whether the command
should throw or continue processing on error. The user can pass the
parameter and value `-ErrorAction 'SilentlyContinue'` to the command  to
ignore the error and allowing the command to continue, for example the
command could then return `$null`. But if the user passes the parameter
and value `-ErrorAction 'Stop'` the same error will throw a terminating
error telling the user the expected outcome could not be achieved.

The below example checks to see if a database exist, if it doesn't a
non-terminating error are called. The user is able to either ignore the
error or have it throw depending on what value the user specifies
in parameter `ErrorAction` (or `$ErrorActionPreference`).

```powershell
if (-not $databaseExist)
{
    $errorMessage = $script:localizedData.MissingDatabase -f $DatabaseName

    Write-Error -Message $errorMessage -Category 'InvalidOperation' -ErrorId 'GS0001' -TargetObject $DatabaseName
}
```

#### Terminating Error

A terminating error is an error that the user are not able to ignore by
passing a parameter to the command (like for non-terminating errors).

If a command shall throw an terminating error then the statement `throw` shall
not be used, neither shall the command `Write-Error` with the parameter
`-ErrorAction Stop`. Always use the method `$PSCmdlet.ThrowTerminatingError()`
to throw a terminating error. The exception is when a `[ValidateScript()]`
has to throw an error, then `throw` must be used.

>**NOTE:** Below output assumes `$ErrorView` is set to `'NormalView'` in the
>PowerShell session.

When using `throw` it will fail on the line with the throw statement
making it look like it is that statement inside the function that failed,
which is not correct since it is either a previous command or evaluation
that failed resulting in the line with the `throw` being called. This is
an example when using `throw`:

```plaintext
Exception:
Line |
   2 |  throw 'My error'
     |  ~~~~~~~~~~~~~~~~
     | My error
```

When instead using `$PSCmdlet.ThrowTerminatingError()`:

```powershell
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new(
        'MyError',
        'GS0001',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        'MyObjectOrValue'
    )
)
```

The result from `$PSCmdlet.ThrowTerminatingError()` shows that the command
failed (in this example `Get-Something`) and returns a clear category and
error code.

```plaintext
Get-Something : My Error
At line:1 char:1
+ Get-Something
+ ~~~~~~~~~~~~~
+ CategoryInfo          : InvalidOperation: (MyObjectOrValue:String) [Get-Something], Exception
+ FullyQualifiedErrorId : GS0001,Get-Something
```
