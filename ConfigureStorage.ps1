# CreateRemotePSSession
# RemoteHostPSSession
# Enter-PSSession -Session $RemoteHostPSSession

$DirectoryArray = @(
    "Shares",
    "VmImages",
    "VM"
)

Write-Host "Current available drives"

Get-WmiObject -Class Win32_logicaldisk | 
Select-Object -Property DeviceID, DriveType, VolumeName, 
@{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}},
@{L="Capacity";E={"{0:N2}" -f ($_.Size/1GB)}}

Write-Host

Get-Disk | Format-Table -AutoSize
Write-Host
$DiskNumber = Read-Host "Enter the disk number from the above list to use as the storage space for this server."
$SelectedDisk = Get-Disk -Number $DiskNumber
$SelectedDisk | Format-Table -AutoSize

Write-Host "Using $($SelectedDisk.FriendlyName) as storage for this server."
Write-Host "Formatting $($SelectedDisk.FriendlyName) with maximum disk size."

$ServerPartition = New-Partition -DiskNumber $SelectedDisk.DiskNumber -UseMaximumSize -DriveLetter 'H'

Write-Host "Successfully created new partition."
Write-Host "Formatting new partition..."

Format-Volume -DriveLetter "H"

Get-WmiObject -Class Win32_logicaldisk | 
Select-Object -Property DeviceID, DriveType, VolumeName, 
@{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}},
@{L="Capacity";E={"{0:N2}" -f ($_.Size/1GB)}}

cd "H:\"

Write-Host
Write-Host "Creating directories.."
Write-Host

foreach($directory in $DirectoryArray)
{
    #Write-Host "Creating directory $($(Get-Location).Path)$directory"
    New-Item -Path . -Name $directory -ItemType "directory"
}

ls
