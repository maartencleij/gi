# Preferences
$ErrorActionPreference = "Stop"
$StartVmAfterCompletion = $true

# Load VM names and other variables from CSV file
$vmList = Import-Csv -Path "vmconfig.csv"

$vmList | ForEach-Object -Parallel {
    $VMname = $_.VMName
    $ResourceGroupName = $_.ResourceGroupName
    $AzTenantId = $_.AzTenantId
    $AzSubscriptionId = $_.AzSubscriptionId
    $TOPdeskActivity = $_.TOPdeskActivity
    $TopdeskActivityWithoutSpaces = $TOPdeskActivity.Replace(" ", "")

    try {
        Connect-AzAccount -TenantId $AzTenantId
        Select-AzSubscription $AzSubscriptionId

        # Evaluate if VM exists before continuing
        $Vm2Snapshot = Get-AzVM -Name $VMname -ResourceGroupName $ResourceGroupName
        if ($null -ne $Vm2Snapshot) {
            # Shutdown VM
            Write-Output ("Initiating shutdown of VM [ $($VMname) ] in [ $($ResourceGroupName) ]")
            Stop-AzVM -Name $Vm2Snapshot.Name -ResourceGroupName $Vm2Snapshot.ResourceGroupName -Force
            Write-Output ("VM shut down successfully")

            # Snapshot VM OS disk
            $OsDiskSnapshotName = "$($Vm2Snapshot.StorageProfile.OsDisk.Name)-OS-$($TopdeskActivityWithoutSpaces)"
            $OsDiskSnapShotConfig = New-AzSnapshotConfig -SourceUri $Vm2Snapshot.StorageProfile.OsDisk.ManagedDisk.Id -CreateOption Copy -Location $Vm2Snapshot.Location
            New-AzSnapshot -Snapshot $OsDiskSnapShotConfig -SnapshotName $OsDiskSnapshotName -ResourceGroupName $Vm2Snapshot.ResourceGroupName
            Write-Output ("Creating snapshot from [ $($Vm2Snapshot.StorageProfile.OsDisk.Name) ] completed successfully")

            # Evaluate if server has data disks, if so snapshot them
            $Vm2SnapshotDataDisks = $Vm2Snapshot.StorageProfile.DataDisks
            if ($Vm2SnapshotDataDisks.count -gt 0) {
                foreach ($DataDisk in $Vm2SnapshotDataDisks) {
                    $DataDiskSnapshotName = "$($DataDisk.Name)-LUN_$($DataDisk.Lun)-$($TopdeskActivityWithoutSpaces)"
                    $DataDiskSnapshotUri = (Get-AzDisk -DiskName $DataDisk.Name -ResourceGroupName $Vm2Snapshot.ResourceGroupName).Id
                    $DataDiskSnapShotConfig = New-AzSnapshotConfig -SourceUri $DataDiskSnapshotUri -CreateOption Copy -Location $Vm2Snapshot.Location
                    New-AzSnapshot -Snapshot $DataDiskSnapShotConfig -SnapshotName $DataDiskSnapshotName -ResourceGroupName $Vm2Snapshot.ResourceGroupName
                    Write-Output ("Creating snapshot from [ $($DataDisk.Name) ] completed successfully")
                }
            } else {
                Write-Output ("No data disks found for VM [ $($VMname) ] in [ $($ResourceGroupName) ]")
            }

            # Evaluate if VM needs to be started following completion, if so start it.
            if ($using:StartVmAfterCompletion -eq $true) {
                Write-Output ("Initiating startup of VM [ $($VMname) ] in [ $($ResourceGroupName) ]")
                Start-AzVM -Name $Vm2Snapshot.Name -ResourceGroupName $Vm2Snapshot.ResourceGroupName
                Write-Output ("VM started successfully")
            } else {
                Write-Output ("StartVmAfterCompletion set to false. Skipping start of VM.")
            }
        } else {
            Write-Error ("Unable to find VM [ $($VMname) ] in [ $($ResourceGroupName) ] in subscription [$($AzSubscriptionId)]. Please check input and try again")
        }
    } catch {
        Write-Error ("Error thrown while logging into Azure or executing part of the procedure: $($_.Exception.Message)")
    }
} -ThrottleLimit 5