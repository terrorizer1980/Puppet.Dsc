Describe 'Get-ProviderContent' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      $ExampleDscResource = New-Object -TypeName Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo -Property @{Name = 'FooBarBaz'}

      $Result = Get-ProviderContent -DscResource $ExampleDscResource

      It 'Returns an appropriate representation of a Puppet Resource API type attribute' {
        $ClassDeclaration = 'class Puppet::Provider::DscFoobarbaz::DscFoobarbaz < Puppet::Provider::DscBaseProvider'
        $Result | Should -MatchExactly $ClassDeclaration
      }
    }
    Context 'Verify underscore is removed from ProviderName' {
      $ExampleDscResource = New-Object -TypeName Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo -Property @{Name = 'Foo_Bar'}

      $Result = Get-ProviderContent -DscResource $ExampleDscResource

      It 'Returns an appropriate representation of a Puppet Resource API type attribute' {
        $ClassDeclaration = 'class Puppet::Provider::DscFooBar::DscFooBar < Puppet::Provider::DscBaseProvider'
        $Result | Should -MatchExactly $ClassDeclaration
      }
    }
  }
}