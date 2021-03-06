$PAT = "mypat" # Personal Access Token - part of Azure DevOps
$AzureDevOpsOrg = "https://dev.azure.com/my-org"
$Project = "my-project"
$RepositoryId = "my-repo"
$branch = "mybranch"
$pattern = "*.ps1" #could be a /path*.ext

#get the current date
$toDate = $(Get-Date -Format "MM/dd/yyyy hh:mm:ss tt") -replace " ","%20"
#look some time in the past.
$fromDate = $(get-date).AddDays(-1).ToString("MM/dd/yyyy hh:mm:ss tt") -replace " ","%20"

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $PAT)))

$files = @()
#GET https://dev.azure.com/fabrikam/_apis/git/repositories/{repositoryId}/commits?searchCriteria.itemVersion.version=master&api-version=5.1
#https://docs.microsoft.com/en-us/rest/api/azure/devops/git/commits/get%20commits?view=azure-devops-rest-5.1#in-a-date-range
[uri] $script:GetCommitsURI = "$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryId/commits?searchCriteria.itemVersion.version=$branch&searchCriteria.toDate=$toDate&searchCriteria.fromDate=$fromDate"
$GetCommitsResponse = Invoke-RestMethod -Uri $GetCommitsURI -Method GET -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $Base64AuthInfo) } 
$commits = ($GetCommitsResponse.value).commitid

foreach ($commitid in $commits) { 
    [uri] $script:GetChangesURI = "$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryId/commits/$commitId/changes?api-version=5.1";
    $GetChangesResponse = Invoke-RestMethod -Uri $GetChangesURI -Method GET -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $Base64AuthInfo) } ;
    foreach ($change in $getChangesResponse.changes) {
        $files += $change.item.Path
        #can also look into $change.changeType (add, edit, etc.) for each change in the commit
    }
}

#get unique and filtered files based on a pattern
$filteredFiles = $files | Select-Object -unique | where-object { $_ -like $pattern } 
Write-Output $filteredFiles