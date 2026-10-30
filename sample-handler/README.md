# Sample Trigger Handler

This folder holds a sample trigger, a sample trigger handler, and a test for the [Salesforce Trigger Framework](../README.md). It is not a package directory, so a deploy of the framework does not install it.

## Design

- Each object has 1 trigger.
- Each trigger has 1 handler.

## What It Contains

### The Trigger

[`main/default/triggers/AccountSampleTrigger.trigger`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger) has no logic: it creates the handler and calls `run()`. It lists all 7 contexts, also the contexts that the handler does not override. So you write the trigger once and do not change it again. A new override in the handler runs with no change to the trigger.

```apex
trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new AccountSampleTriggerHandler().run();
}
```

### The Handler

[`main/default/classes/AccountSampleTriggerHandler.cls`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/classes/AccountSampleTriggerHandler.cls) extends `TriggerHandler` and shows these parts of the framework:

- The constructor passes the class to `super()`, casts the trigger collections that the handler uses, and sets a loop limit with `setMaxLoopCount()`. The limit is high, so a bulk update does not reach it.
- Before insert, the handler removes extra spaces from each Account name. Before update, it does the same only for the names that changed. It finds them with the old records.
- After update, the handler copies a changed phone number to the child Accounts. For that update, it bypasses itself with `TriggerHandler.bypass(AccountSampleTriggerHandler.class)`, so the update does not run the handler again. It clears the bypass in a `finally` block.
- `andFinally()` runs after each of the 7 contexts, also the contexts that the handler does not override. The sample records the finished operation, and the test reads it.
- The handler is `inherited sharing`, and its query and DML statement name `SYSTEM_MODE`. A trigger runs without sharing, so the handler can update child Accounts that the running user cannot edit. Code Analyzer reports system mode with `FlagSystemMode`, so the method suppresses that rule, and its ApexDoc gives the reason.

### The Test

[`main/default/classes/AccountSampleTriggerHandlerTest.cls`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/classes/AccountSampleTriggerHandlerTest.cls) proves each of these behaviors with real DML, with 1 test for each behavior. It also shows how a test bypasses a handler to set up data. The test class suppresses `FlagSystemMode` for its own setup and checks.

## Try It in a Scratch Org

Deploy the framework and the sample together, and run the sample test:

```bash
sf project deploy start --source-dir force-app --source-dir sample-handler --target-org <alias>
sf apex run test --class-names AccountSampleTriggerHandlerTest --target-org <alias> --wait 10
```

## More Information

The [Usage section of the framework README](../README.md#usage) tells how to write a handler and a trigger.

## Credits

This sample is part of [salesforce-trigger-framework](https://github.com/dschach/salesforce-trigger-framework), which is based on [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework) by Kevin O'Hara.
