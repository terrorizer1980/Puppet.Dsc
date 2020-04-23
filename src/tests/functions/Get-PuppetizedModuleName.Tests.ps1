Describe 'Get-PuppetizedModuleName' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      It 'lower-cases module names' {
        Get-PuppetizedModuleName 'xDSCSomething' | Should -MatchExactly "xdscsomething"
      }
      It 'replaces invalid characters' {
        Get-PuppetizedModuleName 'xDSC::Something' | Should -MatchExactly "xdsc__something"
      }
      It 'deals with prefixed numbers' {
        Get-PuppetizedModuleName '7zip' | Should -MatchExactly "a7zip"
      }
    }
  }
}
