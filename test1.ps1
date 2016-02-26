#ps1_sysnative

Start-Transcript -Path C:\user_data_log.txt -Append

# Set the Administrator password
net user Administrator $admin_password

# Get the Public IP
$PublicIp = (Get-NetIPConfiguration).IPv4Address[1].IPAddress

# Create a new Self-signed cert
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $PublicIp

# Delete any existing WinRM listener
winrm delete winrm/config/Listener?Address=*+Transport=HTTPS

# Create new WinRM listener
New-Item -Address * -Force -Path wsman:\localhost\listener `
-Port 5986 `
-HostName ($cert.subject -split '=')[1] `
-Transport https `
-CertificateThumbPrint $cert.Thumbprint

# Set some config vars
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1025
Set-Item WSMan:\localhost\MaxTimeoutms 1800001

# Open up WinRM port
# WARNING: This opens the port to the entire internet!
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow

# Open HTTP(s) ports
netsh advfirewall firewall set rule group="World Wide Web Services (HTTP)" new enable=yes > $null
netsh advfirewall firewall set rule group="Secure World Wide Web Services (HTTPS)" new enable=yes > $null

# Set up clock sync
net start w32time
w32tm /config /manualpeerlist:"0.uk.pool.ntp.org 1.uk.pool.ntp.org 2.uk.pool.ntp.org 3.uk.pool.ntp.org" /syncfromflags:manual /reliable:yes /update
w32tm /resync

# Notify our wait condition
Invoke-RestMethod -Method POST -ContentType application/json -Body '{"Status" : "SUCCESS"}' -Uri $wait_condition_url

Stop-Transcript
