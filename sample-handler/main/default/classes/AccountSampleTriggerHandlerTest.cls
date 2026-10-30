/**
 * Tests for the sample handler and the sample trigger. Each test proves 1 behavior through real DML.
 * <br>`AccountSampleTriggerHandler.finishedOperations` is the call log. `andFinally()` adds each operation that the handler finished.
 * <br>The test DML and the queries that read the results run in system mode, so the class suppresses `FlagSystemMode`. The tests set up and check the data directly. The access under test is the access of the handler, which uses system mode on purpose.
 * @author David Schach
 * @since 2021
 * @since 2026-10-30 1 test per behavior, with the finished operations as the call log
 * @group SampleTriggerHandler
 * @see AccountSampleTriggerHandler
 */
@SuppressWarnings('PMD.FlagSystemMode')
@IsTest(isParallel=true testFor='ApexClass:AccountSampleTriggerHandler,ApexTrigger:AccountSampleTrigger')
private inherited sharing class AccountSampleTriggerHandlerTest {
	private static final String HANDLER_NAME = AccountSampleTriggerHandler.class.getName();

	/**
	 * An insert removes the extra spaces from the Account name.
	 */
	@IsTest
	private static void insertNormalizesName() {
		Account newAccount = new Account(Name = '  Sample   Account  ');
		insert as system newAccount;
		Assert.areEqual('Sample Account', nameOf(newAccount.Id), 'the insert should remove the extra spaces');
	}

	/**
	 * An update that changes the name removes the extra spaces from the new name.
	 */
	@IsTest
	private static void updateNormalizesChangedName() {
		Account sampleAccount = insertAccount('Sample Account');
		sampleAccount.Name = 'New   Name ';
		update as system sampleAccount;
		Assert.areEqual('New Name', nameOf(sampleAccount.Id), 'the update should remove the extra spaces from the changed name');
	}

	/**
	 * An update that does not change the name keeps the name as it is.
	 */
	@IsTest
	private static void updateLeavesUnchangedNameAlone() {
		TriggerHandler.bypass(AccountSampleTriggerHandler.class);
		Account sampleAccount = insertAccount('Spaced   Name');
		TriggerHandler.clearBypass(AccountSampleTriggerHandler.class);
		Assert.areEqual('Spaced   Name', nameOf(sampleAccount.Id), 'the bypassed insert should keep the extra spaces');

		sampleAccount.Phone = '555-0100';
		update as system sampleAccount;
		Assert.areEqual('Spaced   Name', nameOf(sampleAccount.Id), 'an update that does not change the name should not change it');
	}

	/**
	 * A changed phone number goes to the child Accounts.
	 */
	@IsTest
	private static void phoneChangeCopiesToChildAccounts() {
		Account parentAccount = insertAccount('Parent Account');
		Account childAccount = insertChildAccount(parentAccount.Id);

		parentAccount.Phone = '555-0100';
		update as system parentAccount;
		Assert.areEqual('555-0100', [SELECT Phone FROM Account WHERE Id = :childAccount.Id WITH SYSTEM_MODE].Phone, 'the child Account should get the new phone number');
	}

	/**
	 * A child Account in the same update as its parent keeps the phone number of its own update. A trigger cannot update the records that it runs for.
	 */
	@IsTest
	private static void childInSameUpdateKeepsItsOwnPhone() {
		Account parentAccount = insertAccount('Parent Account');
		Account childAccount = insertChildAccount(parentAccount.Id);

		parentAccount.Phone = '555-0100';
		childAccount.Phone = '555-0199';
		update as system new List<Account>{ parentAccount, childAccount };
		Assert.areEqual('555-0199', [SELECT Phone FROM Account WHERE Id = :childAccount.Id WITH SYSTEM_MODE].Phone, 'the child Account should keep the phone number of its own update');
	}

	/**
	 * The update of the child Accounts does not run the handler again, because the handler bypasses itself for it.
	 */
	@IsTest
	private static void childUpdateDoesNotRunHandlerAgain() {
		Account parentAccount = insertAccount('Parent Account');
		insertChildAccount(parentAccount.Id);
		AccountSampleTriggerHandler.finishedOperations.clear();
		Integer beforeUpdateRuns = TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_UPDATE);
		Integer afterUpdateRuns = TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_UPDATE);

		parentAccount.Phone = '555-0100';
		update as system parentAccount;
		Assert.areEqual(
			new List<System.TriggerOperation>{ System.TriggerOperation.BEFORE_UPDATE, System.TriggerOperation.AFTER_UPDATE },
			AccountSampleTriggerHandler.finishedOperations,
			'only the update of the parent should run the handler'
		);
		Assert.areEqual(
			beforeUpdateRuns + 1,
			TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_UPDATE),
			'the update of the parent should use 1 before update run, and the child update none'
		);
		Assert.areEqual(
			afterUpdateRuns + 1,
			TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_UPDATE),
			'the update of the parent should use 1 after update run, and the child update none'
		);
	}

	/**
	 * The handler clears its own bypass after it updates the child Accounts.
	 */
	@IsTest
	private static void bypassIsClearedAfterChildUpdate() {
		Account parentAccount = insertAccount('Parent Account');
		insertChildAccount(parentAccount.Id);

		parentAccount.Phone = '555-0100';
		update as system parentAccount;
		Assert.isFalse(TriggerHandler.isBypassed(AccountSampleTriggerHandler.class), 'the handler should not stay bypassed after the child update');
	}

	/**
	 * `andFinally()` runs after all 7 contexts, also the contexts that the handler does not override.
	 */
	@IsTest
	private static void andFinallyRunsAfterEveryContext() {
		Account sampleAccount = insertAccount('Sample Account');
		Assert.areEqual(
			new List<System.TriggerOperation>{ System.TriggerOperation.BEFORE_INSERT, System.TriggerOperation.AFTER_INSERT },
			AccountSampleTriggerHandler.finishedOperations,
			'an insert should finish before insert and then after insert'
		);

		AccountSampleTriggerHandler.finishedOperations.clear();
		sampleAccount.Name = 'Renamed Account';
		update as system sampleAccount;
		Assert.areEqual(
			new List<System.TriggerOperation>{ System.TriggerOperation.BEFORE_UPDATE, System.TriggerOperation.AFTER_UPDATE },
			AccountSampleTriggerHandler.finishedOperations,
			'an update should finish before update and then after update'
		);

		AccountSampleTriggerHandler.finishedOperations.clear();
		delete as system sampleAccount;
		Assert.areEqual(
			new List<System.TriggerOperation>{ System.TriggerOperation.BEFORE_DELETE, System.TriggerOperation.AFTER_DELETE },
			AccountSampleTriggerHandler.finishedOperations,
			'a delete should finish before delete and then after delete'
		);

		AccountSampleTriggerHandler.finishedOperations.clear();
		undelete as system sampleAccount;
		Assert.areEqual(
			new List<System.TriggerOperation>{ System.TriggerOperation.AFTER_UNDELETE },
			AccountSampleTriggerHandler.finishedOperations,
			'an undelete should finish after undelete'
		);
	}

	/**
	 * A bulk insert of more than 200 records runs in chunks, and the loop limit does not stop a chunk.
	 */
	@IsTest
	private static void bulkInsertStaysInsideLoopLimit() {
		List<Account> accounts = new List<Account>();
		for (Integer index = 0; index < 250; index++) {
			accounts.add(new Account(Name = '  Bulk   Account ' + index));
		}
		insert as system accounts;
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the 2 chunks of the insert should each use 1 before insert run');
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_INSERT), 'the 2 chunks of the insert should each use 1 after insert run');
		Assert.areEqual(250, [SELECT COUNT() FROM Account WHERE Name LIKE 'Bulk Account %' WITH SYSTEM_MODE], 'every chunk should remove the extra spaces');
	}

	/**
	 * The constructor sets the class name through the Type constructor of the base class.
	 */
	@IsTest
	private static void constructorRegistersTheHandlerName() {
		Assert.areEqual(HANDLER_NAME, new AccountSampleTriggerHandler().getHandlerName(), 'the constructor should register the class name');
	}

	/**
	 * Inserts an Account with the name.
	 * @param name The Account name.
	 * @return `Account` The new Account.
	 */
	private static Account insertAccount(String name) {
		Account newAccount = new Account(Name = name);
		insert as system newAccount;
		return newAccount;
	}

	/**
	 * Inserts a child Account of the parent.
	 * @param parentId The Id of the parent Account.
	 * @return `Account` The new child Account.
	 */
	private static Account insertChildAccount(Id parentId) {
		Account childAccount = new Account(Name = 'Child Account', ParentId = parentId);
		insert as system childAccount;
		return childAccount;
	}

	/**
	 * Reads the stored name of an Account.
	 * @param accountId The Account Id.
	 * @return `String` The name in the database.
	 */
	private static String nameOf(Id accountId) {
		return [SELECT Name FROM Account WHERE Id = :accountId WITH SYSTEM_MODE].Name;
	}
}