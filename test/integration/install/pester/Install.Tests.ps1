Describe "codedeployagent service" {
    It "is installed" {
        (Get-Service codedeployagent).length | Should Be 1
    }

    It "is stopped" {
        (Get-Service codedeployagent).status | Should Be "Stopped"
    }

    It "is disabled" {
        (Get-Service codedeployagent).StartType | Should Be "Manual"
    }
}
