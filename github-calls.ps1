
function CallWebRequest {
    param (
        [string] $url,
        [string] $userName,
        [string] $PAT,
        [string] $verbToUse = "Get",
        [object] $body
    )

    $Headers = Get-Headers -userName $userName -PAT $PAT

    try {

        $bodyContent = ($body | ConvertTo-Json) -replace '\\', '\'
        $result = Invoke-WebRequest -Uri $url -Headers $Headers -Method $verbToUse -Body $bodyContent -ErrorAction Stop
        
        Write-Host "  StatusCode: $($result.StatusCode)"
        Write-Host "  RateLimit-Limit: $($result.Headers["X-RateLimit-Limit"])"
        Write-Host "  RateLimit-Remaining: $($result.Headers["X-RateLimit-Remaining"])"
        Write-Host "  RateLimit-Reset: $($result.Headers["X-RateLimit-Reset"])"
        Write-Host "  RateLimit-Used: $($result.Headers["x-ratelimit-used"])"
        # convert the response json content
        $info = ($result.Content | ConvertFrom-Json)
    }
    catch {
        Write-Host "Error calling api at [$url]:"
        Write-Host "  StatusCode: $($_.Exception.Response.StatusCode)"
        Write-Host "  RateLimit-Limit: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Limit"))"
        Write-Host "  RateLimit-Remaining: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Remaining"))"
        Write-Host "  RateLimit-Reset: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Reset"))"
        Write-Host "  RateLimit-Used: $($_.Exception.Response.Headers.GetValues("x-ratelimit-used"))"

        $messageData = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "$($_.ErrorDetails.Message)"
        if ($messageData.message.StartsWith("API rate limit exceeded")) {
            Write-Error "Rate limit exceeded. Halting execution"
            throw
        }

        if ($messageData.message -eq "Not Found") {
            Write-Warning "Call to GitHub Api [$url] had [not found] result with documentation url [$($messageData.documentation_url)]"
            return $messageData.documentation_url
        }
        
        Write-Host "$messageData"
    }

    return $info
}

function GetForkCloneUrl {
    param (
        [string] $forkUrl,
        [string] $PAT
    )

    return "https://xx:$PAT@github.com/$fork.git"
}

function GetParentInfo {
    param (
        [string] $fork,
        [string] $PAT
    )

    $repoUrl = "https://api.github.com/repos/$fork"
    $info = CallWebRequest -url $repoUrl -userName $userName -PAT $PAT

    if ($false -eq $info.fork) {
        Write-Error "Repo [$fork] is not a fork"
        throw
    }

    return [PSCustomObject]@{
        parentUrl = $info.parent.git_url
        parentDefaultBranch = $info.parent.default_branch
    }

}