$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
# . "$here\$sut"
$script = "$here\$sut"

. .\src\internal\functions\Invoke-PdkCommand.ps1

# $expected_base = 'import\powershellget'
$expected_base = '../bar/powershellget'

Remove-Item $expected_base -Force -Recurse -ErrorAction Ignore

& $script -PowerShellModuleName "PowerShellGet" -PowerShellModuleVersion "2.1.3"  -OutputDirectory "../bar"

# remove test instances left over from a previous run
try {
  Invoke-DscResource -Name 'PSRepository' -Method 'Set' -Property @{Name = 'foo'; Ensure = 'absent' } -ModuleName @{ModuleName = 'C:/ProgramData/PuppetLabs/code/modules/powershellget/lib/puppet_x/dsc_resources/PowerShellGet/PowerShellGet.psd1'; RequiredVersion = '2.1.3' }
}
catch {
  # ignore cleanup errors
}

# cleanup a previously installed test module before the test, ignoring any result
Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module uninstall vagrant-powershellget' -SuccessFilterScript { $true }

Describe $script {

  It "creates a module" {
    Test-Path "$expected_base\metadata.json" | Should -BeTrue
  }

  It "has a REFERENCE.md" {
    Test-Path "$expected_base\REFERENCE.md" | Should -BeTrue
  }

  It "has a type generated" {
    Test-Path "$expected_base\lib\puppet\type\dsc_psmodule.rb" | Should -BeTrue
  }

  Context "when inside the module" {
    It '`pdk validate metadata` runs successfully' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk validate metadata' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
    }
    It '`pdk validate puppet` runs successfully' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk validate puppet' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
    }
    It '`pdk validate tasks` runs successfully' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk validate tasks' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
    }
    It '`pdk validate yaml` runs successfully' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk validate yaml' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
    }
    It "is buildable" {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk build' -SuccessFilterScript {
        $_ -match "Build of vagrant-powershellget has completed successfully."
      }
    }
    It "is installable" {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module install --verbose pkg/*.tar.gz' -SuccessFilterScript {
        $_ -match "Installing -- do not interrupt"
      }
    }
    It "lists all dsc_psrepository resources" -Pending {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository --verbose --debug --trace' -SuccessFilterScript {
        $_ -match "dsc_psrepository {"
      }
    }
    It "shows a specific dsc_psrepository resource" {
      # PSGallery is the default repo always installed
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository PSGallery --verbose --debug --trace' -SuccessFilterScript {
        $_ -match "dsc_psrepository {" -and $_ -match "PSGallery"
      }
    }
    It "shows a specific dsc_psrepository resource with attributes" -Pending {
      # PSGallery is the default repo always installed
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository PSGallery --verbose --debug --trace' -SuccessFilterScript {
        $_ -match "dsc_psrepository {" -and $_ -match "PSGallery" -and $_ -match "dsc_installationpolicy.*=>.*'trusted'"
      }
    }
  }

  Context "when passing in invalid values" {
    It "reports the error" {
      { New-PuppetDscModule -PowerShellModuleName "____DoesNotExist____" -OutputDirectory "C:\foo" -ErrorAction Stop } | Should -Throw
    }
  }

  Context "when managing an existing repository with 'puppet apply'" {
    It "doesn't do anything" {
      # PSGallery is the default repo always installed
      Set-Content -Path "$expected_base\confirm.pp" -Value "dsc_psrepository { 'PSGallery': }`n"
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --verbose --debug --trace confirm.pp' -ErrorFilterScript { $_ -match 'Notice:.*Dsc_psrepository\[PSGallery\]' }
    }
  }

  Context "when creating a new repository with 'puppet apply'" {
    It "works" {
      # create new arbitrary repo location
      $manifest = 'dsc_psrepository { "foo":
          dsc_ensure             => present,
          dsc_sourcelocation     => "c:\\program files",
          dsc_installationpolicy => untrusted,
        }'
      Set-Content -Path "$expected_base\new_repo.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --verbose --debug --trace --color=false new_repo.pp' -SuccessFilterScript {
        # TODO: fix this to match closer to the changes
        # ($_ -match "Dsc_psrepository\[foo\]/dsc_installationpolicy: dsc_installationpolicy changed  to 'untrusted'") -and ($_ -match "Notice: dsc_psrepository\[foo\]: Updating: Finished")
        $_ -match "Notice: dsc_psrepository\[foo\]: Updating: Finished"
      }
    }
    # remove previous testcase when enabling this
    It "works with non-canonical elements" -Pending {
      # create new arbitrary repo location with a title and non-lowercase source location
      $manifest = 'dsc_psrepository { "bar"
          dsc_name               => "foo":
          dsc_ensure             => present,
          dsc_sourcelocation     => "C:\\Program Files",
          dsc_installationpolicy => untrusted,
        }'
      Set-Content -Path "$expected_base\new_repo.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --verbose --debug --trace --color=false new_repo.pp' -SuccessFilterScript {
        # reminder: this -match didn't work previously, even though it should.
        ($_ -match "Dsc_psrepository\[foo\]/dsc_installationpolicy: dsc_installationpolicy changed  to 'untrusted'") -and ($_ -match "Notice: dsc_psrepository\[foo\]: Creating: Finished")
      }
    }

    It 'is idempotent' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --verbose --debug --trace --color=false new_repo.pp' -ErrorFilterScript { $_ -match 'Notice:.*Dsc_psrepository\[foo\]' }
    }
  }

  Context "when a valid manifest causes a run-time error" {
    It "reports the error" {
      # re-use previous repo location, with a new name this will trip up the DSC resource
      $manifest = 'dsc_psrepository { "foo2":
          dsc_ensure             => present,
          dsc_sourcelocation     => "c:\\program files",
          dsc_installationpolicy => untrusted,
        }'
      Set-Content -Path "$expected_base\reuse_repo.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --verbose --debug --trace --color=false reuse_repo.pp' -SuccessFilterScript {
        $_ -match "The repository could not be registered because there exists a registered repository with Name"
      }
    }
  }

  Context "with a Sensitive value" {
    It "does not print the value in regular mode" -Pending { }
    It "does not print the value in debug mode" -Pending { }
  }
}
