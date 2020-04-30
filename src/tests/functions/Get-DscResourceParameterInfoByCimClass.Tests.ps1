Describe 'Get-DscResourceParameterInfoByCimClass' {
  InModuleScope puppet.dsc {
    # TODO: When Pester 5 comes out we can skip on the context or describe blocks and supply a reason.
    # For now, it just marks as passed but does not run except in an elevated context.
    $RunningElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    Context 'basic functionality' {
      It 'returns parameter info for resources without embedded CIM instances' -Skip:(!$RunningElevated) {
        # We cannot effectively mock out the underlying object, so we need to retrieve a
        # well-known DSC resource at a specific version
        $CimlessDscResource = Get-DscResource -Name Archive -Module @{
          ModuleName    = 'PSDscResources'
          ModuleVersion = '2.12.0.0'
        }
        $CimlessParameterToInspect = Get-DscResourceParameterInfoByCimClass -DscResource $CimlessDscResource |
          Sort-Object -Property Name |
          Select-Object -Last 1
        $CimlessParameterToInspect.Name              | Should -BeExactly 'validate'
        # This function currently cannot discover default values
        $CimlessParameterToInspect.DefaultValue      | Should -BeNullOrEmpty
        $CimlessParameterToInspect.Type              | Should -BeExactly '"Optional[Boolean]"'
        $CimlessParameterToInspect.Help              | Should -MatchExactly '^Specifies whether or not'
        $CimlessParameterToInspect.mandatory_for_get | Should -BeExactly 'false'
        $CimlessParameterToInspect.mandatory_for_set | Should -BeExactly 'false'
        $CimlessParameterToInspect.mof_is_embedded   | Should -BeExactly 'false'
        # This surface is different from Get-DscResourceParameterInfo, but only used for embedded instances
        # which this property is not.
        # $CimlessParameterToInspect.mof_type | Should -BeExactly 'bool'
        $CimlessParameterToInspect.mof_type          | Should -BeExactly 'Boolean'
      }
      It 'returns parameter info for resources with embedded CIM instances' -Skip:(!$RunningElevated) {
        # We cannot effectively mock out the underlying object, so we need to retrieve a
        # well-known DSC resource at a specific version
        $CimfulDscResource = Get-DscResource -Name NTFSAccessEntry -Module @{
          ModuleName    = 'AccessControlDSC'
          ModuleVersion = '1.4.0.0'
        }
        $CimfulParameterToInspect = Get-DscResourceParameterInfoByCimClass -DscResource $CimfulDscResource |
          Sort-Object -Property Name |
          Select-Object -First 1
        $CimfulParameterToInspect.Name              | Should -BeExactly 'accesscontrollist'
        # This function currently cannot discover default values
        $CimfulParameterToInspect.DefaultValue      | Should -BeNullOrEmpty
        $CimfulParameterToInspect.Type              | Should -MatchExactly ([Regex]::Escape('"Array[Struct[{'))
        $CimfulParameterToInspect.Help              | Should -MatchExactly '^Indicates the access control information'
        $CimfulParameterToInspect.mandatory_for_get | Should -BeExactly 'true'
        $CimfulParameterToInspect.mandatory_for_set | Should -BeExactly 'true'
        $CimfulParameterToInspect.mof_is_embedded   | Should -BeExactly 'true'
        $CimfulParameterToInspect.mof_type          | Should -BeExactly 'NTFSAccessControlList[]'
      }
    }
    Context "When the resource can't be found" {
      Mock Initialize-DscResourceCimClass {Throw 'foo'}
      $DscResource = Get-DscResource -Name Archive -Module @{
        ModuleName    = 'PSDscResources'
        ModuleVersion = '2.12.0.0'
      }
      It 'stops processing' -Skip:(!$RunningElevated) {
        { Get-DscResourceParameterInfoByCimClass -DscResource $DscResource } | Should -Throw
      }
    }
  }
}
