<#
.SYNOPSIS
    Lists all Git repos in the current repoFolder and their current branch.

.DESCRIPTION
    Iterates through each top-level repoFolder in the current directory, checks if
    it contains a Git repo, retrieves the current branch name or all branch
    names, then outputs the repo-repoFolder and branch names in a table.
    This script should be placed in the repoFolder with all your repos in it.

.PARAMETER -all
    If specified, retrieves all branches for each Git repo found in the current
    repoFolder. If not specified, retrieves only the current branch in each repoFolder.

.PARAMETER -branchNameSearch
    If specified, filters the branches to only show those that contain the
    specified string, case-insensitive.

.EXAMPLE
    .\viewBranches.ps1
    This example runs the script, which will output the list of Git repos and
    their branches in the current repoFolder.

.EXAMPLE
    .\viewBranches.ps1 -all
    This example runs the script with the -all argument, which will output the
    list of all branches for each Git repo found in the current repoFolder.

.EXAMPLE
    .\viewBranches.ps1 -branchSearch "feature"
    This example filters the branches and only shows those containing the word 
    "feature".
#>

param (
    [CmdletBinding()]
    [switch]$all = $false,
    [CmdletBinding()]
    [string]$branchNameSearch = ""
)

#region Functions
function Get-All-Branch-Names {
    param (
        [string]$repoFolderName,
        [hashtable]$output
    )

    $branchNames = & git branch --format="%(refname:short)" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Error retrieving branches for '$($repoFolderName)': $branchNames"

        if ($branchNameSearch.Length -eq 0) {
            $output[$repoFolderName] = @("Error")
        }
        
        return
    }

    $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Error retrieving current branch for '$($repoFolderName)': $currentBranch"

        if ($branchNameSearch.Length -eq 0) {
            $output[$repoFolderName] = $branchNames | ForEach-Object { $_.Trim() }
        }
        
        return
    }

    $currentBranchTrimmed = $currentBranch.Trim()
    $branchNamesTrimmed = $branchNames | ForEach-Object { $_.Trim() }

    if ($branchNameSearch.Length -gt 0) {
        $branchNamesTrimmed = $branchNamesTrimmed | Where-Object { $_ -like "*$branchNameSearch*" }
    }

    if ($branchNamesTrimmed.Length -eq 0) {
        return
    }

    $output[$repoFolderName] = @()

    if ($branchNamesTrimmed -contains $currentBranchTrimmed) {
        $output[$repoFolderName] += "$currentBranchTrimmed (current)"
        $output[$repoFolderName] += $branchNamesTrimmed | Where-Object { $_ -ne $currentBranchTrimmed } | Sort-Object
    }
    else {
        $output[$repoFolderName] = $branchNamesTrimmed | Sort-Object
    }
}

function Get-Current-Branch-Name {
    param (
        [string]$repoFolderName,
        [hashtable]$output
    )

    $branchName = & git rev-parse --abbrev-ref HEAD 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Error retrieving current branch for '$($repoFolderName)': $branchName"

        if ($branchNameSearch.Length -eq 0) {
            $output[$repoFolderName] = @("Error")
        }

        return
    }

    if ($branchName -like "*$branchNameSearch*") {
        $output[$repoFolderName] = @($branchName)
    }
}

function Write-All-Branch-Names {
    param (
        [hashtable]$output
    )

    Write-Host ""

    $output.GetEnumerator() | Sort-Object Name | ForEach-Object {
        if ($_.Value.Length -eq 0) {
            return
        }

        $repoBranches = @()

        foreach ($branchName in $_.Value) {
            $repoBranches += [pscustomobject]@{
                $_.Key = $branchName
            }
        }

        Write-Host (($repoBranches | Format-Table -AutoSize | Out-String).Trim() + "`n")
    }
}

function Write-Current-Branch-Names {
    param (
        [hashtable]$output
    )

    $output.GetEnumerator() | Sort-Object Name | ForEach-Object {  
        $currentBranch = "Unknown"
        
        if ($_.Value.Length -eq 0) { 
            $currentBranch = "No branches found"
            
            if ($branchNameSearch.Length -gt 0) {
                $currentBranch = $currentBranch, "matching '$($branchNameSearch)'" -Join " "
            }
        } 
        elseif ($_.Value[0] -eq "Error") { 
            $currentBranch = "Error retrieving branch" 
        } 
        else { 
            $currentBranch = $_.Value[0] 
        }
        
        [pscustomobject]@{
            Repo             = $_.Key
            "Current Branch" = $currentBranch
        }
    } | Format-Table -AutoSize

    if ($branchNameSearch.Length -gt 0) {
        Write-Host "sdg"
    }
}

function Handle-Repo-Folder {
    param (
        [System.IO.DirectoryInfo]$repoFolder,
        [hashtable]$output
    )

    Push-Location $repoFolder.FullName

    $isGitRepoFolder = Test-Path ".git"

    if (-not $isGitRepoFolder) {
        Pop-Location
        continue
    }

    try {
        if ($all) {
            Get-All-Branch-Names -repoFolderName $repoFolder -output $output
        }
        else {
            Get-Current-Branch-Name -repoFolderName $repoFolder -output $output
        }
    }
    catch {
        Write-Warning "An exception occurred: $_"
        $output[$repoFolder.Name] = @("Error")
    }
    
    Pop-Location
}
#endregion

# assuming the repoFolder this script is in is the `repos` repoFolder
$reposFolder = $PSScriptRoot
Push-Location $reposFolder

$repoFolders = Get-ChildItem -Directory
$output = @{}

foreach ($repoFolder in $repoFolders) {
    Handle-Repo-Folder -repoFolder $repoFolder -output $output
}

if ($all) {
    Write-All-Branch-Names -output $output
}
else {
    Write-Current-Branch-Names -output $output
}

if ($output.Count -eq 0) {
    $currentBranch = "No branches found"
            
    if ($branchNameSearch.Length -gt 0) { 
        $currentBranch = $currentBranch, "matching '$($branchNameSearch)'" -Join " "
    }
            
    Write-Host $currentBranch
}

Pop-Location
