# Self elevate if not running as admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) 
{ 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs;
    exit 
}

$remoteHostName = Read-Host -Prompt "Enter the remote hosts FQDN"

# If you want to add the host to the hosts file, you can use the code below
# $remoteHostIp = Read-Host -Prompt "Enter the IP of the remote host to add to the local hosts file"
#Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n$remoteHostIp`t$remoteHostName"

$remoteHostUsername = Read-Host -Prompt "Enter the username for $remoteHostName"
$remoteHostPassword = Read-Host -Prompt "Enter the password for $remoteHostUsername on $remoteHostName"

$remoteCredentials = New-Object System.Management.Automation.PSCredential("$remoteHostName\$remoteHostUsername", $(ConvertTo-SecureString $remoteHostPassword -AsPlainText -Force))


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

if($($NetworkAdapters | Measure-Object).Count -eq 1)
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
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $remoteHostName.ToString() -Force
$WinRmTrustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts
Stop-Service -Name winrm -NoWait

While($(Get-Service -Name WinRM).Status -eq "Running")
{
    Start-Sleep -Seconds 1
}

Write-Host "`nSuccessfully added $remoteHostName to the WinRM trusted hosts.`n"
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
Enable-WSManCredSSP -Role Client -DelegateComputer $remoteHostName -Force
Set-Item -Path "wsman:\localhost\service\auth\credSSP" -Value $True -Force

Stop-Service -Name WinRM -NoWait

While($(Get-Service -Name WinRM).Status -eq "Running")
{
    Start-Sleep -Seconds 1
}






# --------------------------------------------------
# Update group policy to allow credential delegation
# --------------------------------------------------

New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value "WSMAN/$remoteHostName" -PropertyType String # Could also set -Value to *





# --------------------------------------------------------------------
# Test remote PS capability by invoking a command on the remote server
# --------------------------------------------------------------------

Invoke-Command {whoami} -ComputerName $remoteHostName -Credential $remoteCredentials