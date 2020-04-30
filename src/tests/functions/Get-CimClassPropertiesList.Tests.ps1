Describe 'Get-CimClassPropertiesList' {
  InModuleScope puppet.dsc {
    Context 'basic functionality' {
      Mock Get-CimClass {
        [pscustomobject]@{
          CimClassProperties = @('foo', 'bar', 'baz')
        }
      }
      $Result = Get-CimClassPropertiesList -ClassName Example 
      It 'returns every discovered property for the CIM class' {
        $Result.count | Should -Be 3
        $Result[0]    | Should -Be 'foo'
      }
      It 'Calls Get-CimClass once' {
        Assert-MockCalled -CommandName Get-CimClass -Times 1
      }
      It 'looks in the DSC namespace by default' {
        Assert-MockCalled -CommandName Get-CimClass -Times 1 -ParameterFilter {
          $Namespace -eq 'root\Microsoft\Windows\DesiredStateConfiguration'
        }
      }
    }
  }
}
