# Preferences
$ErrorActionPreference = "Stop"

# Load VM names and other variables from CSV file
$vmList = Import-Csv -Path "vmconfig.csv"

foreach ($vm in $vmList) {
    $VMname = $vm.VMName
    $ResourceGroupName = $vm.ResourceGroupName
    $AzTenantId = $vm.AzTenantId
    $AzSubscriptionId = $vm.AzSubscriptionId
    $TOPdeskActivity = $vm.TOPdeskActivity
    $TopdeskActivityWithoutSpaces = $TOPdeskActivity.Replace(" ", "")

    try {
        Connect-AzAccount -TenantId $AzTenantId
        Select-AzSubscription $AzSubscriptionId

        # Get the VM details
        $Vm2Snapshot = Get-AzVM -Name $VMname -ResourceGroupName $ResourceGroupName
        if ($null -ne $Vm2Snapshot) {

            # Generate snapshot names using the same convention as the snapshot creation script
            $OsDiskSnapshotName = "$($Vm2Snapshot.StorageProfile.OsDisk.Name)-OS-$($TopdeskActivityWithoutSpaces)"

            # Find and remove the OS disk snapshot if it includes the TOPdeskActivity identifier
            $OsDiskSnapshot = Get-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $OsDiskSnapshotName -ErrorAction SilentlyContinue
            if ($null -ne $OsDiskSnapshot -and $OsDiskSnapshot.Name -like "*$TopdeskActivityWithoutSpaces*") {
                Remove-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $OsDiskSnapshotName -Force
                Write-Output ("Deleted snapshot [ $OsDiskSnapshotName ] for OS disk of VM [ $VMname ] in resource group [ $ResourceGroupName ]")
            } else {
                Write-Output ("No matching OS disk snapshot found for VM [ $VMname ] with snapshot name [ $OsDiskSnapshotName ] including TOPdeskActivity [ $TopdeskActivity ]")
            }

            # Check for and remove data disk snapshots if they include the TOPdeskActivity identifier
            $Vm2SnapshotDataDisks = $Vm2Snapshot.StorageProfile.DataDisks
            if ($Vm2SnapshotDataDisks.count -gt 0) {
                foreach ($DataDisk in $Vm2SnapshotDataDisks) {
                    $DataDiskSnapshotName = "$($DataDisk.Name)-LUN_$($DataDisk.Lun)-$($TopdeskActivityWithoutSpaces)"

                    $DataDiskSnapshot = Get-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $DataDiskSnapshotName -ErrorAction SilentlyContinue
                    if ($null -ne $DataDiskSnapshot -and $DataDiskSnapshot.Name -like "*$TopdeskActivityWithoutSpaces*") {
                        Remove-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $DataDiskSnapshotName -Force
                        Write-Output ("Deleted snapshot [ $DataDiskSnapshotName ] for data disk [ $DataDisk.Name ] of VM [ $VMname ] in resource group [ $ResourceGroupName ]")
                    } else {
                        Write-Output ("No matching data disk snapshot found for VM [ $VMname ] with snapshot name [ $DataDiskSnapshotName ] including TOPdeskActivity [ $TopdeskActivity ]")
                    }
                }
            } else {
                Write-Output ("No data disks found for VM [ $VMname ] in [ $ResourceGroupName ]")
            }

        } else {
            Write-Error ("Unable to find VM [ $($VMname) ] in [ $($ResourceGroupName) ] in subscription [$($AzSubscriptionId)]. Please check input and try again")
        }
    } catch {
        Write-Error ("Error thrown while logging into Azure or executing part of the procedure: $($_.Exception.Message)")
    }
}
