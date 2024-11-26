# Function to decode the base64 URL-encoded JWT part
function Decode-Base64Url {
    param (
        [string]$Base64Url
    )
    $Base64 = $Base64Url.Replace('_', '/').Replace('-', '+')
    switch ($Base64.Length % 4) {
        2 { $Base64 += '==' }
        3 { $Base64 += '=' }
    }
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

# Function to fetch and process the MDS blob
function Get-FIDOMDSBlob {
    param (
        [string]$MDSUrl = "https://mds3.fidoalliance.org/"
    )

    # Fetch the MDS blob
    Write-Host "Fetching MDS blob from $MDSUrl..."
    try {
        $response = Invoke-RestMethod -Uri $MDSUrl -Method Get
    } catch {
        Write-Error "Failed to fetch MDS blob: $_"
        return
    }

    # Split the JWT into header, payload, and signature
    Write-Host "Decoding JWT..."
    $jwtParts = $response -split '\.'
    if ($jwtParts.Length -ne 3) {
        Write-Error "Invalid JWT format"
        return
    }

    $header = Decode-Base64Url -Base64Url $jwtParts[0]
    $payload = Decode-Base64Url -Base64Url $jwtParts[1]

    # Parse the payload into a PowerShell object
    $payloadObject = $null
    try {
        $payloadObject = $payload | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse JSON payload: $_"
        return
    }

    Write-Host "Successfully decoded JWT payload."

    # Expand the metadataStatement for each entry
    $expandedEntries = @()
    foreach ($entry in $payloadObject.entries) {
        $metadataStatement = $entry.metadataStatement

        # Flatten metadataStatement fields into the entry if present
        if ($metadataStatement) {
            foreach ($key in $metadataStatement.PSObject.Properties.Name) {
                $entry | Add-Member -MemberType NoteProperty -Name "metadata_$key" -Value $metadataStatement.$key -Force
            }
        }

        # Remove the original metadataStatement to avoid redundancy
        $entry.PSObject.Properties.Remove('metadataStatement')

        $expandedEntries += $entry
    }

    return $expandedEntries
}

# Execute the function and store the result
$MDSArray = Get-FIDOMDSBlob

# Output the expanded entries
if ($MDSArray) {
    Write-Host "Expanded MDS Entries:"
    $MDSArray | ForEach-Object { $_ | ConvertTo-Json -Depth 3 | Write-Host }
} else {
    Write-Error "Failed to retrieve or decode MDS blob."
}
