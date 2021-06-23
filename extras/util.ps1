Function ConvertTo-VersionBuild {
  [CmdletBinding()]
  param (
    [Parameter()]
    [String[]]
    $Version
  )

  Begin { }
  Process {
    $Version | Sort-Object -Descending | ForEach-Object -Process {
      [pscustomobject]@{
        Version = $_.substring(0, ($_.length - 2))
        Build   = [int]([string]$_[-1])
      }
    }
  }
  End { }
}

Function Get-LatestBuild {
  [CmdletBinding()]
  param (
    [Parameter()]
    [String[]]
    $Version
  )
  Begin { }
  Process {
    $VersionAndBuild = ConvertTo-VersionBuild -Version $Version
    $VersionAndBuild.version |
      Select-Object -Unique |
      ForEach-Object -Process {
        $VersionAndBuild |
          Where-Object -Property Version -EQ $_ |
          Sort-Object -Property Build -Descending |
          Select-Object -First 1
        }
  }
  End { }
}

Function ConvertFrom-VersionBuild {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline = $true)]
    [object[]]
    $VersionBuild
  )

  Begin { }
  Process {
    $VersionBuild | ForEach-Object -Process {
      "$($_.Version)-$($_.Build)"
    }
  }
  End { }
}

Function Get-ForgeModuleInfo {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string[]]
    $Name
  )

  Begin {
    $UriBase = 'https://forgeapi.puppet.com/v3/modules/dsc-'
    $ModuleSearchParameters = @{
      Method          = 'Get'
      UseBasicParsing = $True
      Headers         = @{
        Authotization = "Bearer $ENV:FORGE_TOKEN"
      }
    }
  }
  Process {
    foreach ($Module in $Name) {
      $ModuleSearchParameters.Uri = $UriBase + (Get-PuppetizedModuleName $Module)
      $Result = Invoke-RestMethod @ModuleSearchParameters
      [PSCustomObject]@{
        Name                 = $Result.name
        Releases             = $Result.releases.version
        PowerShellModuleInfo = $Result.current_release.metadata.dsc_module_metadata
      }
    }
  }
  End { }
}

Function Get-ForgeDscModules {
  [CmdletBinding()]
  param (
    [Parameter()]
    [object[]]
    $Name
  )

  Begin {
    $PaginationBump = 5
    $ForgeSearchParameters = @{
      Method          = 'Get'
      UseBasicParsing = $True
      Uri             = 'https://forgeapi.puppet.com/v3/modules'
      Headers         = @{
        Authotization = "Bearer $ENV:FORGE_TOKEN"
      }
      Body            = @{
        owner  = 'dsc'
        limit  = $PaginationBump
        offset = 0
      }
    }
    $Results = [System.Collections.ArrayList]::new()
  }

  Process {
    do {
      $Response = Invoke-RestMethod @ForgeSearchParameters
      ForEach ($Result in $Response.results) {
        $null = $Results.Add([PSCustomObject]@{
            Name                 = $Result.name
            Releases             = $Result.releases.version
            PowerShellModuleInfo = $Result.current_release.metadata.dsc_module_metadata
          })
      }
      $ForgeSearchParameters.body.offset += $PaginationBump
    } until ($null -eq $Response.Pagination.Next)
    $Results
  }
  End { }
}

Function Update-ForgeDscModule {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string[]]$Name
  )

  Begin { }

  Process {
    If ($null -eq $Name) {
      $ModulesToRebuild = Get-ForgeDscModules
    } Else {
      $ModulesToRebuild = Get-ForgeModuleInfo -Name $Name
    }
    foreach ($Module in $ModulesToRebuild) {
      foreach ($VersionAndBuild in (Get-LatestBuild $Module.Releases)) {
        $OutputFolder = "$(Get-Location)/import/$($Module.Name)"
        If (Test-Path $OutputFolder) {
          Remove-Item $OutputFolder -Force -Recurse
        }
        $PuppetizeParameters = @{
          PuppetModuleAuthor      = 'dsc'
          PowerShellModuleName    = [string]$Module.PowerShellModuleInfo.Name
          PowerShellModuleVersion = [string]$VersionAndBuild.Version -replace '-', '.'
        }
        Write-Host "Puppetizing with: $($PuppetizeParameters | Out-String)"
        New-PuppetDscModule @PuppetizeParameters
        $VersionAndBuild.Build += 1
        $PublishCommand = @(
          'pdk'
          'release'
          "--forge-token=$ENV:FORGE_TOKEN"
          "--version=$($VersionAndBuild | ConvertFrom-VersionBuild)"
          '--skip-changelog'
          '--skip-validation'
          '--skip-documentation'
          '--skip-dependency'
          '--force'
        ) -Join ' '
        Write-Host "Executing: $PublishCommand"
        Invoke-PdkCommand -Path $OutputFolder -Command $PublishCommand -SuccessFilterScript { $_ -match 'Publish to Forge was successful' }
        Write-Host "Published $($Module.Name) at $($VersionAndBuild | ConvertFrom-VersionBuild)"
      }
    }
  }

  End { }
}

