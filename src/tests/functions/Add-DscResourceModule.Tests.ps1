Describe 'Vendoring a DSC module' {
  InModuleScope puppet.dsc {
    Context 'Without AllowPrerelease specified' {
      Mock New-Item -Verifiable
      Mock Save-Module -Verifiable
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target\' }
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      Mock Get-ChildItem
      Mock Move-Item
      Mock Remove-Item

      Add-DscResourceModule -Name SomeDSCModule -Path 'TestDrive:\target\' -RequiredVersion '1.0.0' -Repository 'PSGallery'

      It 'downloads the latest stable version of the module' {
        Assert-VerifiableMock
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target\') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target_tmp') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled Save-Module -Times 1 -Debug -ParameterFilter {
          ($Name -eq 'SomeDSCModule') `
            -and ($path -eq 'TestDrive:\target_tmp') `
            -and ($RequiredVersion -eq '1.0.0') `
            -and ($Repository -eq 'PSGallery')
        }
        Assert-MockCalled Remove-Item -Times 1 -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      }
    }
    Context 'With AllowPrerelease specified' {
      Mock New-Item -Verifiable
      Mock Save-Module -Verifiable
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target\' }
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      Mock Get-ChildItem
      Mock Move-Item
      Mock Remove-Item

      Add-DscResourceModule -Name SomeDSCModule -Path 'TestDrive:\target\' -RequiredVersion '1.0.0' -Repository 'PSGallery' -AllowPrerelease

      It 'downloads the latest stable version of the module' {
        Assert-VerifiableMock
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target\') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target_tmp') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled Save-Module -Times 1 -Debug -ParameterFilter {
          ($Name -eq 'SomeDSCModule') `
            -and ($path -eq 'TestDrive:\target_tmp') `
            -and ($RequiredVersion -eq '1.0.0') `
            -and ($Repository -eq 'PSGallery') `
            -and ($AllowPrerelease -eq $true)
        }
        Assert-MockCalled Remove-Item -Times 1 -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      }
    }
  }
}
