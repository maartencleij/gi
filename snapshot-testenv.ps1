# Variables
$AzTenantId = "34d03e7f-fa03-432a-a48d-53b8e084a3c8"
$AzSubscriptionId = "c3c14b0b-5afb-4d91-87b6-b0964f310cc3"
$TOPdeskActivity = "tostie"
$StartVmAfterCompletion = $true

# Preferences
$ErrorActionPreference = "Stop"

# Strip spaces from activity number if they are present
$TopdeskActivityWithoutSpaces = $TOPdeskActivity.Replace(" ", "")

# Load VM names and Resource Groups from CSV file
$vmList = Import-Csv -Path "vmnames.csv"

try {
    Connect-AzAccount -TenantId $AzTenantId
    Select-AzSubscription $AzSubscriptionId

    foreach ($vm in $vmList) {
        $VMname = $vm.VMName
        $ResourceGroupName = $vm.ResourceGroupName

        # Evaluate if VM exists before continuing
        $Vm2Snapshot = Get-AzVM -Name $VMname -ResourceGroupName $ResourceGroupName
        if ($null -ne $Vm2Snapshot) {
            # Shutdown VM
            Write-Output ("Initiating shutdown of VM [ $($VmName) ] in [ $($ResourceGroupName) ]")
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
                # Snapshot VM Data disks
                foreach ($DataDisk in $Vm2SnapshotDataDisks) {
                    # Snapshot Data disk
                    $DataDiskSnapshotName = "$($DataDisk.Name)-LUN_$($DataDisk.Lun)-$($TopdeskActivityWithoutSpaces)"
                    $DataDiskSnapshotUri = (Get-AzDisk -DiskName $DataDisk.Name -ResourceGroupName $Vm2Snapshot.ResourceGroupName).Id
                    $DataDiskSnapShotConfig = New-AzSnapshotConfig -SourceUri $DataDiskSnapshotUri -CreateOption Copy -Location $Vm2Snapshot.Location
                    New-AzSnapshot -Snapshot $DataDiskSnapShotConfig -SnapshotName $DataDiskSnapshotName -ResourceGroupName $Vm2Snapshot.ResourceGroupName
                    Write-Output ("Creating snapshot from [ $($DataDisk.Name) ] completed successfully")
                }
            } else {
                Write-Output ("No data disks found for VM [ $($VmName) ] in [ $($ResourceGroupName) ]")
            }

            # Evaluate if VM needs to be started following completion, if so start it.
            if ($StartVmAfterCompletion -eq $true) {
                # Start VM
                Write-Output ("Initiating startup of VM [ $($VmName) ] in [ $($ResourceGroupName) ]")
                Start-AzVM -Name $Vm2Snapshot.Name -ResourceGroupName $Vm2Snapshot.ResourceGroupName
                Write-Output ("VM started successfully")
            } else {
                Write-Output ("StartVmAfterCompletion set to false. Skipping start of VM.")
            }
        } else {
            Write-Error ("Unable to find VM [ $($VmName) ] in [ $($ResourceGroupName) ] in subscription [$($AzSubscriptionId)]. Please check input and try again")
        }
    }
} catch {
    Write-Error ("Error thrown while logging into Azure or executing part of the procedure: $($_.Exception.Message)")
}
