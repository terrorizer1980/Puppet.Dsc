Describe 'Get-TypeParameterContent' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      $ExampleParameterInfo = [PSCustomObject[]]@(
        @{
          Name              = 'apple'
          DefaultValue      = $null
          Type              = "Optional[Boolean]"
          Help              = "Some string of help content`nSplit on a new line"
          mandatory_for_get = 'false'
          mandatory_for_set = 'false'
          mof_is_embedded   = 'false'
          mof_type          = 'bool'
        },
        @{
          Name              = 'banana'
          DefaultValue      = 'foo'
          Type              = "Enum['foo', 'bar']"
          Help              = $null
          mandatory_for_get = 'true'
          mandatory_for_set = 'true'
          mof_is_embedded   = 'false'
          mof_type          = 'string'
        }
      )

      $Result = Get-TypeParameterContent -ParameterInfo $ExampleParameterInfo

      It 'Returns an appropriate representation of a Puppet Resource API type attribute' {
        $Result[0] | Should -MatchExactly 'dsc_apple: {'
        $Result[0] | Should -MatchExactly 'Some string of help content'
        $Result[0] | Should -MatchExactly 'mandatory_for_get: false,'
        $Result[0] | Should -MatchExactly 'mandatory_for_set: false,'
        $Result[0] | Should -MatchExactly "mof_type: 'bool',"
        $Result[0] | Should -MatchExactly 'mof_is_embedded: false,'
        $Result[1] | Should -MatchExactly 'dsc_banana: {'
        $Result[1] | Should -MatchExactly 'desc: %q{},'
        $Result[1] | Should -MatchExactly 'behaviour: :namevar,'
        $Result[1] | Should -MatchExactly 'mandatory_for_get: true,'
        $Result[1] | Should -MatchExactly 'mandatory_for_set: true,'
        $Result[1] | Should -MatchExactly "mof_type: 'string',"
        $Result[1] | Should -MatchExactly 'mof_is_embedded: false,'
      }
    }
  }
}