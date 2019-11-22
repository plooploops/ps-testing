$PAT = "my-pat" # Personal Access Token - part of Azure DevOps
$AzureDevOpsOrg = "https://dev.azure.com/my-prg"
$Project = "my-project"
$RepositoryId = "my-repo"
$branch = "my-branch"
$pullRequestId = "mypr" #e.g. 123
# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $PAT)))

#get from all local branches
$files = @()
#GET https://dev.azure.com/fabrikam/_apis/git/repositories/{repositoryId}/commits?searchCriteria.itemVersion.version=master&api-version=5.1
#https://docs.microsoft.com/en-us/rest/api/azure/devops/git/commits/get%20commits?view=azure-devops-rest-5.1#on-a-branch
#https://docs.microsoft.com/en-us/rest/api/azure/devops/git/commits/get%20commits?view=azure-devops-rest-5.1#in-a-date-range
#[uri] $script:GetCommitsURI = "$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryId/commits?searchCriteria.itemVersion.version=$branch&gitLogHistoryMode=fullHistory"
[uri] $script:GetCommitsURI = "$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryId/pullRequests/$pullRequestId/commits?searchCriteria.itemVersion.version=$branch"
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

$pattern = "*.ps1" #could be a /path*.ext
#get unique and filtered files based on a pattern
$filteredFiles = $files | Select-Object -unique | where-object { $_ -like $pattern } 
echo $filteredFiles