# PuppetDSCBuilder

This PowerShell module downloads DSC Resources from the PSGallery and then builds a Puppet Module containing parsed Puppet types. Similar to the puppetlabs-dsc module, it contains the source DSC Resource as well as the Puppet type, but is configurable to only have the DSC Resources you specify. This reduces the size of the module and allows different deplyoment scenarios.

## Converting a Module from the Public Gallery

Use the `New-PuppetDscModule` function to download DSC Resources from the PSGallery and build a Puppet Module which vendors and exposes those resources as Puppet resources.
Lets go through the workflow for building the Puppet Module.

### Building the Module

```powershell
New-PuppetDscModule -PowerShellModuleName 'PowerShellGet' -PowerShellModuleVersion '2.1.3'  -PuppetModuleAuthor 'testuser' -OutputDirectory '../bar'
```

This function will create a new Puppet module, powershellget, which vendors and puppetizes the PowerShellGet PowerShell module at version 2.2.3 and its dependencies, exposing the DSC resources as Puppet resources. 
By default, it will fetch from the public PSGallery but this behavior can be overridden,.

The module is generated successfully in the `import` folder at the current path location.

It contains type, providers, metadata.json, REFERENCE.md etc. - all the components you need and expect for a Puppet module.

We can use the [PDK commands](https://puppet.com/docs/pdk/1.x/pdk_reference.html) to build and install the module.

```sh
pdk build
pdk bundle exec puppet module install --verbose pkg/*.tar.gz
```

Generated tar file can be uploaded to the forge manually or by using the function `Publish-PuppetModule`

```powershell
Publish-PuppetModule -PuppetModuleFolderPath C:\output\testmodule -ForgeUploadUrl https://testforgeapi.test.com/releases -ForgeToken testmoduletoken -Build -Publish
```

This command will create or use existing pkg and publish the `<tarball>` to the Forge, for the `testmodule` depends on the options passed for pdk release command.

### Sample Manifest Using the Generated Module

```puppet
dsc_psrepository { "Foo":
  dsc_name               => "Foo",
  dsc_ensure             => "Present",
  dsc_sourcelocation     => "c:\\program files",
  dsc_installationpolicy => "Untrusted",
}
```

Verify the resources are created successfully.

```sh
pdk bundle exec puppet resource dsc_psrepository
```

### Platform Support

- Windows PowerShell 5.1

## Platform Support

- Windows PowerShell 5.1

*Note*: The build system requires Windows PowerShell at this time while the DSC support in 7+ is still experimental.
