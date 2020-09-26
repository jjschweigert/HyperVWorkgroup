$User = Read-Host -Prompt "Enter the user to allow access, make sure it is in the form server\user"
$SharePath = Read-Host -Prompt "Enter full path for share in the form {Drive}:\{Path}"
$ShareName = Read-Host -Prompt "Enter a name for this share"

New-SmbShare -Name $ShareName -Path $SharePath -FullAccess $User