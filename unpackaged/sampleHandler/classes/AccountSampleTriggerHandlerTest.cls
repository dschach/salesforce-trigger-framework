/**
 * Account Sample handler
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 */
@IsTest
private class AccountSampleTriggerHandlerTest {
	@IsTest
	/**
	 * @description Test method to demonstrate using our sample handler and showing limits and debug
	 * @author David Schach
	 */
	static void insertUpdateAccount() {
		TriggerHandler.showDebug();
		Account a = new Account(Name = 'TestAcct');

		Test.startTest();
		insert a;
		TriggerHandler.showDebug(false);

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllUpperCase(), 'Name is not uppercase');
		a.Name = 'TestAcct';
		AccountSampleTriggerHandler.showDebug();
		update a;
		Test.stopTest();

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllLowerCase(), 'Name is not lowercase');
	}
}