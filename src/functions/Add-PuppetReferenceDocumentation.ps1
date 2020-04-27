function Add-PuppetReferenceDocumentation {
    <#
      .SYNOPSIS
        Generate REFERENCE.md
      .DESCRIPTION
        Generate REFERENCE.md
      .PARAMETER PuppetModuleFolderPath
        The path, relative or literal, to the Puppet module's root folder.
      .EXAMPLE
        Add-PuppetReferenceDocumentation -PuppetModuleFolderPath C:\output\testmodule
        This command will generate `REFERENCE.md` file.
    #>
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$true)]
      $PuppetModuleFolderPath
    )

    begin {
      $PuppetModuleFolderPath = Resolve-Path -Path $PuppetModuleFolderPath -ErrorAction Stop
      $Command = [scriptblock]::Create("pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md")
    }
    process {
      Try {
        $ErrorActionPreference = 'Stop'
        Invoke-PdkCommand -Path $PuppetModuleFolderPath -Command $Command -SuccessFilterScript {
          $_ -match "pdk"
        }
        # Verify REFERENCE.md file is generated
        $ReferenceFile = Join-Path -Path $PuppetModuleFolderPath -ChildPath REFERENCE.md
        if (Test-Path $ReferenceFile -PathType leaf)
          {
            Write-Output "REFERENCE.md file generated"
          }
      } Catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
      }
    }
    end {}
  }