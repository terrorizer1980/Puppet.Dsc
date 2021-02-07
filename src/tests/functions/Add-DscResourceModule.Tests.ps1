Describe 'Vendoring a DSC module' {
  InModuleScope puppet.dsc {
    Context 'Without AllowPrerelease specified' {
      Mock New-Item -Verifiable
      Mock Save-Module -Verifiable
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target\' }
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      Mock Get-Module
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
      Mock Get-Module
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
    Context 'When a required module is found in the repository' {
      Mock New-Item -Verifiable
      Mock Save-Module -Verifiable
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target\' }
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      Mock Test-Path { $true  } -ParameterFilter { $path -match 'foo' }
      Mock Get-Module { @{ RequiredModules = @("foo") } } -ParameterFilter {$Name -match "SomeDscModule"}
      Mock Get-Module
      Mock Copy-Item
      Mock Get-ChildItem
      Mock Move-Item
      Mock Remove-Item

      Add-DscResourceModule -Name SomeDSCModule -Path 'TestDrive:\target\' -RequiredVersion '1.0.0' -Repository 'PSGallery'

      It 'sees that the required module is vendored' {
        Assert-VerifiableMock
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target\') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled New-Item -Times 1 -ParameterFilter { ($path -eq 'TestDrive:\target_tmp') -and ($ItemType -eq 'Directory') }
        Assert-MockCalled Save-Module -Times 1 -Debug -ParameterFilter {
          ($Name -eq 'SomeDSCModule') `
            -and ($path -eq 'TestDrive:\target_tmp') `
            -and ($RequiredVersion -eq '1.0.0') `
            -and ($Repository -eq 'PSGallery')
        }
        Assert-MockCalled Copy-Item -Times 0
        Assert-MockCalled Remove-Item -Times 1 -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      }
    }
    Context 'When a required module is not found in the repository' {
      Mock New-Item -Verifiable
      Mock Save-Module -Verifiable
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target\' }
      Mock Test-Path { $false } -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      Mock Test-Path { $false  } -ParameterFilter { $path -match 'foo' }
      Mock Get-Module { @{ RequiredModules = @("foo") } } -ParameterFilter {$Name -match "SomeDscModule"}
      Mock Get-Module { @{ Path = "TestDrive:\target_tmp\foo\foo.psd1" } } -ParameterFilter {$Name -match 'foo'}
      Mock Copy-Item
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
        Assert-MockCalled Get-Module -Times 1 -ParameterFilter { $Name -eq 'foo' }
        Assert-MockCalled Copy-Item -Times 1 -ParameterFilter {
          ($Path -match 'foo') `
            -and ($Destination -eq "TestDrive:\target_tmp") `
            -and ($Container -eq $true) `
            -and ($Recurse -eq $true)
        }
        Assert-MockCalled Remove-Item -Times 1 -ParameterFilter { $path -eq 'TestDrive:\target_tmp' }
      }
    }
  }
}
