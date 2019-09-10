<#
 .Synopsis
  Copies Active Directory group membership from a user to one or more other users.

 .Description
  Copies Active Directory group membership from a user to one or more other users.

 .Parameter From
  Selects the user to copy group membership from.

 .Parameter To
  Selects the user or users to apply copied group membership to.

 .Parameter OverwriteExisting
  Removes user from all existing groups except for Domain Users before applying new membership.

 .Parameter ShowErrors
  Displays errors encountered by the cmdlet during the process block as part of the output.

 .Example
   # Copy permissions from UserA to UserB
   Copy-ADUserPermissions -From UserA -To UserB

 .Example
   # Copy permissions from UserA to UserB and UserC
   Copy-ADUserPermissions -From UserA -To UserB, UserC

 .Example
   # Copy permissions from UserA to UserB and remove UserB's previous group membership
   Copy-ADUserPermissions -From UserA -To UserB -OverwriteExisting
#>
Function Copy-ADUserPermissions {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [object]$From,

        [Parameter(Mandatory)]
        [object]$To,

        [Parameter()]
        [switch]$OverwriteExisting,

        [Parameter()]
        [switch]$ShowErrors

    )

    begin {
        $SourceGroups = Get-ADPrincipalGroupMembership $From
        $TargetUsersArray = New-Object System.Collections.Generic.List[System.Object]
        $ResultsArray = New-Object System.Collections.Generic.List[System.Object]
        foreach ($User in $To) {
            $TargetUsersArray.Add((Get-ADUser $User))
        }

    }
    process {
        if ($PSBoundParameters.ContainsKey('OverwriteExisting')) {
            foreach ($User in $TargetUsersArray) {
                Get-AdPrincipalGroupMembership -Identity $User | Where-Object -Property Name -Ne -Value 'Domain Users' | Remove-AdGroupMember -Members $User -confirm:$false
            }
        }
        foreach ($Group in $SourceGroups) {
            try {
                Add-ADGroupMember -Identity $Group -Members $TargetUsersArray
            }
            catch {
                if ($PSBoundParameters.ContainsKey('ShowErrors')) {
                    foreach ($Line in $Error) {
                    Write-Error $Line
                    }
                }

            }
        }

    }
    end {
        foreach ($User in $TargetUsersArray) {
            $UserResultObject = [PSCustomObject]@{
                UPN = $User.SamAccountName
                Status = $null
            }
            $TargetUserGroupMembership = Get-ADPrincipalGroupMembership $User
            $Comparison = Compare-Object -ReferenceObject $SourceGroups -DifferenceObject $TargetUserGroupMembership
            if (!($Comparison)) {
                $UserResultObject.Status = 'Success'
                }
            else {
                $UserResultObject.Status = 'Error'
                $UserResultObject | Add-Member -NotePropertyName 'DiffGroup' -NotePropertyValue $Comparison.InputObject.name
                $UserResultObject | Add-Member -NotePropertyName 'Source/Target' -NotePropertyValue $Comparison.SideIndicator
                }
            $ResultsArray.Add($UserResultObject)
        }
        Write-Output $ResultsArray
    }
}
