/**
 * A sample Account trigger handler that shows how to use the framework.
 * <br>Before insert and before update, it removes extra spaces from each new or changed Account name.
 * <br>After update, it copies a changed phone number to the child Accounts. It bypasses itself for that update, so the update does not run this handler again.
 * <br>A loop limit stops recursion that the bypass does not stop. `andFinally()` runs after each context.
 * <br>A trigger runs without sharing, so this `inherited sharing` handler does too. Each query and DML statement names `SYSTEM_MODE`, so the handler can update child Accounts that the running user cannot edit.
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 * @group-content doc-assets/files/sampletriggerhandlerhome.html
 * @see AccountSampleTriggerHandlerTest
 */
public inherited sharing class AccountSampleTriggerHandler extends TriggerHandler {
	/**
	 * The maximum number of runs of each trigger operation of this handler in 1 transaction. Each chunk of 200 records uses 1 run. So 50 allows an update of 10,000 records, which runs before update and after update 50 times each.
	 */
	private static final Integer MAX_LOOP_COUNT = 50;

	/**
	 * The trigger operations that this handler finished in the transaction, in order. `andFinally()` adds each one.
	 */
	@TestVisible
	private static List<System.TriggerOperation> finishedOperations = new List<System.TriggerOperation>();

	/**
	 * The new Accounts of the trigger, cast from `Trigger.new`.
	 */
	private List<Account> newRecords;

	/**
	 * The old Accounts of the trigger by Id, cast from `Trigger.oldMap`. It is null in an insert.
	 */
	private Map<Id, Account> oldRecordsMap;

	/**
	 * Creates the handler for the trigger. It passes its class to the base class, so the base class does no name lookup. It casts the trigger collections that the handler uses, and it sets the loop limit.
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 */
	public AccountSampleTriggerHandler() {
		super(AccountSampleTriggerHandler.class);
		this.newRecords = (List<Account>) Trigger.new;
		this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
		this.setMaxLoopCount(MAX_LOOP_COUNT);
	}

	/**
	 * Removes extra spaces from the name of each new Account.
	 */
	public override void beforeInsert() {
		normalizeNames(newRecords);
	}

	/**
	 * Removes extra spaces from each Account name that changed.
	 */
	public override void beforeUpdate() {
		List<Account> renamedAccounts = new List<Account>();
		for (Account updatedAccount : newRecords) {
			if (updatedAccount.Name != oldRecordsMap.get(updatedAccount.Id).Name) {
				renamedAccounts.add(updatedAccount);
			}
		}
		normalizeNames(renamedAccounts);
	}

	/**
	 * Copies each changed phone number to the child Accounts.
	 */
	public override void afterUpdate() {
		Map<Id, String> phoneByParentId = new Map<Id, String>();
		for (Account updatedAccount : newRecords) {
			if (updatedAccount.Phone != oldRecordsMap.get(updatedAccount.Id).Phone) {
				phoneByParentId.put(updatedAccount.Id, updatedAccount.Phone);
			}
		}
		if (phoneByParentId.isEmpty()) {
			return;
		}
		copyPhoneToChildAccounts(phoneByParentId);
	}

	/**
	 * Records the finished operation. A real handler puts work here that must follow each context, for example a rollup.
	 * <br>`andFinally()` runs after each context. For an insert, an update, or a delete, it runs 2 times for each chunk of 200 records: after the before context and after the after context.
	 * <br>Some work must run only once for each chunk, for example the publication of 1 platform event. Put that work in an `if` block that checks `getTriggerEvent()` for an after context.
	 * @example
	 * // andFinally() runs after the before context and again after the after context.
	 * // This example runs only once for each chunk of 200 records, after the after context.
	 * public override void andFinally() {
	 *   if (getTriggerEvent() == System.TriggerOperation.AFTER_UPDATE) {
	 *     EventBus.publish(new Account_Change__e(Record_Count__c = Trigger.size));
	 *   }
	 * }
	 */
	public override void andFinally() {
		finishedOperations.add(getTriggerEvent());
	}

	/**
	 * Replaces each group of spaces in the Account names with 1 space, and removes the spaces at the start and the end.
	 * @param accounts The Accounts to change.
	 */
	private static void normalizeNames(List<Account> accounts) {
		for (Account changedAccount : accounts) {
			changedAccount.Name = changedAccount.Name.normalizeSpace();
		}
	}

	/**
	 * Updates the phone number of the child Accounts. The handler is bypassed for that update.
	 * <br>It leaves out a child Account that is in the same trigger run, because a trigger cannot update the records that it runs for.
	 * <br>The query and the update run in system mode, so this method suppresses `FlagSystemMode`. The phone number must reach all child Accounts, also the ones that the running user cannot see or edit.
	 * @param phoneByParentId The new phone number of each parent Account, by Id.
	 */
	@SuppressWarnings('PMD.FlagSystemMode')
	private void copyPhoneToChildAccounts(Map<Id, String> phoneByParentId) {
		Set<Id> parentIds = phoneByParentId.keySet();
		List<Account> childAccounts = new List<Account>();
		for (Account childAccount : [SELECT Id, ParentId FROM Account WHERE ParentId IN :parentIds WITH SYSTEM_MODE]) {
			if (!oldRecordsMap.containsKey(childAccount.Id)) {
				childAccount.Phone = phoneByParentId.get(childAccount.ParentId);
				childAccounts.add(childAccount);
			}
		}
		if (childAccounts.isEmpty()) {
			return;
		}
		// This handler is running, so it was not bypassed before. The finally block restores that state, also when the update fails.
		TriggerHandler.bypass(AccountSampleTriggerHandler.class);
		try {
			Database.update(childAccounts, AccessLevel.SYSTEM_MODE);
		} finally {
			TriggerHandler.clearBypass(AccountSampleTriggerHandler.class);
		}
	}
}