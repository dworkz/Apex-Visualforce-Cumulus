global without sharing class OpportunitySoftCrediters_TDTM extends npsp.TDTM_Runnable {

// the main entry point for TDTM to invoke our trigger handlers.
global override DmlWrapper run
(List<SObject> newList,   List<SObject> oldList, npsp.TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {
DmlWrapper dmlWrapper = null;

if (triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
dmlWrapper = new DmlWrapper();
     map<Id, Opportunity> newOppMap = new map<Id, Opportunity>((List<Opportunity>)newList);         
     map<Id, Opportunity> oldOppMap = new map<Id, Opportunity>((List<Opportunity>)oldList);
map<Id, Opportunity> oppForProcessing = new map<Id, Opportunity>();

for (Opportunity o : newOppMap.values()) {
if (o.isClosed && o.isWon) {
if(!oldOppMap.get(o.Id).isClosed || !oldOppMap.get(o.Id).isWon || o.Amount_Paid__c != oldOppMap.get(o.Id).Amount_Paid__c || o.Time__c != oldOppMap.get(o.Id).Time__c) {
oppForProcessing.put(o.Id, o);
}
}
}
list<OpportunityContactRole> influencersList = new list<OpportunityContactRole>(); 
 
influencersList = [Select Role, OpportunityId, Id, ContactId From OpportunityContactRole WHERE OpportunityId IN :oppForProcessing.keySet() AND Role IN :getRoles()];
   if(!influencersList.isEmpty()) {
   list<Soft_Credit__c> softCreditListToInsert = new list<Soft_Credit__c>();
   list<Soft_Credit__c> softCreditListToUpdate = new list<Soft_Credit__c>();
   list<Soft_Credit__c> ExistingSoftCreditList = new list<Soft_Credit__c>();
   Soft_Credit__c sc; 
   list<String> influencersContactIdList = getContactIds(influencersList);
   list<Soft_Credit__c> existingSoftCredits = new list<Soft_Credit__c>();
   existingSoftCredits = [Select Time_influenced__c, Name, Id, Donation_Close_Date__c, DonationId__c, ContactId__c, Amount_influenced__c From Soft_Credit__c Where ContactId__c IN :influencersContactIdList AND DonationId__c IN :oppForProcessing.keySet()];
   for(OpportunityContactRole oppCont: influencersList){
   sc = getSoftCreditByContactIdAndDonationId(existingSoftCredits, oppCont.ContactId, oppCont.OpportunityId);
   if(sc != null){
   sc.Amount_influenced__c = newOppMap.get(oppCont.OpportunityId).Amount; //  = newOppMap.get(oppCont.OpportunityId).Amount_Paid__c; 
sc.Time_influenced__c = newOppMap.get(oppCont.OpportunityId).Time__c;
softCreditListToUpdate.add(sc);
   }else{
   sc = new Soft_Credit__c();
   sc.Name = newOppMap.get(oppCont.OpportunityId).Name + ' Soft Credit';
   sc.ContactId__c = oppCont.ContactId;
   sc.Donation_Close_Date__c = newOppMap.get(oppCont.OpportunityId).CloseDate;
   sc.DonationId__c = oppCont.OpportunityId;
   sc.Amount_influenced__c =  newOppMap.get(oppCont.OpportunityId).Amount; // newOppMap.get(oppCont.OpportunityId).Amount_Paid__c; 
   sc.Time_influenced__c = newOppMap.get(oppCont.OpportunityId).Time__c;
softCreditListToInsert.add(sc);
   }
   }
   system.debug('VPROK TEST  = ' + softCreditListToUpdate);
if(!softCreditListToInsert.isEmpty()) {
dmlWrapper.objectsToInsert.addAll((List<Sobject>)softCreditListToInsert);
}
if(!softCreditListToUpdate.isEmpty()) {
dmlWrapper.objectsToUpdate.addAll((List<Sobject>)softCreditListToUpdate);
}
}
}

return dmlWrapper;
}
//***** HELPER METHODS *****//

// dynamically create list of ContactRoles that fit the criteria(must include "Soft Credit" string) 
private list<String> getRoles(){
list<String> result = new list<String>();
Schema.DescribeFieldResult fieldResult = OpportunityContactRole.role.getDescribe();
List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
for(Schema.PicklistEntry f : ple){
if(f.getValue().contains('Soft Credit')){
result.add(f.getValue());
}
}
return result;
}

private list<String> getContactIds (list<OpportunityContactRole> ocrList){
list<String> result = new list<String>();
for(OpportunityContactRole ocr: ocrList){
result.add(ocr.ContactId);
}
return result;
}

private Soft_Credit__c getSoftCreditByContactIdAndDonationId(list<Soft_Credit__c> existingSoftCredits, String ContactId, String OpportunityId){
//Soft_Credit__c result = new Soft_Credit__c();
for(Soft_Credit__c sc: existingSoftCredits){
if(sc.ContactId__c.equals(ContactId) && sc.DonationId__c.equals(OpportunityId)){
return sc; 
}
}
return null;
} 
}

TestClass:

/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(SeeAllData=true)
private class test_OpportunitySoftCrediters_TDTM {


private static Contact testContact;
private static Opportunity testDonation;
private static Contact testInfluencer;
private static OpportunityContactRole donator;
private static OpportunityContactRole influencer;

// init method that occures before startTest() method. All recods created in this method.
private static void init() {   
testContact = new Contact(FirstName = 'TestFirstName', LastName = 'Test LastName');
testInfluencer = new Contact(FirstName = 'TestInfluencerFirstName', LastName = 'TestInfluencer LastName');
insert(testContact);
insert(testInfluencer);
testDonation = new Opportunity(AccountId = testContact.AccountId, Name = 'TestDonation', StageName = 'Qualification', Contribution_Type__c = 'Money', CloseDate = system.today());
insert(testDonation);
donator = new OpportunityContactRole(OpportunityId = testDonation.Id, ContactId = testContact.Id, Role = 'Donor');
influencer = new OpportunityContactRole(OpportunityId = testDonation.Id, ContactId = testInfluencer.Id, Role = getRoles().get(0));
insert(donator);
insert(influencer);
}


    static testMethod void myUnitTest() {
        init();
        test.startTest();
        testDonation.StageName = 'Stewardship';
        update(testDonation);
        list<Soft_Credit__c> scList = [SELECT ID FROM Soft_Credit__c WHERE ContactId__c = :testInfluencer.Id];
        system.assertEquals(scList.size(), 1);
        test.StopTest();
    }
    
    
    //HELPER METHODS
    private static list<String> getRoles(){
list<String> result = new list<String>();
Schema.DescribeFieldResult fieldResult = OpportunityContactRole.role.getDescribe();
List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
for(Schema.PicklistEntry f : ple){
if(f.getValue().contains('Soft Credit')){
result.add(f.getValue());
}
}
return result;
}
    
}
