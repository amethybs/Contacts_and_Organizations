/*
    Copyright (c) 2009, Salesforce.com Foundation
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.com Foundation
* @date 2011 (1.x)
* @description Provides opportunity and contact role support for all models  
*/
public without sharing class OpportunityContactRoles {

    /// <name> ContactRoles </name>
    /// <summary> Default Constructor </summary>
    public OpportunityContactRoles(){}

    /// <name> ContactRoles </name>
    /// <summary> Overloads the ContactRoles object constructor to handle ContactRoles processing </summary>
    public OpportunityContactRoles(Map<Id, Opportunity> oppList){
        List<Opportunity> triggerOpps = oppList.values();
 //       Set<Id> triggerOppIDs = oppList.keySet();
       // Boolean haveCheckedOpportunityRoles = false;
                
//        List<Opportunity> oppsToProcess = new List<Opportunity>();
        List<OpportunityContactRole> CRUpdates = new List<OpportunityContactRole>();

        Map<Id, Opportunity> oppsInsertCR = oppList.clone();

        //Get existing contact roles for the trigger opps. 
        List<OpportunityContactRole> CRs = [select OpportunityId, ContactId, Role, IsPrimary from OpportunityContactRole where IsPrimary = true and OpportunityId in :oppsInsertCR.keySet()];

        //Check for primary CR with no role value; save those for updates.
        if(CRs.size() > 0){
            for(OpportunityContactRole cr : CRs){
                if(cr.Role == null){
                    CRUpdates.add(cr);
                }
                oppsInsertCR.remove(cr.OpportunityId);
            }
        }
        /*
        //No existing primary, so add the trigger opps for contact role creation.
        else {
            for(Opportunity o : triggerOpps){
                oppsToProcess.add(o);
            }
        }*/

        //Create CRs.
        if (oppsInsertCR.size() > 0){
            insertCR(oppsInsertCR.values());
        }

        //Update existing CRs.
        if (CRUpdates.size() > 0){
            updateCR(CRUpdates);
        }

      //  haveCheckedOpportunityRoles = true;
    }

    /// <name> getDefaultRole </name>
    /// <summary> Return the default role from the custom setting.  Use custom setting for default role value.</summary>
    public static String getDefaultRole(){
        return Constants.getContactsSettings().Opportunity_Contact_Role_Default_role__c;
    }

    /// <name> insertCR </name>
    /// <summary> Creates a new Contact Role record when an opp is inserted and there is no primary CR.  Use custom setting for default role value.</summary>
    /// <param name="opportunties"> List of opportunities meeting trigger criteria </param>
    public static void insertCR(Opportunity[] opportunities){

        List<OpportunityContactRole> CRs = new List<OpportunityContactRole>();

        //Straightforward creation of opp contact role.      
        for(Opportunity o : opportunities){
            if(o.Contact_ID_for_Role__c != null) {
                try {
                    CRs.add(new OpportunityContactRole(OpportunityId = o.Id, ContactId = o.Contact_ID_for_Role__c, Role = OpportunityContactRoles.getDefaultRole(), IsPrimary = true));
                } catch (exception e) {
                    o.addError(Label.Opportunity_Contact_Role_Error_Bad_Contact_Id);
                }
            }
        }
        if (CRs.size() > 0){
            Database.SaveResult[] lsr = Database.insert(CRs, false); 
        }
    }

    /// <name> UpdateCR </name>
    /// <summary> Update a primary contact role where the role field is empty.  Use custom setting for default role value.</summary>
    /// <param name="CRs"> List of contact roles  </param>
    public static void updateCR(OpportunityContactRole[] CRs){

        for(OpportunityContactRole cr : CRs){
            cr.Role = OpportunityContactRoles.getDefaultRole();
        }
        Database.SaveResult[] lsr = Database.update(CRs, false);
    }
    //truncate string representation of an ID to 15 chars
    public static string shortenId(String idForShortening){
    	if(idForShortening.length() >= 15) {
    		idForShortening = idForShortening.subString(0,15);
    	}    		
    	return idForShortening;
    }
    //fill one-to-one accounts for Opportunities where a Contact id is supplied
    public static void opportunityAccounts(List<Opportunity> oppList){
    	
        Map<String,Account> contactsAndOneToOneAccounts = new Map<String,Account>();
        Set<String> primaryContactIds = new Set<String>();
        Set<Id> oppAccounts = new Set<Id>();
        
        for(Opportunity o : oppList){
        	if(o.AccountId != null && o.Contact_Id_for_role__c == null){
        		oppAccounts.add(o.AccountId);
        	}
        	
            if(o.AccountId == null && o.Contact_Id_for_role__c != null){
                primaryContactIds.add(o.Contact_Id_for_role__c);                
            }
        }
        Map<Id,Account> primaryAccounts = new Map<Id,Account>([select id, One2OneContact__c from Account where id IN :oppAccounts]);
         
        List<Contact> primaryContacts = new List<Contact>();
        primaryContacts = [select AccountId,Account.Id,Account.SYSTEM_AccountType__c from Contact where Id IN :primaryContactIds];
        for(Contact thisContact : primaryContacts) {
       		contactsAndOneToOneAccounts.put(shortenId(string.valueOf(thisContact.Id)),thisContact.Account);
        }
        //loop through opps again and then put the right accountid on the opp
        for(Opportunity o : oppList){
        	//add the contact id from the Account. if it's not valid it won't error
        	if(o.AccountId != null && o.Contact_Id_for_role__c == null){ 
        		o.Contact_Id_for_role__c = primaryAccounts.get(o.AccountId).One2OneContact__c;
        	}
        	
            if(o.AccountId == null && o.Contact_Id_for_role__c != null){                //using the contact id, pull the account from the map
                
                if(contactsAndOneToOneAccounts.get(shortenId(o.Contact_Id_for_role__c))!=null){
                	Account accountForContact = contactsAndOneToOneAccounts.get(shortenId(o.Contact_Id_for_role__c));
                	//for one-to-one accounts, set the account id
                	if(accountForContact.SYSTEM_AccountType__c == Constants.ONE_TO_ONE_ORGANIZATION_TYPE){
                		o.AccountId = accountForContact.Id;
                	}
                } else {
                    o.addError(Label.Opportunity_Contact_Role_Error_Bad_Contact_Id);
                }            
            }
        }       
    }       
}