if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) 
{ 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; 
    exit
}

$username = "hyperv\josh"
$password = ConvertTo-SecureString "Password@001" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential($username, $password)
Invoke-Command {Stop-Computer -ComputerName localhost -Force} -ComputerName "hypervserver" -Credential $creds