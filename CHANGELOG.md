# Change log for DscResource.Base

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

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
