Describe 'Invoke-PdkCommand' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      $CommandFoo = [scriptblock]::Create('foo')
      $SuccessException = "Module 'Foo' generated at path"

      Context 'Failures' {
        Mock Start-Job {
          [PSCustomObject]@{ID = 0}
        }
        Mock Wait-Job  {
          # Create a version of the job output that has only what we need for a "bad" job with multiple messages
          return @{
            ChildJobs = [System.Collections.ArrayList]@(
              @{ Error = [System.Collections.ArrayList]@(
                @{ Exception = 'Foo' }
                @{ Exception = 'Bar' }
                @{ Exception = 'Baz' }
              )}
            )
          }
        }
        It 'Throws if the path to call the PDK from cannot be resolved' {
          {Invoke-PdkCommand -Path TestDrive:\Foo -Command $CommandFoo -SuccessFilterScript { $_ -eq $SuccessException } } | 
            Should -Throw "Cannot find path 'TestDrive:\Foo' because it does not exist."
          Assert-MockCalled Start-Job -Times 0
          Assert-MockCalled Wait-Job  -Times 0
        }
        It 'Throws the last error if the success filter script matches none of the PDK messages in stderr' {
          {Invoke-PdkCommand -Path TestDrive:\ -Command $CommandFoo -SuccessFilterScript { $_ -eq $SuccessException } } |
            Should -Throw -PassThru |
            Select-Object -ExpandProperty Exception | Should -Match 'Baz'
          Assert-MockCalled Start-Job -Times 1
          Assert-MockCalled Wait-Job  -Times 1
        }
      }

      Context 'Success' {
        Context 'Success message is in stderr' {
          Mock Start-Job {
            [PSCustomObject]@{ID = 0}
          }
          Mock Wait-Job  {
            # Create a version of the job output that has only what we need for a "good" job
            return @{
              ChildJobs = [System.Collections.ArrayList]@(
                @{ Error = [System.Collections.ArrayList]@(@{ Exception = $SuccessException }) }
              )
            }
          }
  
          It 'Starts and waits for a job' {
            { Invoke-PdkCommand -Command $CommandFoo -SuccessFilterScript { $_ -eq $SuccessException } } | Should -Not -Throw
            Assert-MockCalled Start-Job -Times 1
            Assert-MockCalled Wait-Job  -Times 1
          }
        }

        Context 'Success message is in stdout' {
          Mock Start-Job {
            [PSCustomObject]@{ID = 0}
          }
          Mock Wait-Job  {
            # Create a version of the job output that has only what we need for a "good" job
            return @{
              ChildJobs = [System.Collections.ArrayList]@(
                @{
                  Error  = [System.Collections.ArrayList]@(@{ Exception = 'foo' })
                  Output = [System.Collections.ArrayList]@($SuccessException)
                }
              )
            }
          }
  
          It 'Starts and waits for a job' {
            { Invoke-PdkCommand -Command $CommandFoo -SuccessFilterScript { $_ -eq $SuccessException } } | Should -Not -Throw
            Assert-MockCalled Start-Job -Times 1
            Assert-MockCalled Wait-Job  -Times 1
          }
        }
      }
    }
  }
}