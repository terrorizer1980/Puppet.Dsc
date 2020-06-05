param (
  $TestGeneral = $true,

  $TestFunctions = $true,

  [ValidateSet('None', 'Default', 'Passed', 'Failed', 'Pending', 'Skipped', 'Inconclusive', 'Describe', 'Context', 'Summary', 'Header', 'Fails', 'All')]
  $Show = ('Summary', 'Failed'),

  $Include = "*",

  $Exclude = ""
)

$ErrorActionPreference = "Stop"

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

Remove-Module puppet.dsc -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\puppet.dsc.psd1" -Force

$totalFailed = 0

#region Run General Tests
if ($TestGeneral)
{
  Write-PSFMessage -Level Important -Message "Modules imported, proceeding with general tests"
  foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1"))
  {
    Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
    $results = Invoke-Pester -Script $file.FullName -Show $Show -PassThru
    foreach ($result in $results)
    {
      $totalFailed += $result.FailedCount
    }
  }
}
#endregion Run General Tests

#region Test Commands
if ($TestFunctions)
{
  Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
  foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*Tests.ps1"))
  {
    if ($file.Name -notlike $Include) { continue }
    if ($file.Name -like $Exclude) { continue }

    Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
    $results = Invoke-Pester -Script $file.FullName -Show $Show -PassThru
    foreach ($result in $results)
    {
      $totalFailed += $result.FailedCount
    }
  }
}
#endregion Test Commands

if ($totalFailed -gt 0)
{
  throw "$totalFailed tests failed!"
}
