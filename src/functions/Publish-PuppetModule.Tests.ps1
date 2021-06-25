Describe 'Publish-PuppetModule' -Tag 'Unit' {
  BeforeAll {
    $ModuleRootPath = Split-Path -Parent $PSCommandPath |
      Split-Path -Parent
    Import-Module "$ModuleRootPath/Puppet.Dsc.psd1"
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
  }

  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      BeforeAll {
        Mock Test-Path { return $False }
        Mock New-Item {}
        Mock Invoke-PdkCommand {}
        Mock Resolve-Path { $Path }

        Initialize-PuppetModule -OutputFolderPath TestDrive:\ -PuppetModuleName Foo
      }

      It 'Uses the PDK to generate the package' {
        Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeToken 'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Build
        Should -Invoke Invoke-PdkCommand -ParameterFilter { $Command -match 'pdk build' } -Times 1
      }

      It 'Uses the PDK to publish the module' {
        Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeToken 'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Publish
        Should -Invoke Invoke-PdkCommand -ParameterFilter { $Command -match 'pdk release publish' } -Times 1
      }

      It 'Uses the PDK to publish to default url' {
        Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -Publish
        Should -Invoke Invoke-PdkCommand -ParameterFilter { $Command -match 'pdk release publish' } -Times 1
      }
    }
    Context 'When the forge token is not passed' {
      BeforeAll {
        Mock Test-Path { return $True }
        Mock New-Item {}
        Mock Invoke-PdkCommand { Throw 'foo' }
        Mock Command {}
        Mock Resolve-Path { $Path }
      }

      It 'Rethrows the exception' {
        { Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\Foo' -ForgeUploadUrl 'https://localhost' -Publish } | Should -Throw 'foo'
      }
    }

    Context 'When the PDK command is unsuccessful' {
      BeforeAll {
        Mock Test-Path { return $True }
        Mock New-Item {}
        Mock Invoke-PdkCommand { Throw 'foo' }
        Mock Command {}
        Mock Resolve-Path { $Path }
      }

      It 'Rethrows the exception' {
        { Publish-PuppetModule -PuppetModuleFolderPath 'TestDrive:\' -ForgeToken 'abcdefghijk' -ForgeUploadUrl 'https://localhost' -Publish } | Should -Throw 'foo'
      }
    }
  }
}
