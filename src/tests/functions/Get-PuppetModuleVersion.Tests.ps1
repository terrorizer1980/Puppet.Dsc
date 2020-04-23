Describe 'Get-PuppetModuleVersion' {
  InModuleScope puppet.dsc {
    Context 'Basic functionality' {
      It 'Returns a valid Puppet module version' {
        Get-PuppetModuleVersion -Version '1.2.3'   | Should -BeExactly '1.2.3-0-0'
        Get-PuppetModuleVersion -Version '1.2.3.0' | Should -BeExactly '1.2.3-0-0'
        Get-PuppetModuleVersion -Version '1.2.3.1' | Should -BeExactly '1.2.3-1-0'
        Get-PuppetModuleVersion -Version '1.2.3.1' -Build 1 | Should -BeExactly '1.2.3-1-1'
      }
    }
  }
}
