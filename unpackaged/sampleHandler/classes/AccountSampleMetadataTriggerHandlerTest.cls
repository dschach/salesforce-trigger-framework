/**
 * @description
 *
 * @author      David Schach
 * @since       2023
 * @group       SampleTriggerHandler
 */
@IsTest
public with sharing class AccountSampleMetadataTriggerHandlerTest {
	@IsTest
	/**
	 * @description Test method to demonstrate using our sample handler and showing limits and debug
	 * @author David Schach
	 */
	static void insertUpdateAccount() {
		MetadataTriggerHandler.showDebug();
		Account a = new Account(Name = 'TestAcct');

		Test.startTest();
		insert a;
		MetadataTriggerHandler.showDebug(false);

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllUpperCase(), 'Name is not uppercase');
		a.Name = 'TestAcct';
		AccountSampleMetadataTriggerHandler.showDebug();
		update a;
		Test.stopTest();

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllLowerCase(), 'Name is not lowercase');
	}
}