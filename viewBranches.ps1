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

.PARAMETER -branchSearch
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
    [switch]$all = $false,
    [string]$branchNameSearch = ""
)

# save the repoFolder this script was run from, to return to it at the end
$directoryScriptWasRunFrom = Get-Location
# assuming the repoFolder this script is in is the `repos` repoFolder
$reposFolder = $PSScriptRoot

$output = @{}

Set-Location $reposFolder

$repoFolders = Get-ChildItem -Directory

foreach ($repoFolder in $repoFolders) {
    Set-Location $repoFolder.FullName

    $isGitRepoFolder = (Test-Path ".git")

    if (-not $isGitRepoFolder) {
        Set-Location $reposFolder
        continue
    }

    try {
        if ($all) {
            $branchNames = & git branch --format="%(refname:short)" 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Error retrieving branches for '$($repoFolder.Name)': $branchNames"
                $output[$repoFolder.Name] = @("Error")
                continue
            }
   
            $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1

            if ($LASTEXITCODE -eq 0) {
                $currentBranchTrimmed = $currentBranch.Trim()
                $branchNamesTrimmed = $branchNames | ForEach-Object { $_.Trim() }

                if ($branchNameSearch) {
                    $branchNamesTrimmed = $branchNamesTrimmed | Where-Object { $_ -like "*$branchNameSearch*" }
                }

                $output[$repoFolder.Name] = @()

                if ($branchNamesTrimmed -contains $currentBranchTrimmed) {
                    $output[$repoFolder.Name] += "$currentBranchTrimmed (current)"
                    $output[$repoFolder.Name] += $branchNamesTrimmed | Where-Object { $_ -ne $currentBranchTrimmed } | Sort-Object
                }
                else {
                    $output[$repoFolder.Name] = $branchNamesTrimmed | Sort-Object
                }
            }
            else {
                Write-Warning "Error retrieving current branch for '$($repoFolder.Name)': $currentBranch"
                $output[$repoFolder.Name] = $branchNames | ForEach-Object { $_.Trim() }
            }
            
            continue
        }
        else {
            $branchName = & git rev-parse --abbrev-ref HEAD 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Error retrieving current branch for '$($repoFolder.Name)': $branchName"

                if ($branchNameSearch.Length -eq 0) {
                    $output[$repoFolder.Name] = @("Error")
                }
            }
            elseif ($branchName -like "*$branchNameSearch*") {
                $output[$repoFolder.Name] = @($branchName)
            }
        }
    }
    catch {
        Write-Warning "An exception occurred: $_"
        $output[$repoFolder.Name] = @("Error")
    }
    
    Set-Location $reposFolder
}

$hasOutput = $false

if ($all) {
    Write-Output ""

    $output.GetEnumerator() | Sort-Object Name | ForEach-Object {
        if ($_.Value.Length -eq 0) {
            return
        }

        $hasOutput = $true
        $repoBranches = @()

        foreach ($branchName in $_.Value) {
            $repoBranches += [pscustomobject]@{
                $_.Key = $branchName
            }
        }

        Write-Output (($repoBranches | Format-Table -AutoSize | Out-String).Trim() + "`n")
    }
}
else {
    $output.GetEnumerator() | Sort-Object Name | ForEach-Object {    
        $hasOutput = $true   
        [pscustomobject]@{
            Repo             = $_.Key
            "Current Branch" = if ($_.Value.Length -eq 0) { "No branches found $(if ($branchNameSearch.Length -gt 0) { "matching '$($branchNameSearch)'" })" } 
            elseif ($_.Value[0] -eq "Error") { "Error retrieving branch" } 
            else { $_.Value[0] }
        }
    } | Format-Table -AutoSize
}

if (-not $hasOutput) {
    Write-Output "No branches found $(if ($branchNameSearch.Length -gt 0) { "matching '$($branchNameSearch)'" })"
}

Set-Location $directoryScriptWasRunFrom
