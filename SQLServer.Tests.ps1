#Requires -Modules Pester
#Requires -version 4
#Requires -Modules dbatools
<#
.SYNOPSIS
Operation validation tests (Pester) for Microsoft SQL Server
.DESCRIPTION
Test steps
1. Check services are online
2.  
.EXAMPLE
Invoke-Pester -script @{Path = '.\SQLServer.Tests.ps1'; parameters = @{sqlServerName = lon-sql-01}}
.NOTES
Author: Michael Ansbro
Date: 06/04/2017
Version: 0.5
#>
Param {
    [string]$sqlServerName
}

$Session = New-PSSession -ComputerName $sqlServerName

Describe 'Checking server' {

    Context 'Check SQL Server service started' {
        $sqlService = Get-service -DisplayName "SQL Server*" 
        foreach ($service in $sqlService) {
            it "$($service.DisplayName) is running" {
                $service.status | should be "Running"
            }
        }
    }
}

Describe "Checking SQL Server" {

    Context 'Check DB status normal' {
        $sqlDB = Get-DbaDatabase -sqlInstance $sqlServerName
        foreach ($db in $sqlDB) {
            it "$($db.name) status is normal" { 
                $db.status | should be 'Normal'
            }
        }
    }
    Context 'Full database backup in the last 24 hours' {
        $sqlbackup = Get-DbaLastBackup -SqlServer $sqlServerName
        foreach ($sqlDB in $sqlbackup) {
            $sqlDB.Sincefull = [int]($sqlDB.sinceFull -replace ":\d+:\d+")
            It "$($sqlDB.database) full backup in the last 24 hours" {
                $sqldb.SinceFull | should belessthan 24
            }
        }
    }
    Context 'MaxDop recommended setting' {
        $sqlMaxDop = Test-DbaMaxDop -SqlServer $sqlServerName
        it 'MaxDop set to recommended value' {
            $sqlMaxDop.currentInstanceMaxDop | should match $sqlMaxDop.recommendedMaxDop
        }

    }
    Context 'MaxMemory recommended setting' {
        $sqlMaxMemory = Test-DbaMaxMemory -SqlServer $sqlServerName
        it 'MaxMemory set to recommended value' {
            $sqlMaxMemory.sqlMaxMB | should match $sqlMaxMemory.recommendedMB
        }

    }
Remove-PSSession -Session $Session
}
