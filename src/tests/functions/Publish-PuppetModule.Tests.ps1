Describe 'Publish-PuppetModule' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      Mock Test-Path         { return $False }
      Mock New-Item          {}
      Mock Invoke-PdkCommand {}
      Mock Resolve-Path      {$Path}

      Initialize-PuppetModule -OutputFolderPath TestDrive:\ -PuppetModuleName Foo

      Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeToken  'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Build

      It 'Uses the PDK to generate the package' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'pdk build'} -Times 1
      }

      Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeToken  'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Publish

      It 'Uses the PDK to publish the module' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'pdk release publish'} -Times 1
      }

      Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -Publish

      It 'Uses the PDK to publish to default url' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'pdk release publish'} -Times 1
      }
    }
    Context 'When the forge token is not passed' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Invoke-PdkCommand { Throw 'foo' }
      Mock Command           {}
      Mock Resolve-Path      {$Path}

      It 'Rethrows the exception' {
        { Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeUploadUrl 'https://localhost' -Publish } | Should -Throw 'foo'
      }
    }

    Context 'When the PDK command is unsuccessful' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Invoke-PdkCommand {Throw 'foo'}
      Mock Command           {}
      Mock Resolve-Path      {$Path}

      It 'Rethrows the exception' {
        { Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\' -ForgeToken  'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Publish } | Should -Throw 'foo'
      }
    }
  }
}