Function Get-PowerShellDscModule {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string[]]
    $Name
  )

  Begin { }
  Process {
    If ($null -eq $Name) {
      $Name = Find-Module -DscResource * -Name * |
        Select-Object -ExpandProperty Name
    }

    ForEach ($NameToSearch in $Name) {
      $Response = Find-Module -Name $NameToSearch -AllVersions
      [PSCustomObject]@{
        Name     = $NameToSearch
        Releases = $Response.Version
      }
    }
  }
  End { }
}

Function ConvertTo-StandardizedVersionString {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline = $true)]
    [version[]]
    $Version
  )
  Begin { }
  Process {
    ForEach ($VersionToProcess in $Version) {
      $StandardizedVersion = [PSCustomObject]@{
        Major    = $VersionToProcess.Major
        Minor    = $VersionToProcess.Minor
        Build    = $VersionToProcess.Build
        Revision = $VersionToProcess.Revision
      }
      if ($StandardizedVersion.Minor -eq -1) {
        $StandardizedVersion.Minor = 0
      }
      if ($StandardizedVersion.Major -eq -1) {
        $StandardizedVersion.Major = 0
      }
      if ($StandardizedVersion.Build -eq -1) {
        $StandardizedVersion.Build = 0
      }
      if ($StandardizedVersion.Revision -eq -1) {
        $StandardizedVersion.Revision = 0
      }
      "$($StandardizedVersion.Major).$($StandardizedVersion.Minor).$($StandardizedVersion.Build).$($StandardizedVersion.Revision)"
    }
  }
  End { }
}

Function Get-UnreleasedDscModuleVersion {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string[]]
    $Name
  )

  Begin { }
  Process {
    $GalleryModuleInfo = Get-PowerShellDscModule -Name $Name
    ForEach ($Module in $GalleryModuleInfo) {
      $ForgeModuleInfo = Get-ForgeModuleInfo -Name (Get-PuppetizedModuleName -Name $Module.Name)
      $VersionsReleasedToForge = Get-LatestBuild $ForgeModuleInfo.Releases |
        Select-Object -ExpandProperty Version |
        ForEach-Object -Process { $_ -replace '-', '.' }
      $ModuleVersions = ConvertTo-StandardizedVersionString -Version $Module.Releases
      $VersionsToRelease = $ModuleVersions | Where-Object -FilterScript { $_ -notin $VersionsReleasedToForge }
      [PSCustomObject]@{
        Name     = $Module.Name
        Versions = $VersionsToRelease
      }
    }
  }
  End { }
}

Function Publish-NewDscModuleVersion {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string[]]
    $Name
  )
  Begin {}
  Process {
    $ModuleInformation = Get-UnreleasedDscModuleVersion -Name $Name
    ForEach ($Module in $ModuleInformation) {
      $PuppetModuleName = Get-PuppetizedModuleName $Module.Name
      $OutputFolder = "$(Get-Location)/import/$PuppetModuleName"
      ForEach ($Version in $Module.Versions) {
        If (Test-Path $OutputFolder) {
          Remove-Item $OutputFolder -Force -Recurse
        }
        $PuppetizeParameters = @{
          PuppetModuleAuthor      = 'dsc'
          PowerShellModuleName    = $Module.Name
          PowerShellModuleVersion = $Version
        }
        Write-Host "Puppetizing with: $($PuppetizeParameters | Out-String)"
        New-PuppetDscModule @PuppetizeParameters
        $PublishCommand = @(
          'pdk'
          'release'
          "--forge-token=$ENV:FORGE_TOKEN"
          '--skip-changelog'
          '--skip-validation'
          '--skip-documentation'
          '--skip-dependency'
          '--force'
        ) -Join ' '
        Write-Host "Executing: $PublishCommand"
        Invoke-PdkCommand -Path $OutputFolder -Command $PublishCommand -SuccessFilterScript { $_ -match 'Publish to Forge was successful' }
        Write-Host "Published $($Module.Name) as $PuppetModuleName at $Version"
      }
    }
  }
  End {}
}
