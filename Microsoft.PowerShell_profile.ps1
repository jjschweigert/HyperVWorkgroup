Import-Module posh-git
Import-Module oh-my-posh
Set-Theme Agnoster

$DefaultUser = $env:UserName
$Global:RemoteHostPSSession = $null;

function CreateRemotePSSession {
    $remoteHost = Read-Host -Prompt "Enter the fqnd of the remote host"
    $creds = Get-Credential -Message "Enter the username and password to use for this remote session, note username should be in the form $remoteHost/user"
    
    $Global:RemoteHostPSSession = New-PSSession -ComputerName $remoteHost -Credential $creds

    Write-Host 'Run "Enter-PSSession -Session $RemoteHostPSSession" to start a remote powershell session.'
    Write-Host 'Run "exit" from the remote session to leave the remote powershell session and return to the local host session.'
}

function TransferFile{

    $Source = Read-Host -Prompt "Enter full source path of file in the form {Drive}:\{Path}"
    $Destination = Read-Host -Prompt "Enter path to move the file to in the form {Drive}:\{Path}"

    Move-Item -Path $Source -Destination $Destination
}

function PrintWelcomeMessage {
    
}