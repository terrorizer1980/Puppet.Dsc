# PuppetDSCBuilder

This PowerShell module downloads DSC Resources from the PSGallery and then builds a Puppet Module containing parsed Puppet types. Similar to the puppetlabs-dsc module, it contains the source DSC Resource as well as the Puppet type, but is configurable to only have the DSC Resources you specify. This reduces the size of the module and allows different deplyoment scenarios.

## DSC Resource Import

- [x] Import from PowerShell Gallery

## Module Creation

- [x] PDK new module
- [x] Module per DSC Resource or all DSC Resources

## DSC Resource Parsing

## Base Types

- [x] Uint8,Uint16,Uint32,Uint64,Sint8,Sint16,Sint32,Sint64,Real32,Real64,Char16
- [x] String
- [x] Boolean
- [x] DateTime
- [x] Hashtable
- [x] PSCredential

## CimInstance/EmbeddedInstance

- [ ] Microsoft.Management.Infrastructure.CimInstance

## How to Build Modules

### Platform Support

- Windows PowerShell 5.1

*Note*: The build system requires Windows PowerShell at this time because PowerShell DSC does not support PowerShell Core

### Building

1. Install the EPS module from the PowerShell Gallery
1. git clone jpogran/puppetdscbuilder
1. Add DSC Resource names and versions to ./import.csv
1. ./builder.ps1 -modulename 'dsc_foo'
