# Sample trigger handler

This folder holds a sample trigger and trigger handler for the [Salesforce Trigger Framework](../README.md). It is not a package directory, so a deploy of the framework does not install it.

## What it contains

- `main/default/triggers/AccountSampleTrigger.trigger` declares every Account trigger context. It turns on the limits debug output for the transaction, and it runs the handler with its class name and with the entry and exit debug output turned on:

  ```apex
  trigger AccountSampleTrigger on Account(before insert, after insert, before update, after update, before delete, after delete, after undelete) {
  	TriggerHandler.showLimits();
  	new AccountSampleTriggerHandler('AccountSampleTriggerHandler').debug(true).run();
  }
  ```

- `main/default/classes/AccountSampleTriggerHandler.cls` extends `TriggerHandler`. Its constructor passes the class name to `super()` and casts the 4 trigger collections. Before insert it changes each Account name to upper case, and before update to lower case. After insert it reads the Contacts of the new Accounts in user mode.
- `main/default/classes/AccountSampleTriggerHandlerTest.cls` inserts and updates an Account and checks both name changes, and it checks that both constructors register the handler name.

## Try it in a scratch org

Deploy the framework and the sample together, and run the sample test:

```bash
sf project deploy start --source-dir force-app --source-dir sample-handler --target-org <alias>
sf apex run test --class-names AccountSampleTriggerHandlerTest --target-org <alias> --wait 10
```
