function Get-TypeContent {
  <#
  .SYNOPSIS
    Return the text for a Puppet Resource API Type given a DSC Resouce.
  .DESCRIPTION
    Return the text for a Puppet Resource API Type given a DSC Resouce.
    It will return the text but _not_ directly write out the file.
  .PARAMETER DscResource
    A DSCResourceInfo object with the required parameter information
    retrieved - if the object does _not_ already have the updated info
    for the parameters, this function will attempt to retrieve it.
  .EXAMPLE
    Get-DscResourceTypeInformation -Name PSRepository | Get-TypeContent

    This will retrieve a DSC resource from the PSModulePath, retrieve the information
    needed to represent the DSC resource's properties as Puppet Resource API type
    attributes and then return the representation of that DSC resource appropriate
    for the Puppet Resource API.
  #>
  [cmdletbinding()]
  param (
    [OutputType([String], [String[]])]
    [Parameter(ValueFromPipeline)]
    [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]$DscResource
  )

  Begin {}

  Process {
    ForEach ($Resource in $DscResource) {
      If($Null -eq $Resource.ParameterInfo) {
        $Resource = Get-DscResourceTypeInformation -DscResource $Resource
      }
      If ($Null -eq $Resource.FriendlyName) {
        $FriendlyName = $Resource.Name
      } Else {
        $FriendlyName = $Resource.FriendlyName
      }
      New-Object -TypeName System.String @"
require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'dsc_$($Resource.Name.ToLowerInvariant())',
  dscmeta_resource_friendly_name: '$FriendlyName',
  dscmeta_resource_name: '$($Resource.ResourceType)',
  dscmeta_module_name: '$($Resource.ModuleName)',
  dscmeta_module_version: '$($Resource.Version)',
  docs: %q{
    The DSC $FriendlyName resource type.
    Automatically generated from version $($Resource.Version)
  },
  features: ['simple_get_filter', 'canonicalize'],
  attributes: {
    ensure: {
      type:    'Enum[present, absent]',
      desc:    'Whether this resource should be present or absent on the target system.',
      default: 'present',
    },
    name: {
      type:      'String',
      desc:      'Description of the purpose for this resource declaration.',
      behaviour: :namevar,
    },
$((Get-TypeParameterContent -ParameterInfo $Resource.ParameterInfo) -join "`n")
  },
)
"@
    }
  }

  End {}
}
