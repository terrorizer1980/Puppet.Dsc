BeforeAll {
  $ModuleRootPath = Split-Path -Parent $PSCommandPath |
    Split-Path -Parent |
    Split-Path -Parent
  Import-Module "$ModuleRootPath/Puppet.Dsc.psd1"
  . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe 'Get-ReadmeContent' {
  InModuleScope Puppet.Dsc {
    Context 'Basic verification' {
      BeforeAll {
        $Parameters = @{
          PowerShellModuleName        = 'Foo.Bar'
          PowerShellModuleDescription = 'Foo and bar and baz!'
          PowerShellModuleGalleryUri  = 'https://powershellgallery.com/Foo.Bar/1.0.0'
          PowerShellModuleProjectUri  = 'https://github.com/Baz/Foo.Bar'
          PowerShellModuleVersion     = '1.0.0'
          PuppetModuleName            = 'foo_bar'
        }
        $Result = Get-ReadmeContent @Parameters
      }
      It 'Has the puppet module name as the title' {
        $Result | Should -MatchExactly "# $($Parameters.PuppetModuleName)"
      }
      It 'Includes the link to the builder, the upstream module, and the module version in the first para' {
        $Result | Should -MatchExactly "\[Puppet DSC Builder\]\(.+\)"
        $Result | Should -MatchExactly "\[$($Parameters.PowerShellModuleName)\]\($($Parameters.PowerShellModuleGalleryUri)\)"
        $Result | Should -MatchExactly "v$([Regex]::Escape($Parameters.PowerShellModuleVersion))"
      }
      It 'Includes the module description as a quote' {
        $Result | Should -MatchExactly "> _$($Parameters.PowerShellModuleDescription)_"
      }
      It 'Links to the Resource API and pwshlib dependencies' {
        $Result | Should -MatchExactly "\[Puppet Resource API\]\(.+\)"
        $Result | Should -MatchExactly "\[puppetlabs/pwshlib\]\(.+\)"
      }
      It 'Links to the base provider on github' {
        $Result | Should -MatchExactly "\(https://github.com/.+/dsc_base_provider.rb\)"
      }
      It 'Links to further narrative documentation' {
        $Result | Should -MatchExactly '\[narrative documentation\]\(.+\)'
      }
      It 'Links to the issues page for the builder, the pwslib module, and the upstream module' {
        $Result | Should -MatchExactly "\[file an issue\]\(.+puppetlabs/Puppet.Dsc/issues/new/choose\)"
        $Result | Should -MatchExactly "\[file an issue\]\(.+puppetlabs/ruby-pwsh/issues/new/choose\)"
        $Result | Should -MatchExactly "\[file an issue\]\($($Parameters.PowerShellModuleProjectUri)\)"
      }
    }
  }
}
