$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
$odatapath = join-path $here "odata"

Invoke-Expression (gc "$here\..\PshOdata.psm1" |out-String)

$class = New-PshOdataClass Process -PK ID -Properties 'Name','ID'

Describe "New-PshOdataClass" {
    It "Returns a psobject with the provided name" {
        $class.name | Should Be "Process"
    }
	It "Returns a psobject with the provided PK" {
		$class.pk | Should Be "ID"
	}
	It "Returns a psobject with two properties" {
		$class.properties.count |Should Be 2
	}
	It "New-PshOdataClass with only one property should return a list with one element in it" {
		(New-PshOdataClass TestClass -PK ID -Properties 'ID').properties.count |Should Be 1
	}
}

Describe "Add-PshOdataMethod" {
	It "Validate that optional parameters are optional" {
		{$class |Add-PshOdataMethod -verb get -cmdlet get-process} |should not Throw
	}
	It "Creates a GET method" {
		{$class |Add-PshOdataMethod -verb get -cmdlet get-process -Params Name, ID -FilterParams Name} |should not Throw
	}
	It "Sets the get property of the class" {
		$class.get |should not BeNullOrEmpty
	}
	It "Validates the get property's module property" {
		$class.get.module |Should be "c:\windows\system32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Management"
	}
	It "Should not set the update property of the class when only the get method was added" {
		$class.update|should BeNullOrEmpty
	}
	It "Creates a DELETE method" {
        {$class |Add-PshOdataMethod -verb delete -cmdlet stop-process -FilterParams ID} |should not Throw
	}
	It "Fails if the DELETE method has a FieldParam that is not the pk" {
        {$class |Add-PshOdataMethod -verb delete -cmdlet stop-process -FilterParams Name} |Should Throw
	} 
	It "Fails if the DELETE method has a value for the params argument" {
        {$class |Add-PshOdataMethod -verb delete -cmdlet stop-process -FilterParams ID -params ID,Name} |Should Throw
	} 
	It "Fails if verb is not valid" {
		{$class |Add-PshOdataMethod -verb blah -cmdlet dir -pk ID -Params Name, ID -FilterParams Name} |should Throw
	}
	It "Fails if cmdlet is not valid" {
		{$class |Add-PshOdataMethod -verb get -cmdlet dir -pk ID -Params Name, ID -FilterParams Name} |should Throw
	}
    It "Correctly grabs the module for the GET method" {
        $class.get.module| Should be "c:\windows\system32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Management"
    }
    It "Supports PassThru" {
        (New-PshOdataClass Process -PK ID -Properties 'Name','ID'|Add-PshOdataMethod -PassThru -verb get -cmdlet get-process -Params Name, ID -FilterParams Name).Get.Module | Should be "c:\windows\system32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Management"
    }
}

function CommandWith2ParamSets {
    param(
        [Parameter(Mandatory=$true,ParameterSetName="set1")]
        [string] $set1param,
        [Parameter(Mandatory=$true,ParameterSetName="set2")]
        [string] $set2param,
        [Parameter(Mandatory=$false)]
        [switch] $switchparam
    )
}
Describe "Get-ParameterSetXML" {
    It "Does not work with an invalid command" {
        {Get-ParameterSetXML 'lskdfjlsdfjlksdfjljdfkljdsf'} |should Throw
    }
    It "Converts the ParameterSet of a command into appropriate schema.xml syntax" {
        Get-ParameterSetXML CommandWith2ParamSets |Should be @'
          <ParameterSets>
            <ParameterSet>
              <Name>set1</Name>
              <Parameter>
                <Name>set1param</Name>
                <Type>System.String[], mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089</Type>
                <IsMandatory>True</IsMandatory>
              </Parameter>
              <Parameter>
                <Name>switchparam</Name>
                <Type>System.Management.Automation.SwitchParameter, System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35</Type>
                <IsSwitch>True</IsSwitch>
              </Parameter>
            </ParameterSet>
            <ParameterSet>
              <Name>set2</Name>
              <Parameter>
                <Name>set2param</Name>
                <Type>System.String[], mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089</Type>
                <IsMandatory>True</IsMandatory>
              </Parameter>
              <Parameter>
                <Name>switchparam</Name>
                <Type>System.Management.Automation.SwitchParameter, System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35</Type>
                <IsSwitch>True</IsSwitch>
              </Parameter>
            </ParameterSet>
          </ParameterSets>

'@
    }
}

Describe "ConvertTo-MofText" {
	It "Converts a class to the text required in a Mof file" {
		$class |ConvertTo-MofText |Should be @'
class mosd_Process
{
    [Key] String ID;
    String Name;
};

'@
	}
}

Describe "ConvertTo-ResourceXML" {
    It "Converts a class to the text needed in the resource section of the schema.xml" {
        $class |ConvertTo-ResourceXML |Should be @'
        <Resource>
            <RelativeUrl>Process</RelativeUrl>
            <Class>mosd_Process</Class>
        </Resource>

'@
    }
}

$validatexml = [IO.file]::ReadAllText((join-path $here validate_schema.xml))
Describe "ConvertTo-ClassXML" {
    It "Converts a class to the text needed in the class section of the schema.xml" {
        $class |ConvertTo-ClassXML |Should BeExactly $validatexml
    }
}

Describe "New-PshOdataEndpoint" {
	It "New-PshOdataEndpoint succeeds if the folder exists and the -Force switch is used" {
		{$class |New-PshOdataEndpoint -Path $odatapath} |Should Not Throw
	}
	It "New-PshOdataEndpoint should fail if the folder exists" {
		{$class |New-PshOdataEndpoint -Path $odatapath} |Should Throw
	}
	It "NewPshOdataEndpoint succeeds if the folder exists and the -Force switch is used" {
		{$class |New-PshOdataEndpoint -Path $odatapath -Force} |Should Not Throw
	}
    It "Should create schema.mof" {
        join-path $odatapath schema.mof |Should exist
    }
    It "Should create schema.xml" {
        join-path $odatapath schema.xml |Should exist
    }
    It "Should create RbacConfiguration.xml" {
        join-path $odatapath RbacConfiguration.xml |Should exist
    }
    It "Validate data in RbacConfiguration.xml" {
        [IO.file]::ReadAllText((join-path $odatapath RbacConfiguration.xml)) |Should be @"
<?xml version="1.0" encoding="utf-8"?>
<RbacConfiguration>
<Groups><Group Name="UserGroup" MapIncomingUser="true"><Modules>
<Module>c:\windows\system32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Management</Module>
</Modules></Group></Groups>
<Users DefaultGroup="UserGroup"></Users>
</RbacConfiguration>

"@
    }
}

# cleanup the directory created during the tests
rm $odatapath -recurse

