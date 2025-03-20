# MSAzureOnboarding
Automated Process for Onboarding Employees to a company in an Azure Environment

# Resources
![image.png](/.attachments/image-2b9e4fe5-eec6-4154-ba79-d479bf43fefc.png)

# Main Flow
![image.png](/.attachments/image-ad4ae86c-7745-4ffa-9391-5363703baa51.png)

The features of this new process:
- E3 and E5 license check prior to user creation, alert sent when out of licenses
- More user friendly flow success and failure messages to IT Help
- Built in monitoring and alerts when flows fails, alerts within one hour
- Added approval process and sends copy to HR for review
- More emails to the requestor, approver and IT team to allow clear tracking of the onboarding process.
- Email litigation turned on by default using PowerShell script for all new users
- If selected: Jetbrains ReSharper license assignment automated using the JetBrains API
- Automatically add users to JIRA through the JIRA API and into the VG Organsiation
- Automatically adds location properties based on office location so that email signatures appear more professional
- Automatically assigns Usage Location in Entra ID based on office location to ensure better security detections for Microsoft Sentinel

# SharePoint Form

![image.png](/.attachments/image-bdb3e783-0fc2-47f7-9c3e-f98f525100de.png)

The form takes in the following parameters:
- Start Date
- First Name
- Last Name
- Job Title
- Mobile Number
- Department
- Office Location
- Approver
- Supervisor
- Select Required Hardware
- Select Required Software
- Minimum Laptop Specifications
- Additional Comments

Once the user fills in the form, it can then be used to activate the logic app every 10 minutes. 

Anytime you need to add additional columns, simply click the + Add column on the right of the page:
![image.png](/.attachments/image-adf644fc-9e14-4241-9648-fa06c5046b2e.png)

Then select the correct field needed. Once you have set up the proper fields, you then need to click **Integrate > Power Apps > Customize Forms**.

![image.png](/.attachments/image-4c532ceb-5b4e-4fcc-8378-cc5a15e4e81e.png)

On the fields pane on the left, make sure to add the right field and check to make sure all features are correct. In some cases, you may need to manually toggle the features such as required and default value. 

![image.png](/.attachments/image-7d743b5e-4422-46bd-9f22-10ca4ba4fdc1.png)

You can drag the fields around in the list to rearrange them, try not to break the layout! Undo if anything disastrous happens.

Once completed, make sure to **publish** the change.

# SharePoint Form Logic App
The logic app checks every 10 minutes for updated to the SharePoint form and runs the logic flow. 

1. The approver and HR will receive an email where they can click approve or reject the onboarding request. If rejected, the flow will terminate, only one person needs to select the option. HR is informed they only need to select the option if the manager is on leave.
2. Once approved, the user will be created in Azure AD
3. Before user creation occurs, we check E3 and E5 licenses, if there are no licenses an email is sent to JIRA

We check for E3 and E5 licenses using the MS Graph API through the logic app HTTP:

| License | SKU ID | Content-type | URI | Method |
|--|--|--|--|--|
| E3 | 71a9d935-2760-4973-b514-a5c33566cc4b_05e9a617-0261-4cee-bb44-138d3ef5d965 | application/json | https://graph.microsoft.com/v1.0/subscribedSkus/71a9d935-2760-4973-b514-a5c33566cc4b_05e9a617-0261-4cee-bb44-138d3ef5d965 | GET |
| E5 Security | 71a9d935-2760-4973-b514-a5c33566cc4b_26124093-3d78-432b-b5dc-48bf992543d5 | application/json | https://graph.microsoft.com/v1.0/subscribedSkus/71a9d935-2760-4973-b514-a5c33566cc4b_26124093-3d78-432b-b5dc-48bf992543d5 | GET |

In the JSON API response, the **consumedUnits** is how much we have used and in the JSON **prepaidUnits { properties { enabled }}** is how much we have in total. So, to calculate how many units available, we simple find the difference of the two.

4. If the user creation fails, an email will be sent
![image.png](/.attachments/image-a86a4733-dd99-4a30-a494-4c5cc8217464.png)

To run the scope User Creation Fails, the previous actions must have been a fail, otherwise it will skip. This checks if there has been a duplicate name created or any other error with Azure AD creation. The Get Manager action run at the following setting:
![image.png](/.attachments/image-79ecb189-c63a-4af4-abd3-f0cef57535e7.png)
This is because, if the condition does not match for User Creation Fails, it will be skipped by the logic app and so we must continue the flow by using skipped.

5. User assigned manager
6. Onboarding information is sent to JIRA
7. Assigned location property based on Office Location (this is done through MS Graph using HTTP PATCH), usage location is required for license assignments

8. Runs the **aa-onboardingPS** runbook for the Powershell script.

## Assigned Roles
|Role Name| Env | ID |
|--|--|--|
| Lifecycle Workflows Administrator | RBAC |  |
| User-LifeCycleInfo.ReadWrite.All | MS Graph (00000003-0000-0000-c000-000000000000) | 925f1248-0f97-47b9-8ec8-538c54e01325 |
| User Administrator | RBAC |  |
| Directory Reader | RBAC |  |
| Directory.Read.All | MS Graph (00000003-0000-0000-c000-000000000000) | 7ab1d382-f21e-4acd-a863-ba3e13f7da61 |

## Alerts
The alert rule to monitor if there were any failures will send an email.

# Automation Account Runbook (PowerShell)

## PowerShell Script

Currently the PowerShell script turn on email litigation for an indefinite period of time. Scripts can be added here for the future.

```
param (
    [Parameter (Mandatory = $true)] 
    [String]$Username
)
$CustomerDefaultDomainname = "contoso.onmicrosoft.com"

Write-Output "Username" $Username

Write-Output "Connecting to Exchange Online"
Connect-ExchangeOnline -ManagedIdentity -Organization valocityglobal.com 

$Mailbox = Get-Mailbox | Where {$_.PrimarySmtpAddress -eq $Username}

#Enable Litigation Hold for new user
Set-Mailbox $Mailbox -LitigationHoldEnabled $true
Write-Output "Litigation Hold Applied"

#Disconnect
Disconnect-ExchangeOnline
Write-Output "Disconnected"
```
1. The ```param ()``` at the start of the script indicated the mandatory fields required to run the script. In this case, the user email address is set as the variable ```$Username```.

2. Connecting to Exchange Online using a managed identity which is the system assigned managed identity from the Automation Account.

3. Then the script applies ltigation hold for an indefinate amount of time.

4. The connection with Exchange Online is then disconnected

###Litigation Hold
In the script, litigation hold is applied to the user mailbox. Below shows how Microsoft handles litigation holds.

<IMG  src="https://learn.microsoft.com/en-us/exchange/exchangeserver/media/itpro_recoverableitems.gif?view=exchserver-2019"  alt="Recoverable Items folder."/>

## Assigned Roles
|Role Name| Env | ID |
|--|--|--|
| Exchange.ManageAsApp | Exchange (00000002-0000-0ff1-ce00-000000000000)| 7ab1d382-f21e-4acd-a863-ba3e13f7da61 |
| Exchange Administrator | RBAC |  |

### PowerShell Runbooks
The following modules must be imported for the PowerShell to run properly:
- ExchangeOnlineManagement
- PackageManagement
- PowerShellGet

## Alerts
The alert rule to monitor if there were any failures is called **aa-aue-prod-onboardingPS runbook has failed**. This will send an email to JIRA.
