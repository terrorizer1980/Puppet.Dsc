Function Invoke-PdkCommand {
  <#
    .SYNOPSIS
      Run a PDK command
    .DESCRIPTION
      Run a PDK command and control for errors and output.
    .PARAMETER Path
      Specifies the path from which the PDK command should be run; many PDK commands are only
      valid from inside the root folder of a Puppet module.
    .PARAMETER Command
      The ScriptBlock to execute as a PDK command. Use the [scriptblock]::Create() method in the
      calling scope to interpolate variables so that complicated multi-scope interpolation is not
      required to make the command function.
    .PARAMETER SuccessFilterScript
      The scriptblock representing a Where-Object FilterScript which will iterate over the stderr
      from the PDK command (which is how it writes output), looking for a an error whose exception
      meets the FilterScript criteria.

      If none of the stderr messages meet the success criteria, the PDK command is assumed to have
      failed and will throw the last message from stderr as an exception.
    .EXAMPLE
      Invoke-PDKCommand -Command [scriptblock]::Create('pdk new module foo') -SuccessFilterScript {
        $_ -match "Module 'foo' generated at path"
      }

      This command will run in the current directory, creating a new Puppet module `foo` there. If
      none of the messages from the PDK command match the filterscript it will throw an exception.
  #>
  [CmdletBinding()]
  param(
    [System.String]$Path = '.',
    [Parameter(Mandatory=$True)]
    [System.Management.Automation.ScriptBlock]$Command,
    [Parameter(Mandatory=$True)]
    [System.Management.Automation.ScriptBlock]$SuccessFilterScript
  )
  
  begin {
    $null = Resolve-Path $Path -ErrorAction Stop

    $ScriptBlock = [ScriptBlock]::Create("
      Push-Location -Path $Path
      $Command
    ")
  }
  
  process {
    $PdkResults = Start-Job -ScriptBlock $ScriptBlock | Wait-Job
    $PdkSuccessMessage = $PDkResults.ChildJobs[0].Error.Exception |
      Where-Object -FilterScript $SuccessFilterScript
    If ($null -eq $PdkSuccessMessage) {
      Throw "Command '$Command' failed:`n`t$($PdkResults.ChildJobs[0].Error[-1].Exception -Replace 'System.Management.Automation.RemoteException:', $null)"
    } Else {
      # Should we output anything??
    }
  }

  end {}
}