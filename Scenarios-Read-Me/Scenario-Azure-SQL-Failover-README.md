## Using Azure SQL w/Failover Groups

This is based on the ps1 scripts found here: https://docs.microsoft.com/en-us/azure/sql-database/scripts/sql-database-add-single-db-to-failover-group-powershell

Be sure to login to Azure in PowerShell.

```powershell
az login
```

This PowerShell script example creates a single database, creates a failover group, adds the database to it, and tests failover.

```powershell
# Set variables for your server and database
$subscriptionId = $(az account show --query id -o tsv)
$randomIdentifier = $(Get-Random)
$rgName = "myRG-$randomIdentifier"
$location = "West US 2"
$adminLogin = "azureuser"
$password = "PWD27!"+(New-Guid).Guid
$serverName = "mysqlserver-$randomIdentifier"
$databaseName = "mySampleDatabase"
$drLocation = "East US 2"
$drServerName = "mysqlsecondary-$randomIdentifier"
$failoverGroupName = "failovergrouptutorial-$randomIdentifier"


# The ip address range that you want to allow to access your server 
# Leaving at 0.0.0.0 will prevent outside-of-azure connections
$startIp = "0.0.0.0"
$endIp = "0.0.0.0"

# Show randomized variables
Write-host "Resource group name is" $rgName 
Write-host "Password is" $password  
Write-host "Server name is" $serverName 
Write-host "DR Server name is" $drServerName 
Write-host "Failover group name is" $failoverGroupName

# Set subscription ID
az account set -s $subscriptionId

# Create a resource group
Write-host "Creating resource group..."
$rg = $(az group create -n $rgName -l $location --tags @{Owner="SQLDB-Samples"})
$rg


# Create a server with a system wide unique server name
Write-host "Creating primary logical server..."
$server = az sql server create -g $rgName -n $serverName -l $location -u $adminLogin -p $(ConvertTo-SecureString -String $password -AsPlainText -Force)
$server

# Create a server firewall rule that allows access from the specified IP range
Write-host "Configuring firewall for primary logical server..."
$serverFirewallRule = az sql server firewall-rule create -g $rgName -s $serverName -n "AllowedIPs" --start-ip-address $startIp --end-ip-address $endIp
$serverFirewallRule

# Create General Purpose Gen5 database with 2 vCore
Write-host "Creating a gen5 2 vCore database..."
$database = az sql db create -g $rgName -s $serverName -n $databaseName -e GeneralPurpose -c 2 -f Gen5 --min-capacity 2 --sample-name "AdventureWorksLT"
$database

# Create a secondary server in the failover region
Write-host "Creating a secondary logical server in the failover region..."
$drServer = az sql server create -g $rgName -n $drServerName -l $drLocation -u $adminLogin -p $(ConvertTo-SecureString -String $password -AsPlainText -Force)
$drServer

# Create a failover group between the servers
Write-host "Creating a failover group between the primary and secondary server..."
$failovergroup = az sql failover-group create -n $failoverGroupName -g $rgName -s $serverName --partner-server $drServerName --failover-policy Automatic --grace-period 2 --partner-resource-group $rgName
$failovergroup

# Add the database to the failover group
Write-host "Adding the database to the failover group..."
$failovergroup = az sql failover-group update -n $failoverGroupName -g $rgName -s $serverName --add-db $databaseName
Write-host "Successfully added the database to the failover group..." 

# Check role of secondary replica
Write-host "Confirming the secondary replica is secondary...." 
$(az sql failover-group show -n $failoverGroupName -g $rgName -s $drServerName | ConvertFrom-Json).ReplicationRole

# Failover to secondary server
Write-host "Failing over failover group to the secondary..."
Write-Host "Update Failover Group to Manual Failover Policy"
az sql failover-group update -n $failoverGroupName -g $rgName -s $serverName --failover-policy Manual
az sql failover-group set-primary -g $rgName -s $drServerName -n $failoverGroupName
Write-Host "Failover should now point to primary for $drServerName"
$(az sql failover-group show -g $rgName -s $drServerName -n $failoverGroupName | ConvertFrom-Json).ReplicationRole
Write-Host "Failover should now point to secondary for $serverName"
$(az sql failover-group show -g $rgName -s $serverName -n $failoverGroupName | ConvertFrom-Json).ReplicationRole
Write-host "Failed failover group successfully to" $drServerName



# Revert failover to primary server
Write-host "Failing over failover group to the primary...." 
#az sql failover-group set-primary --allow-data-loss -g {} -s {} -n {}
az sql failover-group set-primary -g $rgName -s $serverName -n $failoverGroupName
Write-Host "Failover should now point to secondary for $drServerName"
$(az sql failover-group show -g $rgName -s $drServerName -n $failoverGroupName | ConvertFrom-Json).ReplicationRole
Write-Host "Failover should now point to primary for $serverName"
$(az sql failover-group show -g $rgName -s $serverName -n $failoverGroupName | ConvertFrom-Json).ReplicationRole
Write-Host "Update Failover Group to Automatic Failover Policy"
az sql failover-group update -n $failoverGroupName -g $rgName -s $serverName --failover-policy Automatic --grace-period 2
Write-host "Failed failover group successfully back to" $serverName

# Show randomized variables
Write-host "Resource group name is" $rgName 
Write-host "Password is" $password  
Write-host "Server name is" $serverName 
Write-host "DR Server name is" $drServerName 
Write-host "Failover group name is" $failoverGroupName
```

We can step through these one at a time, or just run them all in sequence.

Once satisfied, we can remove the resource group.

```powershell
az group delete -g $rgName
```