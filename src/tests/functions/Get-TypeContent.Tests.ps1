Describe 'Get-TypeContent' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      # We cannot effectively mock out the underlying object, so we need to retrieve a
      # well-known DSC resource at a specific version
      $ExampleResource = Get-DscResource -Name Archive -Module @{
        ModuleName    = 'PSDscResources'
        ModuleVersion = '2.12.0.0'
      }

      Mock Get-TypeParameterContent {}

      $Result = Get-TypeContent -DscResource $ExampleResource

      It 'Returns an appropriate representation of a Puppet Resource API type' {
        $Result | Should -MatchExactly "name: 'dsc_archive'"
        $Result | Should -MatchExactly "dscmeta_resource_friendly_name: 'Archive'"
        $Result | Should -MatchExactly "dscmeta_resource_name: 'MSFT_Archive'"
        $Result | Should -MatchExactly "dscmeta_module_name: 'PSDscResources'"
        $Result | Should -MatchExactly "dscmeta_module_version: '2.12.0.0'"
        $Result | Should -MatchExactly 'The DSC Archive resource type.'
        $Result | Should -MatchExactly 'Automatically generated from version 2.12.0.0'
        $Result | Should -MatchExactly "features: \['simple_get_filter', 'canonicalize'\]"
      }
      It 'Attempts to interpolate the parameter information once' {
        Assert-MockCalled -CommandName Get-TypeParameterContent -Times 1
      }
    }
  }
}