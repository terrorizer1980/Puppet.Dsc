Describe 'ConvertTo-UnescapedJson' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      # We cannot effectively mock out the underlying object, so we need to retrieve a
      # well-known DSC resource at a specific version
      $ExampleObject = @{
        VersionRequirement = '>= 6.0.0 < 7.0.0'
      }

      $EscapedResult   = $ExampleObject | ConvertTo-Json
      $UnescapedResult = $ExampleObject | ConvertTo-UnescapedJson

      It 'Converts the object to JSON without unicode escapes' {
        $EscapedResult   | Should -Not -Match '(>=|<)'
        $UnescapedResult | Should -Match '>= 6\.0\.0 < 7\.0\.0'
      }
    }
  }
}