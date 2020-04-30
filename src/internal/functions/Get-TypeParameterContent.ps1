Function Get-TypeParameterContent {
  <#
  .SYNOPSIS
    Return the text for a Puppet Resource API Type attribute given a DSC resource's ParameterInfo
  .DESCRIPTION
    Return the text for a Puppet Resource API Type Attribute (a property or parameter), given a DSC
    Resouce's parameter information. It will return the text but _not_ directly write out the file.
  .PARAMETER ParameterInfo
    A PSCustomObject with the required parameter information added to a DSC resource via the
    Get-DscResourceTypeInformation function.
  .EXAMPLE
    Get-TypeParameterContent (Get-DscResourceTypeInformation -Name PSRepository).ParameterInfo

    This will retrieve a DSC resource from the PSModulePath, retrieve the information
    needed to represent the DSC resource's properties as Puppet Resource API type
    attributes and then return the representation of that DSC resource appropriate
    for the Puppet Resource API.
  #>
  [cmdletbinding()]
  Param (
    [OutputType([String], [String[]])]
    [pscustomobject]$ParameterInfo
  )

  ForEach ($Parameter in $ParameterInfo) {
    New-Object -TypeName System.String @"
    dsc_$($Parameter.name): {
      type: $($Parameter.Type -split "`n" -join "`n            "),
$(
  If ([string]::IsNullOrEmpty($Parameter.Help)) {
    "      desc: %q{},"
  } Else {
    # Assemble the Description String with appropriate indentation
    $DescStrings = @('      desc: %q{')
    $Parameter.Help.Split("`n") | ForEach-Object -Process {$DescStrings += "        $_"}
    $DescStrings += '      },'
    $DescStrings -Join "`n"
  }
)
$(
  If ($Parameter.mandatory_for_get -eq 'true'){
    "      behaviour: :namevar,`n      mandatory_for_get: $($Parameter.mandatory_for_get),"
  } Else {
    "      mandatory_for_get: $($Parameter.mandatory_for_get),"
  }
)
      mandatory_for_set: $($Parameter.mandatory_for_set),
      mof_type: '$($Parameter.mof_type)',
      mof_is_embedded: $($Parameter.mof_is_embedded),
    },
"@
  }
}