Describe 'Initialize-DscResourceCimClass' {
  InModuleScope puppet.dsc {
    Context 'basic functionality' {
      Mock Invoke-DscResource {
        Throw "invalid attempt"
      } -ParameterFilter { $Name -eq 'foo' }
      Mock Invoke-DscResource {
        Throw "Resource $Name was not found"
      } -ParameterFilter { $Name -ne 'foo' }

      It 'does not throw an error if the specified resource is found' {
        {Initialize-DscResourceCimClass -Name 'foo' -ModuleName 'baz' -ModuleVersion '1.2.3'} |
          Should -Not -Throw
      }
      It 'Calls Invoke-DscResource once' {
        Assert-MockCalled -CommandName Invoke-DscResource -Times 1
      }
      It 'throws an error if the specified resource cannot be found' {
        {Initialize-DscResourceCimClass -Name 'bar' -ModuleName 'baz' -ModuleVersion '1.2.3'} |
          Should -Throw
      }
    }
  }
}
