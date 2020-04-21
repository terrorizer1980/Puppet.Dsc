Describe 'Get-EmbeddedInstance' {
  InModuleScope puppet.dsc {
    Context 'Basic functionality' {
      It "Distinguishes between known and unkowable datatype" {
        Get-ShortType -PropertyType '[string]' | Should -BeExactly 'string'
        Get-ShortType -PropertyType '[string[]]' | Should -BeExactly 'string[]'
      }
    }
  }
}