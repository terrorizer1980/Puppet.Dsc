Function Get-PuppetModuleVersion {
  <#
    .SYNOPSIS
      Get a valid Puppet module version from a PowerShell version object
    .DESCRIPTION
      Get a valid Puppet module version from a PowerShell version object, writing a string which
      adds prerelease text for the revision version (if any), and a fifth digit representing the
      build version, starting at 0.
    .PARAMETER Version
      The PowerShell version to base the Puppet version on.
    .PARAMETER BuildNumber
      The build number for the generated module.
    .EXAMPLE
      Get-PuppetModuleVersion -Version 1.2.3

      This will return '1.2.3-0-0' as the valid Puppet module version mapping to the specified PowerShell.
    .EXAMPLE
      Get-PuppetModuleVersion -Version 1.2.3.4

      This will return '1.2.3-4-0' as the valid Puppet module version mapping to the specified PowerShell.
    .EXAMPLE
      Get-PuppetModuleVersion -Version 1.2.3 -BuildNumber 3

      This will return '1.2.3-0-3' as the valid Puppet module version mapping to the specified PowerShell.
  #>
  [cmdletbinding()]
  [OutputType([String])]
  Param (
    [version]$Version,
    [int]$BuildNumber = 0
  )
  If ($Version.Revision -gt 0) {
    "$($Version.Major).$($Version.Minor).$($Version.Build)-$($Version.Revision)-$BuildNumber"
  } Else {
    "$($Version.Major).$($Version.Minor).$($Version.Build)-0-$BuildNumber"
  }
}
