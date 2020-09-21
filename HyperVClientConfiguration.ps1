# Self elevate if not running as admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }


#Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n172.30.32.151`tHVTEST01"



# -------------------------------------------------------------------------------
# Configure network adapter's connection profile for remote management of hyper v
# -------------------------------------------------------------------------------

$NetworkAdapters = $(Get-NetAdapter | Where-Object `
{ `
    ($_.InterfaceDescription -notmatch "Hyper-V") -and `
    ($_.InterfaceDescription -notmatch "TAP") -and `
    ($_.Status -ne "Disconnected") `
})

Write-Host "Available network adapters`n--------------------------`n"
$NetworkAdapters | Format-Table -AutoSize
Write-Host ""

if($($NetworkAdapters | Measure).Count -eq 1)
{
    $NetworkAdapter = Read-Host -Prompt "Type the name of one of the network adapters shown above. Leave blank for $($NetworkAdapters[0].Name)"

    if($NetworkAdapter -eq "")
    {
        $NetworkAdapter = $NetworkAdapters[0].Name
    }
}
else
{
    $NetworkAdapter = Read-Host -Prompt "Type the name of one of the network adapters shown above"
}

Write-Host "`nSetting network adapters connection profile to Private...`n"
Set-NetConnectionProfile -InterfaceAlias $NetworkAdapter -NetworkCategory Private





# -------------------------------------------
# Enable PSRemoting so we can configure WinRM
# -------------------------------------------

Enable-PSRemoting -SkipNetworkProfileCheck -Force





# ---------------------------------------------------------------------------------
# Configure WinRM so we can authenticate with the hyper v server across a workgroup
# ---------------------------------------------------------------------------------

Write-Host "`nConfiguring WinRM...`n"

Set-WSManQuickConfig -SkipNetworkProfileCheck -Force

Start-Service -Name WinRM
$HyperVHostname = Read-Host -Prompt "Enter the hyper v server hostname as added to C:\Windows\System32\Drivers\etc\hosts"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $HyperVHostname.ToString() -Force
$WinRmTrustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts
Stop-Service -Name winrm -NoWait

While($(Get-Service -Name WinRM).Status -eq "Running")
{
    Start-Sleep -Seconds 1
}

Write-Host "`nSuccessfully added $HyperVHostname to the WinRM trusted hosts.`n"
$WinRmTrustedHosts | Format-Table -AutoSize






# -------------------------------------------------------
# Make sure the hyper v management services are installed
# -------------------------------------------------------

Write-Host "`nInstalling Hyper V management services...`n"

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All -All





# -------------------------------------------------------
# Configure this machine for client mode with WinRM/WSMan
# -------------------------------------------------------

Write-Host "`nConfiguring this computer as client to manage Hyper V...`n"

Start-Service -Name WinRM

Enable-WSManCredSSP -Role Client -DelegateComputer locahost -Force
Enable-WSManCredSSP -Role Client -DelegateComputer $env:COMPUTERNAME -Force
Enable-WSManCredSSP -Role Client -DelegateComputer $HyperVHostname -Force
Set-Item -Path "wsman:\localhost\service\auth\credSSP" -Value $True -Force

Stop-Service -Name WinRM -NoWait

While($(Get-Service -Name WinRM).Status -eq "Running")
{
    Start-Sleep -Seconds 1
}

Write-Host "`nSuccessfully configured this computer as client, test connection to server from hyper v management UI"






# --------------------------------------------------
# Update group policy to allow credential delegation
# --------------------------------------------------

New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value "WSMAN/$HyperVHostname" -PropertyType String # Could also set -Value to *





# --------------------------------------------------------------------
# Test remote PS capability by invoking a command on the remote server
# --------------------------------------------------------------------

Invoke-Command {whoami} -ComputerName $HyperVHostname -Credential "$HyperVHostname\josh" -