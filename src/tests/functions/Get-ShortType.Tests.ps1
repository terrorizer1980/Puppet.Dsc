Describe 'Get-ShortType' {
  InModuleScope puppet.dsc {
    Context 'Basic functionality' {
      It 'Returns data types stripped of their outer brackets' {
        Get-ShortType -PropertyType '[string]' | Should -BeExactly 'string'
        Get-ShortType -PropertyType '[string[]]' | Should -BeExactly 'string[]'
      }
    }
  }
}