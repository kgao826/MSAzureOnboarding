param (
    [Parameter (Mandatory = $true)] 
    [String]$Username
)
$CustomerDefaultDomainname = "contoso.onmicrosoft.com"

Write-Output "Username" $Username

Write-Output "Connecting to Exchange Online"
Connect-ExchangeOnline -ManagedIdentity -Organization valocityglobal.com 

$Mailbox = Get-Mailbox | Where {$_.PrimarySmtpAddress -eq $Username}

#Enable Litigation Hold for new user
Set-Mailbox $Mailbox -LitigationHoldEnabled $true
Write-Output "Litigation Hold Applied"

#Disconnect
Disconnect-ExchangeOnline
Write-Output "Disconnected"
