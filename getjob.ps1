# Get all running jobs
$runningJobs = Get-Job | Where-Object { $_.State -eq 'Running' }

# Check if there are any running jobs
if ($runningJobs.Count -eq 0) {
    Write-Output "No jobs are currently running."
} else {
    # Iterate over each running job
    foreach ($job in $runningJobs) {
        Write-Output "Job ID: $($job.Id)"
        Write-Output "Job Name: $($job.Name)"
        Write-Output "Job State: $($job.State)"
        Write-Output "Output:"
        
        # Retrieve and display the job's output
        Receive-Job -Id $job.Id -Keep | Out-String | Write-Output
        Write-Output "--------------------------"
    }
}
