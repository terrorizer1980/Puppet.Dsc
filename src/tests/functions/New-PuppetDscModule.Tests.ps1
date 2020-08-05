Describe "New-PuppetDscModule" {
  InModuleScope puppet.dsc {
    Context "Basic functionality: Elevated" {
      Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
      Mock ConvertTo-CanonicalPuppetAuthorName {$AuthorName}
      Mock Initialize-PuppetModule {}
      Mock Test-RunningElevated { return $true }
      Mock Test-SymLinkedItem   { return $false }
      Mock Add-DscResourceModule {}
      Mock Resolve-Path {$Path}
      Mock Update-PuppetModuleMetadata {}
      Mock Update-PuppetModuleFixture {}
      Mock Update-PuppetModuleReadme {}
      Mock Set-PSModulePath {}
      Mock Get-DscResource {
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]@(
          @{Name = 'FooResource'}
          @{Name = 'BarResource'}
        )
      }
      Mock ConvertTo-PuppetResourceApi {
        $Name = $DscResource.Name.toLower()
        [pscustomobject]@{
          Name         = $Name
          RubyFileName = "$Name.rb"
          Type         = "$Name type"
          Provider     = "$Name provider"
        }
      }
      Mock Test-Path {$true}
      Mock Out-Utf8File {}
      Mock Add-PuppetReferenceDocumentation {}
      Mock Get-Item {}
      $ExpectedOutputDirectory = Join-Path -Path (Get-location) -ChildPath 'import'

      New-PuppetDscModule -PowerShellModuleName Foo

      It 'Does not canonicalize the author name because none was specified' {
        Assert-MockCalled ConvertTo-CanonicalPuppetAuthorName -Times 0
      }
      It 'Scaffolds the initial Puppet module' {
        Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
          $OutputFolderPath -eq $ExpectedOutputDirectory -and
          $PuppetModuleName -ceq 'foo'
        } -Times 1
      }
      It 'Vendors the PowerShell module' {
        Assert-MockCalled Add-DscResourceModule -ParameterFilter {
          $Name -ceq 'Foo' -and
          $Path -match 'import(/|\\)foo' -and
          $Repository -match 'PSGallery'
        } -Times 1
      }
      It 'Updates the Puppet metadata based on the PowerShell metadata' {
        Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
          $PuppetModuleFolderPath       -match 'import(/|\\)foo' -and
          $PowerShellModuleManifestPath -match 'import(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
        }
      }
      It 'Updates the fixture file with the necessary dependencies' {
        Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
          $PuppetModuleFolderPath -match 'import(/|\\)foo'
        } -Times 1
      }
      It 'Updates the Puppet README based on the PowerShell metadata' {
        Assert-MockCalled Update-PuppetModuleReadme -ParameterFilter {
          $PuppetModuleFolderPath       -match 'import(/|\\)foo' -and
          $PowerShellModuleManifestPath -match 'import(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
        }
      }
      It 'Temporarily sets the PSModulePath' {
        Assert-MockCalled Set-PSModulePath -ParameterFilter {
          $Path -match 'import(/|\\)foo\S*dsc_resources$'
        } -Times 1
      }
      It 'Retrieves the DSC resources for processing' {
        Assert-MockCalled Get-DscResource -ParameterFilter {
          $Module -ceq 'Foo'
        } -Times 1
      }
      It 'Converts the DSC resources to the Puppet Resource API representations' {
        Assert-MockCalled ConvertTo-PuppetResourceApi -Times 1
      }
      It 'Writes a type and provider file for each discovered DSC resource' {
        Assert-MockCalled Out-Utf8File -Times 4
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $InputObject -match 'type$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $InputObject -match 'provider$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $Path -cmatch 'fooresource\.rb$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $Path -cmatch 'barresource\.rb$'
        } -Times 2
      }
      It 'Generates the REFERENCE.md file' {
        Assert-MockCalled Add-PuppetReferenceDocumentation -ParameterFilter {
          $PuppetModuleFolderPath -match 'import(/|\\)foo'
        } -Times 1
      }
      It 'Sets the PSModulePath back' {
        Assert-MockCalled Set-PSModulePath -ParameterFilter {
          $Path -eq $env:PSModulePath
        } -Times 1
      }
    }
    Context "Basic functionality: Unelevated" {
      Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
      Mock ConvertTo-CanonicalPuppetAuthorName {$AuthorName}
      Mock Initialize-PuppetModule {}
      Mock Write-PSFMessage {}
      Mock Test-RunningElevated { return $false }
      Mock Test-SymLinkedItem {}
      Mock Add-DscResourceModule {}
      Mock Resolve-Path {$Path}
      Mock Update-PuppetModuleMetadata {}
      Mock Update-PuppetModuleFixture {}
      Mock Update-PuppetModuleReadme {}
      Mock Set-PSModulePath {}
      Mock Get-DscResource {
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]@(
          @{Name = 'FooResource'}
          @{Name = 'BarResource'}
        )
      }
      Mock ConvertTo-PuppetResourceApi {
        $Name = $DscResource.Name.toLower()
        [pscustomobject]@{
          Name         = $Name
          RubyFileName = "$Name.rb"
          Type         = "$Name type"
          Provider     = "$Name provider"
        }
      }
      Mock Test-Path {$true}
      Mock Out-Utf8File {}
      Mock Add-PuppetReferenceDocumentation {}
      Mock Get-Item {}
      $ExpectedOutputDirectory = Join-Path -Path (Get-location) -ChildPath 'import'

      New-PuppetDscModule -PowerShellModuleName Foo -PuppetModuleAuthor 'foobar'

      It 'Warns that the function is running in an unelevated context' {
        Assert-MockCalled Write-PSFMessage -ParameterFilter {$Message -match '^Running un-elevated' } -Times 1
      }
      It 'Canonicalizes the author name' {
        Assert-MockCalled ConvertTo-CanonicalPuppetAuthorName -Times 1
      }
      It 'Scaffolds the initial Puppet module' {
        Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
          $OutputFolderPath -eq $ExpectedOutputDirectory -and
          $PuppetModuleName -ceq 'foo'
        } -Times 1
      }
      It 'Vendors the PowerShell module' {
        Assert-MockCalled Add-DscResourceModule -ParameterFilter {
          $Name -ceq 'Foo' -and
          $Path -match 'import(/|\\)foo' -and
          $Repository -match 'PSGallery'
        } -Times 1
      }
      It 'Updates the Puppet metadata based on the PowerShell metadata' {
        Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
          $PuppetModuleFolderPath       -match 'import(/|\\)foo' -and
          $PowerShellModuleManifestPath -match 'import(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
        }
      }
      It 'Updates the fixture file with the necessary dependencies' {
        Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
          $PuppetModuleFolderPath -match 'import(/|\\)foo'
        } -Times 1
      }
      It 'Temporarily sets the PSModulePath' {
        Assert-MockCalled Set-PSModulePath -ParameterFilter {
          $Path -match 'import(/|\\)foo\S*dsc_resources$'
        } -Times 1
      }
      It 'Retrieves the DSC resources for processing' {
        Assert-MockCalled Get-DscResource -ParameterFilter {
          $Module -ceq 'Foo'
        } -Times 1
      }
      It 'Converts the DSC resources to the Puppet Resource API representations' {
        Assert-MockCalled ConvertTo-PuppetResourceApi -Times 1
      }
      It 'Writes a type and provider file for each discovered DSC resource' {
        Assert-MockCalled Out-Utf8File -Times 4
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $InputObject -match 'type$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $InputObject -match 'provider$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $Path -cmatch 'fooresource\.rb$'
        } -Times 2
        Assert-MockCalled Out-Utf8File -ParameterFilter {
          $Path -cmatch 'barresource\.rb$'
        } -Times 2
      }
      It 'Generates the REFERENCE.md file' {
        Assert-MockCalled Add-PuppetReferenceDocumentation -ParameterFilter {
          $PuppetModuleFolderPath -match 'import(/|\\)foo'
        } -Times 1
      }
      It 'Sets the PSModulePath back' {
        Assert-MockCalled Set-PSModulePath -ParameterFilter {
          $Path -eq $env:PSModulePath
        } -Times 1
      }
    }
    Context 'Parameter Validation'{
      Context 'Output Directory' {
        Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
        Mock Initialize-PuppetModule {}
        Mock Test-RunningElevated { return $true }
        Mock Test-SymLinkedItem   { return $false }
        Mock Add-DscResourceModule {}
        Mock New-Item {$Path}
        Mock Resolve-Path {$Path}
        Mock Update-PuppetModuleMetadata {}
        Mock Update-PuppetModuleFixture {}
        Mock Update-PuppetModuleReadme {}
        Mock Set-PSModulePath {}
        Mock Get-DscResource {}
        Mock ConvertTo-PuppetResourceApi {}
        Mock Test-Path {$true}
        Mock Out-Utf8File {}
        Mock Add-PuppetReferenceDocumentation {}
        Mock Get-Item {}

        New-PuppetDscModule -PowerShellModuleName Foo -OutputDirectory  TestDrive:\Bar -Repository FooRepo
        It 'Respects the specified path' {
          Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
            $OutputFolderPath -eq 'TestDrive:\Bar' -and
            $PuppetModuleName -ceq 'foo'
          } -Times 1
          Assert-MockCalled Add-DscResourceModule -ParameterFilter {
            $Name -ceq 'Foo' -and
            $Path -match 'bar(/|\\)foo' -and
            $Repository -match 'FooRepo'
          } -Times 1
          Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
            $PuppetModuleFolderPath       -match 'bar(/|\\)foo' -and
            $PowerShellModuleManifestPath -match 'bar(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
          }
          Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
            $PuppetModuleFolderPath -match 'bar(/|\\)foo'
          } -Times 1
          Assert-MockCalled Set-PSModulePath -ParameterFilter {
            $Path -match 'bar(/|\\)foo\S*dsc_resources$'
          } -Times 1
          Assert-MockCalled Add-PuppetReferenceDocumentation -ParameterFilter {
            $PuppetModuleFolderPath -eq 'TestDrive:\Bar\foo'
          } -Times 1
        }
      }
      Context 'Puppet Module Name' {
        Context 'Output Directory' {
          Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
          Mock Initialize-PuppetModule {}
          Mock Test-RunningElevated { return $true }
          Mock Test-SymLinkedItem   { return $false }
          Mock Add-DscResourceModule {}
          Mock New-Item {$Path}
          Mock Resolve-Path {$Path}
          Mock Update-PuppetModuleMetadata {}
          Mock Update-PuppetModuleFixture {}
          Mock Update-PuppetModuleReadme {}
          Mock Set-PSModulePath {}
          Mock Get-DscResource {}
          Mock ConvertTo-PuppetResourceApi {}
          Mock Test-Path {$true}
          Mock Out-Utf8File {}
          Mock Add-PuppetReferenceDocumentation {}
          Mock Get-Item {}

          New-PuppetDscModule -PowerShellModuleName Foo -OutputDirectory  TestDrive:\Bar
          It 'Respects the specified path' {
            Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
              $OutputFolderPath -eq 'TestDrive:\Bar' -and
              $PuppetModuleName -ceq 'foo'
            } -Times 1
            Assert-MockCalled Add-DscResourceModule -ParameterFilter {
              $Name -ceq 'Foo' -and
              $Path -match 'bar(/|\\)foo' -and
              $Repository -match 'PSGallery'
            } -Times 1
            Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
              $PuppetModuleFolderPath       -match 'bar(/|\\)foo' -and
              $PowerShellModuleManifestPath -match 'bar(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
            }
            Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
              $PuppetModuleFolderPath -match 'bar(/|\\)foo'
            } -Times 1
            Assert-MockCalled Set-PSModulePath -ParameterFilter {
              $Path -match 'bar(/|\\)foo\S*dsc_resources$'
            } -Times 1
          }
        }

      }
      Context 'Function Output' {
        Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
        Mock Initialize-PuppetModule {}
        Mock Test-RunningElevated { return $true }
        Mock Test-SymLinkedItem   { return $false }
        Mock Add-DscResourceModule {}
        Mock Resolve-Path {$Path}
        Mock Update-PuppetModuleMetadata {}
        Mock Update-PuppetModuleFixture {}
        Mock Update-PuppetModuleReadme {}
        Mock Set-PSModulePath {}
        Mock Get-DscResource {}
        Mock ConvertTo-PuppetResourceApi {}
        Mock Test-Path {$true}
        Mock Out-Utf8File {}
        Mock Add-PuppetReferenceDocumentation {}
        Mock New-Item { 'TestDrive:\OutputDirectory' }
        Mock Get-Item {'Output'}

        $ExpectNoOutputResult = New-PuppetDscModule -PowerShellModuleName Foo
        $ExpectOutputResult   = New-PuppetDscModule -PowerShellModuleName Foo -PassThru
        It 'Only returns output if PassThru is specified' {
          Assert-MockCalled Get-Item -Times 1
          $ExpectNoOutputResult | Should -BeNullOrEmpty
          $ExpectOutputResult   | Should -Be 'Output'
        }
      }
      Context 'Puppet Module Naming' {
        Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
        Mock Initialize-PuppetModule {}
        Mock Test-RunningElevated { return $true }
        Mock Test-SymLinkedItem   { return $false }
        Mock Add-DscResourceModule {}
        Mock Resolve-Path {$Path}
        Mock Update-PuppetModuleMetadata {}
        Mock Update-PuppetModuleFixture {}
        Mock Update-PuppetModuleReadme {}
        Mock Set-PSModulePath {}
        Mock Get-DscResource {}
        Mock ConvertTo-PuppetResourceApi {}
        Mock Test-Path {$true}
        Mock Out-Utf8File {}
        Mock Add-PuppetReferenceDocumentation {}
        Mock Get-Item {$Path}

        $UnspecifiedResult = New-PuppetDscModule -PowerShellModuleName Foo -PassThru
        $SpecifiedResult   = New-PuppetDscModule -PowerShellModuleName Foo -PassThru -PuppetModuleName bar_baz
        It 'Puppetizes the PowerShell module name if a Puppet module name is not specified' {
          Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
            $PuppetModuleName -ceq 'foo'
          } -Times 1
          Assert-MockCalled Add-DscResourceModule -ParameterFilter {
            $Path -match 'import(/|\\)foo' -and
            $Repository -match 'PSGallery'
          } -Times 1
          Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
            $PuppetModuleFolderPath       -match 'import(/|\\)foo' -and
            $PowerShellModuleManifestPath -match 'import(/|\\)foo\S+(/|\\)foo(/|\\)foo.psd1'
          }
          Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
            $PuppetModuleFolderPath -match 'import(/|\\)foo'
          } -Times 1
          Assert-MockCalled Set-PSModulePath -ParameterFilter {
            $Path -match 'import(/|\\)foo\S*dsc_resources$'
          } -Times 1
        }
        It 'Uses the Puppet module name if specified' {
          Assert-MockCalled Initialize-PuppetModule -ParameterFilter {
            $PuppetModuleName -ceq 'bar_baz'
          } -Times 1
          Assert-MockCalled Add-DscResourceModule -ParameterFilter {
            $Path -match 'import(/|\\)bar_baz' -and
            $Repository -match 'PSGallery'
          } -Times 1
          Assert-MockCalled Update-PuppetModuleMetadata -ParameterFilter {
            $PuppetModuleFolderPath       -match 'import(/|\\)bar_baz' -and
            $PowerShellModuleManifestPath -match 'import(/|\\)bar_baz\S+(/|\\)foo(/|\\)foo.psd1'
          }
          Assert-MockCalled Update-PuppetModuleFixture -ParameterFilter {
            $PuppetModuleFolderPath -match 'import(/|\\)bar_baz'
          } -Times 1
          Assert-MockCalled Set-PSModulePath -ParameterFilter {
            $Path -match 'import(/|\\)bar_baz\S*dsc_resources$'
          } -Times 1
        }
      }
    }
    Context 'Error Handling' {
      Context 'When an intermediate step fails' {
        Mock Get-PuppetizedModuleName {$Name.ToLowerInvariant()}
        Mock Test-RunningElevated { return $true }
        Mock Test-SymLinkedItem   { return $false }
        Mock Initialize-PuppetModule {Throw 'Failure!'}
        Mock Set-PSModulePath {}
        $UncalledFunctions = @(
          'Add-DscResourceModule'
          'Update-PuppetModuleMetadata'
          'Update-PuppetModuleFixture'
          'Get-DscResource'
          'ConvertTo-PuppetResourceApi'
          'Test-Path'
          'Out-Utf8File'
          'Add-PuppetReferenceDocumentation'
          'Get-Item'
        )
        ForEach ($Function in $UncalledFunctions) {
          Mock -CommandName $Function {}
        }

        It 'surfaces the underlying error and stops executing' {
          { New-PuppetDscModule -PowerShellModuleName Foo } | Should -Throw 'Failure!'
          ForEach ($Function in $UncalledFunctions) {
            Assert-MockCalled -CommandName $Function -Times 0
          }
          # Cleanup always runs
          Assert-MockCalled Set-PSModulePath -ParameterFilter {
            $Path -eq $Env:PSModulePath
          } -Times 1
        }
      }
      Context 'When running elevated and the output folder is in a symlinked path' {
        Mock Test-RunningElevated { return $true }
        Mock Test-SymLinkedItem   { return $true }

        It 'throws an explanatory exception' {
          { New-PuppetDscModule -PowerShellModuleName Foo } |
            Should -Throw -PassThru |
            Select-Object -ExpandProperty Exception |
            Should -Match "The specified output folder '.+' has a symlink in the path; CIM class parsing will not work in a symlinked folder, specify another path"
        }
      }
    }
  }
}
