Describe 'Initialize-PuppetModule' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      Mock Test-Path         { return $False }
      Mock New-Item          {}
      Mock Invoke-PdkCommand {}
      Mock Copy-Item         {}
      $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
      $ActualTemplateFolder = Join-Path -Path $ModuleRoot -ChildPath 'internal/templates/static'

      Initialize-PuppetModule -OutputFolderPath TestDrive:\Output -PuppetModuleName Foo

      It 'Creates the output folder if needed' {
        Assert-MockCalled New-Item -ParameterFilter {$Path -eq 'TestDrive:\Output'} -Times 1
      }
      It 'Uses the PDK to scaffold a Puppet module' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'pdk new module'} -Times 1
      }
      It 'Copies the static files over' {
        Assert-MockCalled Copy-Item -ParameterFilter {$Path -eq "$ActualTemplateFolder/*"} -Times 1
      }
    }
    Context 'When the module has already been scaffolded' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Remove-Item       {}
      Mock Invoke-PdkCommand {}
      Mock Copy-Item         {}
      $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
      $ActualTemplateFolder = Join-Path -Path $ModuleRoot -ChildPath 'internal/templates/static'

      Initialize-PuppetModule -OutputFolderPath TestDrive:\ -PuppetModuleName Foo

      It 'Does not recreate the output folder' {
        Assert-MockCalled New-Item -Times 0
      }
      It 'Removes the existing module' {
        Assert-MockCalled Remove-Item -Times 1
      }
      It 'Uses the PDK to scaffold a Puppet module' {
        Assert-MockCalled Invoke-PdkCommand -ParameterFilter {$Command -match 'pdk new module'} -Times 1
      }
      It 'Copies the static files over' {
        Assert-MockCalled Copy-Item -ParameterFilter {$Path -eq "$ActualTemplateFolder/*"} -Times 1
      }
    }
    Context 'When the PDK command is unsuccessful' {
      Mock Test-Path         { return $True }
      Mock New-Item          {}
      Mock Remove-Item       {}
      Mock Invoke-PdkCommand { Throw 'foo' }
      Mock Copy-Item         {}
      It 'Rethrows the exception' {
        { Initialize-PuppetModule -OutputFolderPath TestDrive:\ -PuppetModuleName Bar } | Should -Throw 'foo'
        Assert-MockCalled Copy-Item -Times 0
      }
    }
  }
}