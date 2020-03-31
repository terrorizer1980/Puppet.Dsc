Function Get-DscResourceTypeInformation {
  <#
    .SYNOPSIS
      Collate the information about a DSC resource for building a Puppet resource_api type.

    .DESCRIPTION
      This function leverages the Get-DscResource command and the AST for DSC Resources implemented
      in PowerShell to return additional information about the DSC Resource for building a Puppet
      resource_api compliant Type, including retrieving help info, default values, and mandatory status.

    .PARAMETER DscResource
      The DscResourceInfo object to introspect; can be passed via the pipeline, normally retrieved
      via calling Get-DscResource.

    .PARAMETER DscResourceName
      If not passing a full object, specify the name of the DSC Resource to retrieve and introspect.

    .PARAMETER ModuleName
      If not passing a full object, specify the module name of the the DSC Resource to retrieve and introspect.
      Can be either a string or a hash containing the keys ModuleName and ModuleVersion.

    .EXAMPLE
      Get-DscResource -Name PSRepository | Get-DscResourceTypeInformation

      Retrieve the information necessary for generating a Puppet Resource API type from a DSC Resource object.

    .EXAMPLE
      Get-DscResourceTypeInformation -DscResourceName PSRepository

      Retrieve the information necessary for generating a Puppet Resource API type by searching for a DSC
      resource object via Get-DscResource. Will ONLY find the resource if it is in the PSModulePath.

    .NOTES
    This function currently takes EITHER:

    1. A DscResource Object, as passed by Get-DSCResource
    2. A combo of name/module to retrieve DSC Resources from
  #>
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline)]
    [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]$DscResource,
    [string]$DscResourceName,
    [object]$ModuleName
  )
  Begin{}
  Process {
    # Retrieve the DSC Resource information from the system unless passed directly
    If ($null -eq $DscResource) {
      if ($null -eq $ModuleName) {
        $DscResource = Get-DscResource -Name $DscResourceName
      } else {
        $DscResource = Get-DscResource -Name $DscResourceName -Module $ModuleName
      }
    }
    Write-Verbose "Processing DscResource: $($DscResource.Name)"
    Write-Verbose "Module Name:            $($DscResource.ModuleName)"
    Write-Verbose "Module Version:         $($DscResource.Version)"
    Write-Verbose "Implemented As:         $($DscResource.ImplementedAs)"
    Write-Verbose "Path:                   $($DscResource.Path)"
    # We have to copy the info into a custom object because the DscResourceInfo object did not want to
    # add an array property for inserting additional information. A bit silly but it works so /shrug
    $ResourceInformation = [PSCustomObject]@{
      Name               = $DscResource.Name.ToLowerInvariant()
      FriendlyName       = $DscResource.FriendlyName
      ProviderName       = $DscResource.provider_name
      ResourceType       = $DscResource.ResourceType
      Module             = $DscResource.Module
      ModuleName         = $DscResource.ModuleName
      Version            = $DscResource.Version
      ImplementedAs      = $DscResource.ImplementedAs
      relative_mof_path  = $DscResource.relative_mof_path
      Properties         = $DscResource.Properties
      allowed_properties = $DscResource.allowed_properties
      ParameterInfo      = New-Object -TypeName System.Collections.ArrayList
    }
    # We can only parse PowerShell-implemented DSC resources for now
    If ($DscResource.ImplementedAs -eq 'PowerShell') {
      $ParsedAst = [system.management.automation.language.parser]::ParseFile($DscResource.Path, [ref]$null, [ref]$null)
    }
    If ($null -ne $ParsedAst) {
      # We can curreently only retrieve parameter metadata from function and composite DSC resources, not class-based :(
      # There are probably more elegant AST filters but this worked for now.
      $GetFunctionAst = $ParsedAst.FindAll({$true}, $true) | Where-Object -FilterScript {$_.Name -eq 'Get-TargetResource'}
      $SetFunctionAst = $ParsedAst.FindAll({$true}, $true) | Where-Object -FilterScript {$_.Name -eq 'Set-TargetResource'}
      $FilterForMandatoryParameters = {
        $MandatoryAttribute = $_.Attributes.NamedArguments | Where-Object -FilterScript {
          $_.ArgumentName -eq 'Mandatory' -and
          [string]$_.Argument -eq '$true'
        }
        $null -ne $MandatoryAttribute
      }
      If ($null -ne $GetFunctionAst) {
        $MandatoryGetParameters = $GetFunctionAst.body.ParamBlock.Parameters |
          Where-Object -FilterScript $FilterForMandatoryParameters
      }
      If ($null -ne $SetFunctionAst) {
        $MandatorySetParameters = $SetFunctionAst.body.ParamBlock.Parameters |
          Where-Object -FilterScript $FilterForMandatoryParameters
        # We only care about searching for help info on the set as it's the closest analog
        $HelpInfo = $SetFunctionAst.GetHelpContent().Parameters
      }
    }
    # We iterate over allowed_properties to get those that will work via Invoke-DscResource
    # Note that this will always return PSDscRunAsCredential (if run on 5x), which doesn't work in 7+
    ForEach ($Parameter in $DscResource.allowed_properties) {
      If ($null -ne $HelpInfo) {
        $ParameterDescription = $HelpInfo[$Parameter.Name.ToUpper()]
        If ($null -ne $ParameterDescription) { $ParameterDescription = $ParameterDescription.Trim()}
      } Else { $ParameterDescription = $null }
      If ($null -ne $SetFunctionAst) {
        $MandatorySet = ("`$$($Parameter.Name)" -in [string[]]$MandatorySetParameters.Name)
        $DefaultValue = $SetFunctionAst.body.ParamBlock.Parameters |
          Where-Object  -FilterScript { $_.Name -match [string]$Parameter.Name } |
          Select-Object -ExpandProperty DefaultValue
      } Else { $MandatorySet = $Parameter.Required }
      If ($null -ne $GetFunctionAst) {
        $MandatoryGet = ("`$$($Parameter.Name)" -in [string[]]$MandatoryGetParameters.Name)
      } Else { $MandatoryGet = $Parameter.Required }
      # We want to return all the useful info from allowed_properties PLUS
      # the help (if any), the default set value (if any), and whether or not the param is mandatory
      # for get or set calls (it *may* be manadatory for set but not get) - if we can't parse, default
      # to using the Required designation from Get-DscResource, which only cares about setting.
      $ResourceInformation.ParameterInfo.Add([pscustomobject] @{
        Name              = $Parameter.Name.ToLowerInvariant()
        DefaultValue      = $DefaultValue
        Type              = $Parameter.Type
        Help              = $ParameterDescription
        mandatory_for_get = $MandatoryGet.ToString().ToLowerInvariant()
        mandatory_for_set = $MandatorySet.ToString().ToLowerInvariant()
        mof_type          = $Parameter.ShortType
        mof_is_embedded   = $Parameter.EmbeddedInstance.ToString().ToLowerInvariant()
      }) | Out-Null
    }
    $ResourceInformation
  }
  End {}
}