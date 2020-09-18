# Puppet.Dsc

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

## Troubleshooting

Occasionally, something will go wrong when trying to apply a manifest containing Puppetized DSC resources.
There's a few different ways this can happen:

- There can be a misgenerated type, in which case the Puppet representation of the DSC resource does not match the resource's API surface.
  This can be mismatched enums or types - in these cases, the issue is with this builder and a [bug will need to be submitted for this project](https://github.com/puppetlabs/Puppet.Dsc/issues/new?assignees=&labels=Bug%2C+bug&template=bug-report.md&title=) so the Puppetized module can be rebuilt with the patched builder.
- There can be an error in the Ruby code that translates the DSC resource back and forth between Puppet and PowerShell, in which case the issue is with the base provider that lives in the [`pwshlib` module](https://forge.puppet.com/puppetlabs/pwshlib);
  Once a [bug is submitted for that project](https://github.com/puppetlabs/ruby-pwsh/issues/new?assignees=&labels=Bug%2C+bug&template=bug-report.md&title=) and a fix is released, the manifest and Puppetized module should work without any updates except in the dependency `pwshlib` module.
- There can be an error in the underlying DSC resource's implementation in PowerShell - in this case, you'll need to submit a bug with the upstream maintainers for that DSC resource's PowerShell module.
  Once a new release of that module is out a new build of the Puppetized module can happen, vendoring in those updates.

### Type Errors

Sometimes the wrong type of value is specified in a Puppet manifest.
When that happens, you will see an error like this:

```text
Error: dsc_psrepository: Convert property 'name' value from type 'SINT64' to type 'STRING' failed
...
Error: Parameter dsc_name failed on Dsc_psrepository[Foo]: dsc_psrepository.dsc_name expects a String value, got Integer
```

In this case, an integer was specified where the type expected a string;
moreover, the error specifies the resource type (`dsc_psrepository`), title (`Foo`), and the parameter (`dsc_name`) where the error can be found.

### Incorrect Enum

As with incorrect value types, Puppet will also report when an incorrect enum is specified:

```text
Error: Parameter dsc_installationpolicy failed on Dsc_psrepository[Foo]: dsc_psrepository.dsc_installationpolicy expects an undef value or a match for Enum['Trusted', 'Untrusted'], got 'Nonexistant'
```

In this case, for the `Foo` `dsc_psrepository` resource instead of either `Trusted` or `Untrusted`, the value `Nonexistant` was specified in the manifest.

### Error During Invocation

When a DSC invocation goes wrong, Puppet surfaces whatever error DSC/PowerShell returned.
This both means that the error you get is as explicit as Puppet is capable of returning but _also_ that the error quality depends entirely on the underlying DSC implementation for that resource in PowerShell.

```text
Error: dsc_psrepository[{:name=>"Bar", :dsc_name=>"Bar"}]: Creating: PowerShell DSC resource MSFT_PSRepository  failed to execute Set-TargetResource functionality with error message: The running command stopped because the preference variable "ErrorActionPreference" or common parameter is set to Stop: The repository could not be registered because there exists a registered repository with Name 'Foo' and SourceLocation 'C:\Foo'. To register another repository with Name 'Bar', please unregister the existing repository using the Unregister-PSRepository cmdlet.
```

In this case the error is, luckily, fairly explicit:
the specified source location is already being used with another PSRepository;
to clear the error, we'll need to either change the source location or unregister the other PSRepository.

### Debug Mode

Debug mode with Puppetized DSC resources can give you a _lot_ of information, so it's worth looking into that in more detail.
To run in debug mode, append a `--debug` to the end of your Puppet apply call.
That will cause your run to return information like this:

```text
Debug: dsc_psrepository: retrieving {:name=>"PowerShell Gallery", :dsc_name=>"psgAllery", :dsc_installationpolicy=>"Trusted"}
Debug: dsc_psrepository: should_to_resource: {:parameters=>{:dsc_name=>{:value=>"psgAllery", :mof_type=>"String", :mof_is_embedded=>false}}, :name=>"dsc_psrepository", :dscmeta_resource_friendly_name=>"PSRepository", :dscmeta_resource_name=>"MSFT_PSRepository", :dscmeta_module_name=>"PowerShellGet", :dscmeta_module_version=>"2.2.4.1", :dsc_invoke_method=>"get", :vendored_modules_path=>"C:/code/puppetlabs/Puppet.Dsc/import/powershellget/spec/fixtures/modules/powershellget/lib/puppet_x/dsc_resources", :attributes=>nil}
Debug: dsc_psrepository: Script:
... (snipped for brevity)
$InvokeParams = @{Name = 'PSRepository'; Method = 'get'; Property = @{name = 'psgAllery'}; ModuleName = @{ModuleName = 'C:/code/puppetlabs/Puppet.Dsc/import/powershellget/spec/fixtures/modules/powershellget/lib/puppet_x/dsc_resources/PowerShellGet/PowerShellGet.psd1'; RequiredVersion = '2.2.4.1'}}
Try {
  $Result = Invoke-DscResource @InvokeParams
} catch {
  $Response.errormessage   = $_.Exception.Message
  return ($Response | ConvertTo-Json -Compress)
}
... (snipped for brevity)
Debug: dsc_psrepository: raw data received: {"SourceLocation"=>"https://www.powershellgallery.com/api/v2", "InstallationPolicy"=>"Trusted", "Registered"=>true, "Name"=>"psgAllery", "ResourceId"=>nil, "PackageManagementProvider"=>"NuGet", "Trusted"=>true, "PsDscRunAsCredential"=>nil, "PublishLocation"=>"https://www.powershellgallery.com/api/v2/package/", "Ensure"=>"Present", "DependsOn"=>nil, "SourceInfo"=>nil, "ScriptPublishLocation"=>"https://www.powershellgallery.com/api/v2/package/", "ConfigurationName"=>nil, "ModuleVersion"=>"2.2.4.1", "ModuleName"=>"C:/code/puppetlabs/Puppet.Dsc/import/powershellget/spec/fixtures/modules/powershellget/lib/puppet_x/dsc_resources/PowerShellGet/PowerShellGet.psd1", "ScriptSourceLocation"=>"https://www.powershellgallery.com/api/v2/items/psscript"}
Debug: dsc_psrepository: Returned to Puppet as {:dsc_sourcelocation=>"https://www.powershellgallery.com/api/v2", :dsc_installationpolicy=>"Trusted", :dsc_name=>"psgAllery", :dsc_packagemanagementprovider=>"NuGet", :dsc_publishlocation=>"https://www.powershellgallery.com/api/v2/package/", :dsc_ensure=>"Present", :dsc_scriptpublishlocation=>"https://www.powershellgallery.com/api/v2/package/", :dsc_scriptsourcelocation=>"https://www.powershellgallery.com/api/v2/items/psscript", :name=>"PowerShell Gallery", :ensure=>"present"}
Debug: dsc_psrepository: Canonicalized Resources: [{:dsc_installationpolicy=>"Trusted", :dsc_name=>"psgAllery", :name=>"PowerShell Gallery"}]
... (snipped for brevity)
```

The debug information tells you what Puppet is up to, elaborates on the values being passed, then gives you the full text of the PowerShell script being executed (with any sensitive info redacted).
Finally, it tells you what the outcome of that run was.

In particular, when there is an esoteric error it can be useful to copy the invocation from the debug output to a text file you can invoke directly or investigate more thoroughly, especially around the invocation parameters.
Because the code being run is just a PowerShell script, you should then be able to use your usual debugging and investigation tools the same way you would with any other PowerShell script.

## Platform Support

- Windows PowerShell 5.1

*Note*: The build system requires Windows PowerShell at this time while the DSC support in 7+ is still experimental.
