#Requires -Modules Pester
#Requires -version 4
#Requires -Modules dbatools
<#
.SYNOPSIS
Operation validation tests (Pester) for Microsoft SQL Cluster
.DESCRIPTION
Test steps
1. Windows Cluster
    1.1. Check both servers are online
    1.2. Check all cluster groups are online
    1.3. Check all cluster resources are online
2. SQL Server
    2.1 Checking all DBs status is normal
    2.2 Check a FULL backup was done in the last 24 hours
    2.3 Check 
 
.PARAMETER clusterName
Name of the cluster
.PARAMETER sqlServerInstance
Name of the clustered sql instance
.EXAMPLE
Invoke-Pester -script @{path = .\SQLCluster.Tests.ps1; Parameters = @{clustername = 'sqlCluster01'; sqlServerInstance = 'sqlserver\prod'}} 
.NOTES
Author: Michael Ansbro
Date: 12/04/2017
Version: 0.8
#>

Param (
    [string]$clusterName,
    [string]$sqlServerInstance
)


$Session = New-PSSession -ComputerName $clusterName

Describe "Checking $clusterName cluster" {
    
    Context 'Testing both servers are responding' {
        It "All cluster nodes active" {
            $Node = (invoke-command -Session $Session {Get-clusterNode})
            foreach ($nodeStatus in ($node.state)) {
                $nodestatus | should be 'Up'
            }
        }
    }
    Context "Checking all Cluster Groups are online" {
        $clusterGroup = Invoke-command -Session $Session {Get-ClusterGroup}
        foreach ($Group in $clusterGroup) {
            It "$($Group.Name) is online" {
                $Group.state | should be 'online'
            }
        }
    }
    Context "Checking all cluster resources are online" {
        $clusterResource = invoke-command -Session $Session {Get-ClusterResource}
        foreach ($resource in $clusterResource) {
            it "$($resource.name) is online" {
                $resource.state | should be 'online'
            }
        }
    }
}

Describe "Checking SQL Server" {
    
    Context 'Check DB status normal' {
        $sqlDB = Get-DbaDatabase -sqlInstance $sqlServerInstance
        foreach ($db in $sqlDB) {
            it "$($db.name) status is normal" { 
                $db.status | should be 'Normal'
            }
        }
    }
    Context 'Full database backup in the last 24 hours' {
        $sqlbackup = Get-DbaLastBackup -SqlServer $sqlServerInstance
        foreach ($sqlDB in $sqlbackup) {
            $sqlDB.Sincefull = [int]($sqlDB.sinceFull -replace ":\d+:\d+")
            It "$($sqlDB.database) full backup in the last 24 hours" {
                $sqldb.SinceFull | should belessthan 24
            }
        }
    }
    Context 'MaxDop recommended setting' {
        $sqlMaxDop = Test-DbaMaxDop -SqlServer $sqlServerInstance
        it 'MaxDop set to recommended value' {
            $sqlMaxDop.currentInstanceMaxDop | should match $sqlMaxDop.recommendedMaxDop
        }

    }
    Context 'MaxMemory recommended setting' {
        $sqlMaxMemory = Test-DbaMaxMemory -SqlServer $sqlServerInstance
        it 'MaxMemory set to recommended value' {
            $sqlMaxMemory.sqlMaxMB | should match $sqlMaxMemory.recommendedMB
        }

    }
Remove-PSSession -Session $Session
}

