Describe 'Add-PuppetReferenceDocumentation' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      Mock Test-Path         { return $False }
      Mock New-Item          {}
      Mock Invoke-PdkCommand {}

      Initialize-PuppetModule -OutputFolderPath TestDrive:\ -PuppetModuleName Foo

      Add-PuppetReferenceDocumentation -PuppetModuleFolderPath 'TestDrive:\Foo'

      It 'Uses the PDK to generate the REFERENCE.md file' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'bundle exec puppet strings generate --format markdown --out REFERENCE.md'} -Times 1
      }
    }
    Context 'When the PDK command is unsuccessful' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Invoke-PdkCommand { Throw 'foo' }

      It 'Rethrows the exception' {
        { Add-PuppetReferenceDocumentation -PuppetModuleFolderPath TestDrive:\ } | Should -Throw 'foo'
      }
    }
    Context 'When the PuppetModuleFolder path doesnot exist' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Invoke-PdkCommand {}

      It 'Rethrows the exception' {
        { Add-PuppetReferenceDocumentation -PuppetModuleFolderPath TestDrive:\Foo } | Should -Throw "TestDrive:\Foo' because it does not exist"
      }
    }
  }
}