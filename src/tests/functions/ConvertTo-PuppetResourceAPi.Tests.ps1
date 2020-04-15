Describe "ConvertTo-PuppetResourceApi" {
  InModuleScope puppet.dsc {
    Context "When Passed a DscResourceInfo object" {
      Mock Get-DscResourceTypeInformation {
        $DSCResource | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $DscResource.Name -PassThru
      }
      Mock Get-TypeContent     { return "Type: $($DscResource.Name)" }
      Mock Get-ProviderContent { return "Provider: $($DscResource.Name)" }

      $DscResources = [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]@(
        @{Name = 'FooResource'}
        @{Name = 'BarResource'}
      )
      
      $Result = $DscResources | ConvertTo-PuppetResourceApi
      
      It "processes once for each object in the pipeline" {
        Assert-MockCalled Get-DscResourceTypeInformation -Times 2
        $Result[0].Name | Should -BeExactly 'dsc_fooresource'
        $Result[0].RubyFileName | Should -BeExactly 'dsc_fooresource.rb'
        $Result[0].Type | Should -BeExactly 'Type: FooResource'
        $Result[0].Provider | Should -BeExactly 'Provider: FooResource'
        $Result[1].Name | Should -BeExactly 'dsc_barresource'
      }
    }

    Context "When specifying properties" {
      Context "by name only" {
        Mock Get-DscResourceTypeInformation {
          $Name | ForEach-Object -Process {
            [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
              Name = $_
            }
          } | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $_ -PassThru
        }
        Mock Get-TypeContent     { return "Type: $($DscResource.Name)" }
        Mock Get-ProviderContent { return "Provider: $($DscResource.Name)" }

        $Result = ConvertTo-PuppetResourceApi -Name 'Foo', 'Bar', 'Baz'

        It 'calls Get-DscResourceTypeInformation once' {
          Assert-MockCalled Get-DscResourceTypeInformation -Times 1
        }

        It 'converts the resource effectively' {
          $Result[0].Name         | Should -BeExactly 'dsc_foo'
          $Result[0].RubyFileName | Should -BeExactly 'dsc_foo.rb'
          $Result[0].Type         | Should -BeExactly 'Type: Foo'
          $Result[0].Provider     | Should -BeExactly 'Provider: Foo'
          $Result[1].Name         | Should -BeExactly 'dsc_bar'
          $Result[2].Name         | Should -BeExactly 'dsc_baz'
        }
      }

      Context "by name and module" {
        Mock Get-TypeContent     { return "Type: $($DscResource.ParameterInfo)" }
        Mock Get-ProviderContent { return "Provider: $($DscResource.ParameterInfo)" }
        Mock Get-DscResourceTypeInformation {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          } | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $Name -PassThru
        }
        Mock Get-DscResourceTypeInformation {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          } | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $Module -PassThru
        } -ParameterFilter { $null -ne $Module }

        $Result = ConvertTo-PuppetResourceApi -Name Bar -Module Foo

        It 'Only searches by module if specified' {
          $Result.Name | Should -BeExactly 'dsc_bar'
          $Result.RubyFileName | Should -BeExactly 'dsc_bar.rb'
          $Result.Type | Should -BeExactly 'Type: Foo'
          $Result.Provider | Should -BeExactly 'Provider: Foo'
          Assert-MockCalled Get-DscResourceTypeInformation -Times 1
          Assert-MockCalled Get-DscResourceTypeInformation -Times 1 -ParameterFilter {
            $Module -eq 'Foo'
          }
        }
      }

      Context 'via the pipeline' {
        Mock Get-TypeContent     { return "Type: $($DscResource.ParameterInfo)" }
        Mock Get-ProviderContent { return "Provider: $($DscResource.ParameterInfo)" }
        Mock Get-DscResourceTypeInformation {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          } | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $Name -PassThru
        } -ParameterFilter {$Name -eq 'Foo'}
        Mock Get-DscResourceTypeInformation {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          } | Add-Member -MemberType NoteProperty -Name ParameterInfo -Value $Module -PassThru
        } -ParameterFilter { $Module -eq 'Baz' }

        # Objects with name and module properties to pass to the function
        $NameOnly = [PSCustomObject]@{ Name = 'Foo' }
        $NameAndModule = [PSCustomObject]@{
          Name = 'Bar'
          Module = 'Baz'
        }

        $Results = $NameOnly,$NameAndModule | ConvertTo-PuppetResourceApi

        It 'handles pipeline input by property name' {
          $Results.Count | Should -Be 2
          $Results[0].Name         | Should -BeExactly 'dsc_foo'
          $Results[0].RubyFileName | Should -BeExactly 'dsc_foo.rb'
          $Results[0].Type         | Should -BeExactly 'Type: Foo'
          $Results[0].Provider     | Should -BeExactly 'Provider: Foo'
          $Results[1].Name         | Should -BeExactly 'dsc_bar'
          $Results[1].RubyFileName | Should -BeExactly 'dsc_bar.rb'
          $Results[1].Type         | Should -BeExactly 'Type: Baz'
          $Results[1].Provider     | Should -BeExactly 'Provider: Baz'
        }

        It 'processes once for each resource found' {
          Assert-MockCalled Get-DscResourceTypeInformation -Times 2
          Assert-MockCalled Get-TypeContent -Times 2
        }
      }
    }
  }
}