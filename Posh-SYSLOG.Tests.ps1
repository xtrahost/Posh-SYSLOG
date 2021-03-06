﻿Import-Module $PSScriptRoot\Posh-SYSLOG.psm1 -Force
Remove-Job -Name SyslogTest1 -Force -ErrorAction SilentlyContinue

Describe 'Send-SyslogMessage' {
    Mock -ModuleName Posh-SYSLOG Get-Date { return (New-Object datetime(2000,1,1)) }

    Mock -ModuleName Posh-SYSLOG Get-NetIPAddress {return $null}

    Mock -ModuleName Posh-SYSLOG Test-NetConnection {
        $Connection = New-Object PSCustomObject
        $Connection | Add-Member -MemberType NoteProperty -Name 'SourceAddress' -Value (New-Object PSCustomObject) -Force
        $Connection.SourceAddress | Add-Member -MemberType NoteProperty -Name 'IPAddress' -Value ('123.123.123.123') -Force
        $Connection.SourceAddress | Add-Member -MemberType NoteProperty -Name 'PrefixOrigin' -Value ('Manual') -Force
        return $Connection
    }

    $ENV:Computername = 'TestHostname'
    $ENV:userdnsdomain = $null
    
    $GetSyslogPacket = {
        $endpoint = New-Object System.Net.IPEndPoint ([IPAddress]::Any,514)
        $udpclient= New-Object System.Net.Sockets.UdpClient 514
        $content=$udpclient.Receive([ref]$endpoint)
        [Text.Encoding]::ASCII.GetString($content)
    } 

    Context 'Parameter Validation' {
        It 'Should not accept a null value for the server' {
            {Send-SyslogMessage -Server $null -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth'} | Should Throw 'The argument is null or empty'
        }

        It 'Should not accept a null value for the message' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message $null -Severity 'Alert' -Facility 'auth'} | Should Throw 'The argument is null or empty'
        }

        It 'Should not accept a null value for the severity' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity $null -Facility 'auth'} | Should Throw 'Cannot convert null to type "Syslog_Severity"'
        }

        It 'Should not accept a null value for the facility' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility $null} | Should Throw 'Cannot convert null to type "Syslog_Facility"'
        }

        It 'Should not accept a null value for the hostname' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -Hostname $null} | Should Throw 'The argument is null or empty'
        }

        It 'Should not accept a null value for the application name' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -ApplicationName $null} | Should Throw 'The argument is null or empty'
        }

        It 'Should not accept a null value for the timestamp' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -Timestamp $null} | Should Throw 'Cannot convert null to type "System.DateTime"'
        }

        It 'Should not accept a null value for the UDP port' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -UDPPort $null} | Should Throw 'Cannot validate argument on parameter'
        }

        It 'Should not accept an invalid value for the UDP port' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -UDPPort 456789789789} | Should Throw 'Error: "Value was either too large or too small for a UInt16.'
        }

        It 'Should reject ProcessID parameter if -RFC3164 is specified' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -RFC3164 -ProcessID 1} | Should Throw 'Parameter set cannot be resolved using the specified named parameters'
        }

        It 'Should reject MessageID parameter if -RFC3164 is specified' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -RFC3164 -MessageID 1} | Should Throw 'Parameter set cannot be resolved using the specified named parameters'
        }

        It 'Should reject StructuredData parameter if -RFC3164 is specified' {
            {Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -RFC3164 -StructuredData 1} | Should Throw 'Parameter set cannot be resolved using the specified named parameters'
        }
    }

    Context 'Severity Level Calculations' {
        It 'Calculates the correct priority of 0 if Facility is Kern and Severity is Emergency' {
            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Emergency' -Facility 'kern'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<0>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            
        }

        It 'Calculates the correct priority of 7 if Facility is Kern and Severity is Debug' {
            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Debug' -Facility 'kern'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<7>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            $UDPResult | Should Be $Expected
        }   

        It 'Calculates the correct priority of 24 if Facility is daemon and Severity is Emergency' {
            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Emergency' -Facility 'daemon'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<24>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            $UDPResult | Should Be $Expected
        }

        It 'Calculates the correct priority of 31 if Facility is daemon and Severity is Debug' {
            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Debug' -Facility 'daemon'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<31>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            $UDPResult | Should Be $Expected
        }
    }

    Context 'RFC 3164 Message Format' {      
        start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
        Start-Sleep 2
        $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -RFC3164
        Start-Sleep 2
        $UDPResult = Receive-Job SyslogTest1
        Remove-Job SyslogTest1
        $Expected = '<33>Jan 01 00:00:00 TestHostname Posh-SYSLOG.Tests.ps1 Test Syslog Message'

        It 'Should send RFC5424 formatted message' {
            $UDPResult | Should Be $Expected
        }

        It 'Should not return any value' {
            $TestCase | Should be $null
        }
    }

    Context 'RFC 5424 message format' {
        start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
        Start-Sleep 2
        $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth'
        Start-Sleep 2
        $UDPResult = Receive-Job SyslogTest1
        Remove-Job SyslogTest1
        $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
        $Expected = '<33>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID

        It 'Should send RFC5424 formatted message' {
            $UDPResult | Should Be $Expected
        }

        It 'Should not return any value' {
            $TestCase | Should be $null
        }
    }

    Context 'Hostname determination' {              
        It 'Uses any hostname it is given' {
            Start-Job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth' -Hostname 'SomeRandomHostNameDude'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<33>1 {0} SomeRandomHostNameDude Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            $UDPResult | Should Be $Expected
        }

        It 'Uses the FQDN if the computer is domain joined' {
            $ENV:userdnsdomain = 'contoso.com'
            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<33>1 {0} TestHostname.contoso.com Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
            $ENV:userdnsdomain = ''
            $UDPResult | Should Be $Expected
        }

        It 'Uses a Static IP address, on the correct interface that the server is reached on, if no FQDN and not hostname specified' {
            Mock -ModuleName Posh-SYSLOG Get-NetIPAddress {return 'value'}          

            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<33>1 {0} 123.123.123.123 Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID
      
            $UDPResult | Should Be $Expected
        }

        It 'Uses the Windows computer name, if no static ip or FQDN' {
            Mock -ModuleName Posh-SYSLOG Get-NetIPAddress {return $null} 

            start-job -Name SyslogTest1 -ScriptBlock $GetSyslogPacket
            Start-Sleep 2
            $TestCase = Send-SyslogMessage -Server '127.0.0.1' -Message 'Test Syslog Message' -Severity 'Alert' -Facility 'auth'
            Start-Sleep 2
            $UDPResult = Receive-Job SyslogTest1
            Remove-Job SyslogTest1
            $ExpectedTimeStamp = (New-Object datetime(2000,1,1)).ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
            $Expected = '<33>1 {0} TestHostname Posh-SYSLOG.Tests.ps1 {1} - - Test Syslog Message' -f $ExpectedTimeStamp, $PID

            $UDPResult | Should Be $Expected
        }
    }

    Context 'Scrypt Analyzer' {
        It 'Does not have any issues with the Script Analyser' {
            Invoke-ScriptAnalyzer .\Functions\Send-SyslogMessage.ps1 | Should be $null
        }
    }
}