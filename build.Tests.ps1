$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
# . "$here\$sut"
$script = "$here\$sut"

. .\src\internal\functions\Invoke-PdkCommand.ps1

$expected_base = '../bar/powershellget'

Remove-Item $expected_base -Force -Recurse -ErrorAction Ignore

& $script -PowerShellModuleName "PowerShellGet" -PowerShellModuleVersion "2.1.3"  -PuppetModuleAuthor 'testuser' -OutputDirectory "../bar"

# remove test instances left over from a previous run
try {
  Invoke-DscResource -Name 'PSRepository' -Method 'Set' -Property @{Name = 'foo'; Ensure = 'absent' } -ModuleName @{ModuleName = 'C:/ProgramData/PuppetLabs/code/modules/powershellget/lib/puppet_x/dsc_resources/PowerShellGet/PowerShellGet.psd1'; RequiredVersion = '2.1.3' }
}
catch {
  # ignore cleanup errors
}

# cleanup a previously installed test module before the test, ignoring any result
Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module uninstall testuser-powershellget' -SuccessFilterScript { $true }

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
        $_ -match "Build of testuser-powershellget has completed successfully."
      }
    }
    It "is installable" {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module install --verbose pkg/*.tar.gz' -SuccessFilterScript {
        $_ -match "Installing -- do not interrupt"
      }
    }
    It "lists all dsc_psrepository resources" -Pending {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository' -SuccessFilterScript {
        $_ -match "dsc_psrepository {"
      }
    }
    It "shows a specific dsc_psrepository resource" {
      # PSGallery is the default repo always installed
      $Result = Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository title dsc_name=PSGallery' -PassThru -SuccessFilterScript {
        $_ -match "dsc_psrepository { 'title'"
      }
      $Result -match "dsc_name => 'PSGallery'"
    }
    It "shows a specific dsc_psrepository resource with attributes" -Pending {
      # PSGallery is the default repo always installed
      $Result = Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_psrepository title dsc_name=PSGallery' -PassThru -SuccessFilterScript {
        $_ -match "dsc_psrepository { 'title'"
      }
      $Result -match "dsc_name => 'PSGallery'" -and $Result -match "dsc_installationpolicy => 'Trusted'"
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
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply confirm.pp' -ErrorFilterScript { $_ -match 'Notice:.*Dsc_psrepository\[PSGallery\]' }
    }
  }

  Context "when creating a new repository with 'puppet apply'" {
    It "works" {
      # create new arbitrary repo location
      $manifest = 'dsc_psrepository { "Foo":
          dsc_name               => "Foo",
          dsc_ensure             => "Present",
          dsc_sourcelocation     => "c:\\program files",
          dsc_installationpolicy => "Untrusted",
        }'
      Set-Content -Path "$expected_base\new_repo.pp" -Value $manifest
      $Command = 'pdk bundle exec puppet apply --color=false new_repo.pp'
      $SuccessFilterScript = {
        $_ -match 'Creating: Finished'
      }
      $ErrorFilterScript = {
        $_ -match 'Error'
      }
      Invoke-PdkCommand -Path $expected_base -Command $Command -SuccessFilterScript $SuccessFilterScript -ErrorFilterScript $ErrorFilterScript
    }
    # remove previous testcase when enabling this
    It "works with non-canonical elements" {
      # create new arbitrary repo location with a title and non-lowercase source location
      $manifest = 'dsc_psrepository { "bar":
          dsc_name               => "baz",
          dsc_ensure             => "Present",
          dsc_sourcelocation     => "C:\\Program Files (x86)",
          dsc_installationpolicy => "Untrusted",
        }'
      Set-Content -Path "$expected_base\new_repo.pp" -Value $manifest
      $Command = 'pdk bundle exec puppet apply --color=false new_repo.pp'
      $SuccessFilterScript = {
        $_ -match 'Creating: Finished'
      }
      $ErrorFilterScript = {
        $_ -match 'Error'
      }
      Invoke-PdkCommand -Path $expected_base -Command $Command -SuccessFilterScript $SuccessFilterScript -ErrorFilterScript $ErrorFilterScript
    }

    It 'is idempotent' {
      $Command = 'pdk bundle exec puppet apply --color=false new_repo.pp'
      $ErrorFilterScript = {
        $_ -match 'Notice:.*Dsc_psrepository'
      }
      Invoke-PdkCommand -Path $expected_base -Command $Command -ErrorFilterScript $ErrorFilterScript
    }
  }

  Context "when using a PSDscRunAsCredential with 'puppet apply'" {
    # NB: The username/password is re-stated because something with scoping causes them to be inaccessible otherwise.
    BeforeAll {
      $Username = 'Foo'
      $Password = 'This is a pretty long phrase, to be quite honest! :)'
      New-LocalUser -Name $Username -Password (ConvertTo-SecureString -AsPlainText -Force $Password)
      Add-LocalGroupMember -Group Administrators -Member $Username
    }
    AfterAll {
      $Username = 'Foo'
      Remove-LocalGroupMember -Group Administrators -Member $Username
      Remove-LocalUser -Name $Username
    }
    It "works" {
      $Username = 'Foo'
      $Password = 'This is a pretty long phrase, to be quite honest! :)'
      # create new arbitrary repo location
      $manifest = "dsc_psrepository { 'Foo':
          dsc_name               => 'Foo',
          dsc_ensure             => 'Present',
          dsc_sourcelocation     => 'c:\program files',
          dsc_installationpolicy => 'Untrusted',
          dsc_psdscrunascredential => {
            user     => '$Username',
            password => Sensitive('$Password'),
          },
        }"
      Set-Content -Path "$expected_base\new_repo.pp" -Value $manifest
      $Command = 'pdk bundle exec puppet apply --color=false new_repo.pp'
      $SuccessFilterScript = {
        $_ -match 'Creating: Finished'
      }
      $ErrorFilterScript = {
        $_ -match 'Error'
      }
      Invoke-PdkCommand -Path $expected_base -Command $Command -SuccessFilterScript $SuccessFilterScript -ErrorFilterScript $ErrorFilterScript
    }

    It 'is idempotent' {
      $Command = 'pdk bundle exec puppet apply --color=false new_repo.pp'
      $ErrorFilterScript = {
        $_ -match 'Notice:.*Dsc_psrepository'
      }
      Invoke-PdkCommand -Path $expected_base -Command $Command -ErrorFilterScript $ErrorFilterScript
    }
  }

  Context "when a valid manifest causes a run-time error" {
    It "reports the error" {
      # re-use previous repo location, with a new name this will trip up the DSC resource
      $manifest = 'dsc_psrepository { "foo2":
          dsc_name               => "foo2",
          dsc_ensure             => "Present",
          dsc_sourcelocation     => "c:\\program files",
          dsc_installationpolicy => "Untrusted",
        }'
      Set-Content -Path "$expected_base\reuse_repo.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --color=false reuse_repo.pp' -SuccessFilterScript {
        $_ -match "The repository could not be registered because there exists a registered repository with Name"
      }
    }
  }

  Context "with a Sensitive value" {
    It "does not print the value in regular mode" -Pending { }
    It "does not print the value in debug mode" -Pending { }
  }
}


$expected_base = '../bar/nuget'

Remove-Item $expected_base -Force -Recurse -ErrorAction Ignore

If (Test-path C:\nugetlocal) { Remove-Item C:\nugetlocal -recurse -force }
new-item C:\nugetlocal -itemtype directory

& $script -PowerShellModuleName "NuGet" -PowerShellModuleVersion "1.3.3"  -PuppetModuleAuthor 'testuser' -OutputDirectory "../bar"

# remove test instances left over from a previous run
try {
  Invoke-DscResource -Name 'DscNuget' -Method 'Set' -Property @{Name = 'nugetlocal'; Ensure = 'absent' } -ModuleName @{ModuleName = 'C:/ProgramData/PuppetLabs/code/modules/nuget/lib/puppet_x/dsc_resources/nuget/nuget.psd1'; RequiredVersion = '1.3.3' }
}
catch {
  # ignore cleanup errors
}

# cleanup a previously installed test module before the test, ignoring any result
Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module uninstall testuser-nuget' -SuccessFilterScript { $true }

Describe $script {

  It "creates a module" {
    Test-Path "$expected_base\metadata.json" | Should -BeTrue
  }

  It "has a REFERENCE.md" {
    Test-Path "$expected_base\REFERENCE.md" | Should -BeTrue
  }

  It "has a type generated" {
    Test-Path "$expected_base\lib\puppet\type\dsc_nuget.rb" | Should -BeTrue
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
        $_ -match "Build of testuser-nuget has completed successfully."
      }
    }
    It "is installable" {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module install --verbose pkg/*.tar.gz' -SuccessFilterScript {
        $_ -match "Installing -- do not interrupt"
      }
    }
  }

  Context "when passing in invalid values" {
    It "reports the error" {
      { New-PuppetDscModule -PowerShellModuleName "____DoesNotExist____" -OutputDirectory "C:\foo" -ErrorAction Stop } | Should -Throw
    }
  }

  Context "when managing an existing repository with 'puppet apply'" {
    It "doesn't do anything" -Pending {
      Set-Content -Path "$expected_base\confirm_nuget.pp" -Value "dsc_nuget { 'testname': }`n"
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply confirm_nuget.pp' -ErrorFilterScript { $_ -match 'Notice:.*Dsc_nuget\[testname\]' }
    }
  }

  Context "Manage a module with 'puppet apply'" {
    It "works" -Pending {
      # manage a module
      # Ticket opened for the failure.https://tickets.puppetlabs.com/browse/IAC-955
      # Ticket opened for the failure.https://tickets.puppetlabs.com/browse/IAC-953
      # Ticket opened for the failure.https://tickets.puppetlabs.com/browse/IAC-905
      $manifest = 'dsc_nuget { "nugetlocal":
      dsc_name                      => "nugetlocal",
      dsc_packagesource             => "c:\\nugetlocal",
      dsc_allownugetpackagepush     => false,
      dsc_port                      => 81,
      dsc_apikey                    => "testapi",
    }'
      Set-Content -Path "$expected_base\manage_module_nuget.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --color=false manage_module_nuget.pp' -SuccessFilterScript {
        $_ -match "Notice: dsc_nuget\[nugetlocaltesting\]: Updating: Finished"
      }
    }
    # remove previous testcase when enabling this
    It "works with non-canonical elements" -Pending {
      # manage another module with a title and non-lowercase source location
      $manifest = 'dsc_nuget { "nugetlocaltesting":
      dsc_name                      => "nugetlocal",
      dsc_packagesource             => "C:\\nugetlocal",
      dsc_allownugetpackagepush     => false,
      dsc_port                      => 81,
      dsc_apikey                    => "testapi",
    }'
      Set-Content -Path "$expected_base\manage_module_nuget.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --color=false manage_module_nuget.pp' -SuccessFilterScript {
        ($_ -match "Dsc_nuget\[nugetlocaltesting\]/dsc_allownugetpackagepush: dsc_allownugetpackagepush changed  to false") -and ($_ -match "Notice: dsc_nuget\[nugetlocaltesting\]: Creating: Finished")
      }
    }

    It 'is idempotent' {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --color=false manage_module_nuget.pp' -ErrorFilterScript { $_ -match 'Notice:.*Dsc_nuget\[nugetlocaltesting\]' }
    }
  }

  Context "when a valid manifest causes a run-time error" {
    It "reports the error" -Pending {
      # re-use previous repo location, with a new name this will trip up the DSC resource
      $manifest = 'dsc_nuget { "nugetlocalnew":
      dsc_name                      => "nugetlocalnew",
      dsc_packagesource             => "C:\\nugetlocal",
      dsc_allownugetpackagepush     => false,
      dsc_port                      => 81,
      dsc_apikey                    => "testapi",
    }'
      Set-Content -Path "$expected_base\reuse_repo_nuget.pp" -Value $manifest
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet apply --color=false reuse_repo_nuget.pp' -SuccessFilterScript {
        $_ -match "The repository could not be registered because there exists a registered repository with Name"
      }
    }
  }

  Context "test created resource,since no default resources are available" {
    It "lists all dsc_nuget resources" -Pending {
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_nuget' -SuccessFilterScript {
        $_ -match "dsc_nuget {"
      }
    }
    It "shows a specific dsc_nuget resource" -Pending {
      #No default values for local nuget repository
      Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_nuget testname' -SuccessFilterScript {
        $_ -match "dsc_nuget {" -and $_ -match "testname"
      }
    }
    It "shows a specific dsc_nuget resource with attributes" -Pending {
       #No default values for local nuget repository
       Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet resource dsc_nuget testname' -SuccessFilterScript {
         $_ -match "dsc_nuget {" -and $_ -match "testname" -and $_ -match "dsc_packagesource.*=>.*'nugetlocal'"
      }
    }
  }
}
