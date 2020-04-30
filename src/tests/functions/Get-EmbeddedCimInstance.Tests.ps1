Describe 'Get-EmbeddedCimInstance' {
  InModuleScope puppet.dsc {
    Context 'basic functionality' {
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='foo';Value='bar' }) }
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='EmbeddedInstance';Value='bar' }) }
        )
      } -ParameterFilter {$ClassName -eq 'foo'}
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='EmbeddedInstance';Value='baz' }) }
        )
      } -ParameterFilter {$ClassName -eq 'bar'}
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='baz';Value='bing' }) }
        )
      } -ParameterFilter {$ClassName -eq 'baz'}

      $Result = Get-EmbeddedCimInstance -ClassName foo
      It 'returns every discovered property for the CIM class' {
        $Result.count | Should -Be 1
        $Result       | Should -Be 'bar'
      }
      It 'Calls Get-CimClass once' {
        Assert-MockCalled -CommandName Get-CimClassPropertiesList -Times 1
      }
      It 'looks in the DSC namespace by default' {
        Assert-MockCalled -CommandName Get-CimClassPropertiesList -Times 1 -ParameterFilter {
          $Namespace -eq 'root\Microsoft\Windows\DesiredStateConfiguration'
        }
      }
    }
    Context 'when run recursively' {
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='foo';Value='bar' }) }
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='EmbeddedInstance';Value='bar' }) }
        )
      } -ParameterFilter {$ClassName -eq 'foo'}
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='EmbeddedInstance';Value='baz' }) }
        )
      } -ParameterFilter {$ClassName -eq 'bar'}
      Mock Get-CimClassPropertiesList {
        @(
          [pscustomobject]@{ Qualifiers = @([pscustomobject]@{ Name='baz';Value='bing' }) }
        )
      } -ParameterFilter {$ClassName -eq 'baz'}

      It 'returns every discovered property for the CIM class and nested CIM Classes' {
        $RecursiveResult = Get-EmbeddedCimInstance -ClassName foo -Recurse
        $RecursiveResult.count | Should -Be 2
        $RecursiveResult[0]    | Should -Be 'bar'
        $RecursiveResult[1]    | Should -Be 'baz'
      }
    }
  }
}
