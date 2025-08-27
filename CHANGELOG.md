# Change log for DscResource.Base

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `azure-pipelines.yml`
  - Remove `windows-2019` images fixes [#43](https://github.com/dsccommunity/DscResource.Base/issues/43)
  - Move individual tasks to `windows-latest`.
- `ResourceBase`
  - Cache properties not in desired state.
  - Make `Set()` call `Test()` and `Test()` call `Get()`.
  - Remove use of array addition and `ForEach-Object`.

### Removed

- `ResourceBase`
  - Remove `Compare()` method as not used.
  - Removed feature flags and alternate behavior.

## [1.4.0] - 2025-05-24

### Removed

- Removed `Clear-ZeroedEnumPropertyValue` as it was moved and implemented
  the `Get-DscProperty` command in the _DscResource.Common_ module.

### Added

- Wiki
  - How to use this base class. Fixes [#5](https://github.com/dsccommunity/DscResource.Base/issues/5)
  and [#19](https://github.com/dsccommunity/DscResource.Base/issues/19).
  - Add WikiContent to release assets.

### Changed

- `ResourceBase`
  - Refactor `GetDesiredState` method to handle zeroed enum values using
    `Get-DscProperty` when the property `FeatureOptionalEnums` is set to
    `$true`.
  - Remove calls to `Assert()` and `Normalize()` in `Test()` and `Set()` fixes [#35](https://github.com/dsccommunity/DscResource.Base/issues/35).

### Fixed

- build.yaml
  - Add `Generate_Wiki_Content`, `Generate_Wiki_Sidebar`, `Clean_Markdown_Metadata`
docs tasks. Fixes [#32](https://github.com/dsccommunity/DscResource.Base/issues/32).
- `ResourceBase`
  - Add check for properties not being `$null` fixes [#30](https://github.com/dsccommunity/DscResource.Base/issues/30).
  - Comment typo's.

## [1.3.0] - 2025-03-15

### Added

- `ResourceBase`
  - Added a new method `NormalizeProperties` that can be overridden in a
    derived class to provide custom normalization logic. This method can
    be used to normalize the properties of a desired state prior to the
    methods `AssertProperties`, `GetCurrentState`, and `Modify` being called.
    Default there is no normalization of properties. Fixes [issue #27](https://github.com/dsccommunity/DscResource.Base/issues/27).

## [1.2.1] - 2025-02-03

### Changed

- `Clear-ZeroedEnumPropertyValue`
  - Fixed enum type check.

## [1.2.0] - 2025-02-02

### Added

- `ResourceBase`
  - Add optional feature flag to handle using Enums as optional properties.
    This requires setting the starting value of the Enum to 1 so it is
    initialized as 0. Fixes [Issue #22](https://github.com/dsccommunity/DscResource.Base/issues/22).

    To use, set `$this.FeatureOptionalEnums = $true` in your class constructor.
- `Clear-ZeroedEnumPropertyValue`
  - Added private function to remove enums with a zero value from a hashtable.

### Changed

- `ResourceBase`
  - Add feature flag to allow use of enums on optional properties.
- `RequiredModules`
  - Add PlatyPS
- `Resolve-Dependency`
  - Add latest config
- `build.yaml`
  - Move docs to own task
  - Remove `VersionedOutputDirectory` as default value is `True`
- `build.ps1`
  - Update from Sampler
- `Resolve-Dependency.ps1`
  - Update from Sampler

### Fixed

- `Get-LocalizedDataRecursive`
  - Switch `throw` to use `TerminatingError` [issue #16](https://github.com/dsccommunity/DscResource.Base/issues/16)

## [1.1.2] - 2024-08-17

### Fixed

- Correcting module manifest and help file description.
- Update build pipeline to use GitVersion v5.

## [1.1.1] - 2024-06-11

### Fixed

- DscResource.Base
  - Test results is now found for the HQRM tests when run in the pipeline.
- `ResourceBase`
  - Fixed style changed.

### Changed

- DscResource.Base
  - Move code coverage task in the pipeline to use task `PublishCodeCoverageResults@2`.
- `Get-LocalizedDataRecursive`
  - Move strings to localized versions ([issue #7](https://github.com/dsccommunity/DscResource.Base/issues/7)).
  - Fix various formatting issues

## [1.1.0] - 2023-02-26

### Added

- DscResource.Base
  - A new private function `ConvertFrom-Reason` was added which takes an
    array of `[Reason]` and coverts it to an array of `[System.Collections.Hashtable]`.

### Changed

- DscResource.Base
  - Enable Pester's new code coverage method.
  - The private function `ConvertTo-Reason` was renamed `Resolve-Reason`.
- `ResourceBase`
  - The property `Reasons` in derived class-based resources is now expected
    to use the type `[System.Collections.Hashtable[]]` ([issue #4](https://github.com/dsccommunity/DscResource.Base/issues/4)).

### Fixed

- DscResource.Base
  - Correct pipeline definition id for status badges in README.md.
- `ResourceBase`
  - Increased code coverage.

## [1.0.0] - 2022-12-31

### Added

- Added the first version of `ResourceBase`.
