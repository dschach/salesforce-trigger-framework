/**
 * Account Sample handler
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 */
@IsTest
private class AccountSampleTriggerHandlerTest {
	@IsTest
	static void insertUpdateAccount() {
		Account a = new Account(Name = 'TestAcct');

		Test.startTest();
		insert a;

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllUpperCase(), 'Name is not uppercase');
		a.Name = 'TestAcct';
		update a;
		Test.stopTest();

		a = [SELECT Id, Name FROM Account WHERE Id = :a.Id LIMIT 1];
		System.assert(a.Name.isAllLowerCase(), 'Name is not lowercase');
	}
}
