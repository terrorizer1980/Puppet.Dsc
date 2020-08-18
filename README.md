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

## Converting a Module from the Public Gallery

New-PuppetDscModule functions downloads DSC Resources from the PSGallery and builds a Puppet Module.
Lets go through the workflow for building the Puppet Module.

### Building the Module

`New-PuppetDscModule -PowerShellModuleName "PowerShellGet" -PowerShellModuleVersion "2.1.3"  -PuppetModuleAuthor 'testuser' -OutputDirectory "../bar"`

This function will create a new Puppet module, powershellget, which vendors and puppetizes the PowerShellGet PowerShell module at version 2.2.3 and its dependencies, exposing the DSC resources as Puppet resources. 
By default the respository value to fetch the resource is PSGallery.

The module is generated successfully in import folder of the current path.

It contains type, providers, metadata.json, REFERENCE.md etc.

We can use the pdk commands to build and install the module.

`pdk build`

`pdk bundle exec puppet module install --verbose pkg/*.tar.gz'`

Generated tar file can be uploaded to the forge manually or by using the function `Publish-PuppetModule`

`Publish-PuppetModule -PuppetModuleFolderPath C:\output\testmodule -ForgeUploadUrl https://testforgeapi.test.com/releases -ForgeToken testmoduletoken -Build true -Publish true `

This command will create or use existing pkg and Publishes the <tarball> to the Forge , for the `testmodule` depends on the options passed for pdk release command.

### Sample Manifest using the generated module
`'dsc_psrepository { "Foo":
  dsc_name               => "Foo",
  dsc_ensure             => "Present",
  dsc_sourcelocation     => "c:\\program files",
  dsc_installationpolicy => "Untrusted",
}'`

Verify the resources are created successfully.
`pdk bundle exec puppet resource dsc_psrepository`

### Platform Support

- Windows PowerShell 5.1

*Note*: The build system requires Windows PowerShell at this time because PowerShell DSC does not support PowerShell Core

### Building

1. Install the EPS module from the PowerShell Gallery
2. git clone jpogran/puppetdscbuilder
3. Add DSC Resource names and versions to ./import.csv
4. ./builder.ps1 -modulename 'dsc_foo'
