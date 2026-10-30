# Sample trigger handler

This folder holds a sample trigger, trigger handler, and test for the [Salesforce Trigger Framework](../README.md). It is not a package directory, so a deploy of the framework does not install it.

## What it contains

- `main/default/triggers/AccountSampleTrigger.trigger` has no logic: it creates the handler and calls `run()`. It lists all 7 contexts, even the ones the handler does not override, so the trigger is written once and never edited again. A new override in the handler runs without a change to the trigger:

```apex
trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new AccountSampleTriggerHandler().run();
}
```

- `main/default/classes/AccountSampleTriggerHandler.cls` extends `TriggerHandler` and shows these parts of the framework:
- The constructor passes the class to `super()`, casts the trigger collections that the handler uses, and sets a loop limit with `setMaxLoopCount()`. The limit is high enough that a bulk update does not reach it.
- Before insert, it removes extra spaces from each Account name. Before update, it does the same only for the names that changed, which it finds with the old records.
- After update, it copies a changed phone number to the child Accounts. It bypasses itself with `TriggerHandler.bypass(AccountSampleTriggerHandler.class)` for that update, so the update does not run the handler again, and it clears the bypass in a `finally` block.
- `andFinally()` runs after each of the 7 contexts, also the ones the handler does not override. The sample records the finished operation, which the test reads.
- The handler is `inherited sharing`, and its query and DML statement name `SYSTEM_MODE`. A trigger runs without sharing, so the handler can update child Accounts that the running user cannot edit. Code Analyzer reports system mode with `FlagSystemMode`, so the method suppresses that rule and its ApexDoc gives the reason. The test class does the same for its own setup and checks.
- `main/default/classes/AccountSampleTriggerHandlerTest.cls` proves each of these behaviors with real DML, 1 test per behavior. It also shows how a test bypasses a handler to set up data.

## Try it in a scratch org

Deploy the framework and the sample together, and run the sample test:

```bash
sf project deploy start --source-dir force-app --source-dir sample-handler --target-org <alias>
sf apex run test --class-names AccountSampleTriggerHandlerTest --target-org <alias> --wait 10
```

## General Theme

Each object has a single trigger

Each trigger has a single handler

## [Handler Documentation](../README.md#usage)

---

## Sample Trigger

```apex
trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new AccountSampleTriggerHandler().run();
}
```

## Sample Handler

```apex
/**
 * A sample Account trigger handler that shows the framework in use.
 * Before insert and before update, it removes extra spaces from each new or changed Account name.
 * After update, it copies a changed phone number to the child Accounts. It bypasses itself for that update, so the update does not run this handler again.
 * A loop limit protects against recursion that the bypass does not stop, and `andFinally()` runs after each context.
 * A trigger runs without sharing, so this `inherited sharing` handler does too. Every query and DML statement names `SYSTEM_MODE`, so the handler can update child Accounts that the running user cannot edit.
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 * @group-content doc-assets/files/sampletriggerhandlerhome.html
 * @see AccountSampleTriggerHandlerTest
 */
public inherited sharing class AccountSampleTriggerHandler extends TriggerHandler {
  /**
   * The maximum number of runs of this handler in 1 transaction. Each trigger context and each chunk of 200 records uses 1 run, so 100 allows an update of 10,000 records, which runs before update and after update 50 times each.
   */
  private static final Integer MAX_LOOP_COUNT = 100;

  /**
   * The trigger operations this handler finished in the transaction, in order. `andFinally()` adds each one.
   */
  @TestVisible
  private static List<System.TriggerOperation> finishedOperations = new List<System.TriggerOperation>();

  private List<Account> newRecords;
  private Map<Id, Account> oldRecordsMap;

  /**
   * Constructor for the trigger. It passes the class to the base class, so the base class never resolves the name at runtime. It casts the trigger collections that the handler uses, and it sets the loop limit.
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
   * Remove extra spaces from the name of each new Account.
   */
  public override void beforeInsert() {
    normalizeNames(newRecords);
  }

  /**
   * Remove extra spaces from each Account name that changed.
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
   * Copy each changed phone number to the child Accounts.
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
   * Record the finished operation. A real handler puts work here that must follow every context, such as a rollup or 1 platform event for the whole trigger.
   */
  public override void andFinally() {
    finishedOperations.add(getTriggerEvent());
  }

  /**
   * Replace each run of spaces in the Account names with 1 space, and remove the spaces at the start and the end.
   * @param accounts The Accounts to change.
   */
  private static void normalizeNames(List<Account> accounts) {
    for (Account changedAccount : accounts) {
      changedAccount.Name = changedAccount.Name.normalizeSpace();
    }
  }

  /**
   * Update the phone number of the child Accounts, with this handler bypassed for that update.
   * A child Account that is in the same trigger run is left out, because a trigger cannot update the records it is running for.
   * The query and the update run in system mode, so `FlagSystemMode` is suppressed for this method. The phone number must reach every child Account, also a child Account that the running user cannot see or edit.
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
```

## Credits

This trigger framework is from [https://github.com/dschach/sfdc-trigger-framework](https://github.com/dschach/sfdc-trigger-framework) which is based on Kevin O'Hara's framework [https://github.com/kevinohara80/sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework)
