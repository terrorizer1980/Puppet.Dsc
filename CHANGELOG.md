# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `JoinOU` to the static list of DSC Resource properties which are Puppet parameters ([#107](https://github.com/puppetlabs/Puppet.Dsc/pulls/107))

## [0.2.0] - 2020-12-04

### Added

- Known limitations section to generated README ([#56](https://github.com/puppetlabs/Puppet.Dsc/pull/56))
- Function to update Puppet module changelog ([#57](https://github.com/puppetlabs/Puppet.Dsc/pull/57))
- Ability to Puppetize PowerShell modules marked as prerelease on the Gallery ([#76](https://github.com/puppetlabs/Puppet.Dsc/pull/76))
- Handling for non-retrievable DSC Resource properties as Puppet parameters ([#88](https://github.com/puppetlabs/Puppet.Dsc/pull/88))
- Clarification to generated README for properties passed to `Invoke-DscResource` and properties that set Puppet behavior ([#84](https://github.com/puppetlabs/Puppet.Dsc/pull/84))
- Handling for read-only properties, allowing them to be included in the generated types and appropriately marked ([#99](https://github.com/puppetlabs/Puppet.Dsc/pull/99))

### Changed

- Lower bound for `pwshlib-puppetlabs` raised to `0.6.1` ([#55](https://github.com/puppetlabs/Puppet.Dsc/pull/55))
- Upper bound for Puppet raised to `8.0.0` ([#101](https://github.com/puppetlabs/Puppet.Dsc/pull/101))
- Collapsed the `ensure` and `dsc_ensure` keywords into just `dsc_ensure` and _only_ for ensurable resources ([#88](https://github.com/puppetlabs/Puppet.Dsc/pull/88))

### Fixed

- Correct links in README ([#54](https://github.com/puppetlabs/Puppet.Dsc/pull/54))
- Parseability of generated description strings in type files ([#77](https://github.com/puppetlabs/Puppet.Dsc/pull/77),[#83](https://github.com/puppetlabs/Puppet.Dsc/pull/83))
- Type generation for DSC Resource properties which are nested CIM instances with optional keys ([#78](https://github.com/puppetlabs/Puppet.Dsc/pull/78))
- Always downcase keys in structs for embedded CIM instances to prevent type definition errors ([#98](https://github.com/puppetlabs/Puppet.Dsc/pull/98))
- Bug in generated README that hid text in the troubleshooting section ([#91](https://github.com/puppetlabs/Puppet.Dsc/pull/91))

## [0.1.0] - 2020-09-25

### Added

- Initial implementation and release

[Unreleased]: https://github.com/puppetlabs/Puppet.Dsc/compare/0.2.0...HEAD
[0.2.0]: https://github.com/puppetlabs/Puppet.Dsc/releases/tag/0.2.0
[0.1.0]: https://github.com/puppetlabs/Puppet.Dsc/releases/tag/0.1.0
