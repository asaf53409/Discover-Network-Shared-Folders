cls
$Throttle = 200 #threads
 
$ScriptBlock = {
   Param (
      [String] $Computer
   )
   
   $path_s = @()
   
   try
    {
         try
    {
    
        $shares = (net view $computer 2>$null| Select-String -Pattern '.*(?=\s*Disk)' -ErrorAction Stop ).Matches.Value 
     }
     catch{
         
         $e=$_.Exception
     }
        For ($j=0; $j -lt $shares.Length; $j++)
        {
        $print= '\\'+$computer+'\'+$shares[$j]
        $acl=Get-Acl $print -ErrorAction Stop
        if($acl.Path -like '*SYSVOL*' -or $acl.Path -like '*NETLOGON*') {
        } 
        else {
        
        $path_s+=$acl.Path
       # $acl.Access  | select IdentityReference 
                }

        }
        
    }
    catch
    {
      $e=$_.Exception 
    }
   
    Write-Host $path_s
    Return $path_s
}


$f=Get-ADForest | select Domains
for($n=0; $n -lt $f.Domains.Count; $n++)
{
    $Results = @()
    $forest=$f.Domains[$n]
    $forest
    $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Throttle)
    $RunspacePool.Open()
    $Jobs = @()
    $computers =@()

    # Access to information Windows 2012 server, create a job for each server separately, the job execution ICMP test and store the result in a PS object

    $computers = (Get-ADComputer -Filter{OperatingSystem -like 'Windows Server *'} -Properties OperatingSystem -Server $forest).Name
    For ($i=1; $i -lt $computers.Length; $i++) {
   
       # Start-Sleep -Seconds 1
       $Job = [powershell]::Create().AddScript($ScriptBlock).AddArgument($computers[$i])
       $Job.RunspacePool = $RunspacePool
       $Jobs += New-Object PSObject -Property @{
          Server = $i
          Pipe = $Job
          Result = $Job.BeginInvoke()
       }
    }
 

     # Cycle output wait .... until all of the job is done 
    Write-Host "Waiting.." -NoNewline
    Do {
       Write-Host "." -NoNewline
   
       try
          {
         Write-Host $Job.Pipe.EndInvoke($Job.Result)	-ErrorAction Stop  
            $Job.Result
        }
        catch
        {
          $e=$_.Exception 
        }
   
   
       Start-Sleep -Seconds 1
    } While ( $Jobs.Result.IsCompleted -contains $false)
    Write-Host "All jobs completed!"
 

    ForEach ($Job in $Jobs)
    {   $Results += $Job.Pipe.EndInvoke($Job.Result)
    }
    $Results | sort -unique



}

# Create a resource pool, how many runspace specified can be executed simultaneously


 
