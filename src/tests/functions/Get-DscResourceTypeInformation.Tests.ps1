Describe "Parameter Handling" {
  InModuleScope puppet.dsc {
    Context "When Passed a DscResourceInfo object" {
      Mock Get-DscResource {}
      Mock Get-DscResourceParameterInfo { return $DscResource.Name }
      $DscResources = [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]@(
        @{Name = 'foo'}
        @{Name = 'bar'}
      )
      
      $Result = $DscResources | Get-DscResourceTypeInformation
      
      It "processes once for each object in the pipeline" {
        Assert-MockCalled Get-DscResourceParameterInfo -Times 2
        $Result[0].ParameterInfo | Should -be $Result[0].Name
      }

      It "never calls Get-DscResource" {
        Assert-MockCalled Get-DscResource -Times 0
      }
    }

    Context "When specifying properties" {
      Context "by name only" {
        Mock Get-DscResourceParameterInfo { return $DscResource.Name }
        Mock Get-DscResource {
          ForEach-Object -InputObject $Name -Process {
            [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
              Name = $Name
            }
          }
        }

        It 'calls Get-DscResource once' {
          $Result = Get-DscResourceTypeInformation -Name foo, bar, baz
          $Result[0].ParameterInfo | Should -Be $Result[0].Name
          Assert-MockCalled Get-DscResource -Times 1
        }
      }

      Context "by name and module" {
        Mock Get-DscResourceParameterInfo { return $DscResource.Name }
        Mock Get-DscResource {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          }
        }
        Mock Get-DscResource {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Module
          }
        }  -ParameterFilter { $null -ne $Module }

        $Result = Get-DscResourceTypeInformation -Name bar -Module foo

        It 'Only searches by module if specified' {
          $Result.ParameterInfo | Should -Be 'foo'
          Assert-MockCalled Get-DscResource -Times 1
          Assert-MockCalled Get-DscResource -Times 1 -ParameterFilter {
            $Module -eq 'foo'
          }
        }
      }

      Context 'via the pipeline' {
        Mock Get-DscResourceParameterInfo { return $DscResource.Name }
        Mock Get-DscResource {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Name
          }
        }  -ParameterFilter { $Name -eq 'foo' }
        Mock Get-DscResource {
          [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]@{
            Name = $Module
          }
        } -ParameterFilter { $Module -eq 'baz' }

        # Objects with name and module properties to pass to the function
        $NameOnly = [PSCustomObject]@{ Name = 'foo' }
        $NameAndModule = [PSCustomObject]@{
          Name = 'bar'
          Module = 'baz'
        }
        $Results = $NameOnly,$NameAndModule | Get-DscResourceTypeInformation

        It 'handles pipeline input by property name' {
          $Results.Count | Should -Be 2
          $Results[0].Name | Should -Be 'foo'
          $Results[1].Name | Should -Be 'baz'
        }

        It 'processes once for each resource found' {
          Assert-MockCalled Get-DscResource -Times 2
          Assert-MockCalled Get-DscResourceParameterInfo -Times 2
        }
      }
    }
  }
}