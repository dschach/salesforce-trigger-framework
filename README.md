[![codecov](https://codecov.io/gh/dschach/salesforce-trigger-framework/branch/main/graph/badge.svg?token=1StpM73gpE)](https://codecov.io/gh/dschach/salesforce-trigger-framework)
[![CI](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml)
[![Twitter](https://img.shields.io/twitter/follow/dschach.svg?style=social)](https://x.com/dschach)

# Salesforce Trigger Framework

- [Salesforce Trigger Framework](#salesforce-trigger-framework)
  - [Credit](#credit)
  - [Documentation](#documentation)
    - [Changelog](#changelog)
  - [Overview](#overview)
  - [Usage](#usage)
    - [Trigger Handler](#trigger-handler)
    - [Trigger](#trigger)
  - [Cool Stuff](#cool-stuff)
    - [Bypass API](#bypass-api)
    - [Check Bypass Status](#check-bypass-status)
    - [Global Bypass](#global-bypass)
    - [Set Bypass](#set-bypass)
    - [Max Loop Count](#max-loop-count)
    - [Debug Statements](#debug-statements)
    - [Universal Action](#universal-action)
  - [Overridable Methods](#overridable-methods)
  - [API Reference](#api-reference)

## Credit

Based on Kevin O'Hara's famous framework [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework). Its MIT license notice is in [NOTICE](NOTICE).

## Documentation

[Class Documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html)

### Changelog

[Complete Changelog](CHANGELOG.md)

## Overview

(from Kevin O'Hara)

Triggers should (IMO) be logicless. Putting logic into your triggers creates un-testable, difficult-to-maintain code. It's widely accepted that a best-practice is to move trigger logic into a handler class.

This trigger framework bundles a single **TriggerHandler** base class that you can inherit from in all of your trigger handlers. The base class includes context-specific methods that are automatically called when a trigger is executed.

The base class also provides a secondary role as a supervisor for Trigger execution. It acts like a watchdog, monitoring trigger activity and providing an api for controlling certain aspects of execution and control flow.

But the most important part of this framework is that it's minimal and simple to use.

**Deploy to a scratch org:**
[Deploy instructions](./DEPLOY.md)

**Deploy to a Salesforce org:**
[![Deploy](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=dschach&repo=salesforce-trigger-framework)

## Usage

### Trigger Handler

To create a trigger handler, create a class that extends [TriggerHandler.cls](https://github.com/dschach/salesforce-trigger-framework/blob/main/force-app/main/default/classes/TriggerHandler.cls). Here is the declaration of an Opportunity trigger handler.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
}
```

To add logic to a trigger context, override that context's method in your trigger handler. Here is how we would add logic to a `beforeUpdate, afterUpdate` trigger.

**Note:** When referencing the Trigger static maps within a class, SObjects are returned versus SObject subclasses like Opportunity, Account, etc. This means that you must cast when you reference them in your trigger handler. You could do this in your constructor if you wanted. Technically, you only need to cast for oldMap and newMap, but for completeness, I encourage casting Trigger.new and Trigger.old as well.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private List<Opportunity> newRecords;
  private List<Opportunity> oldRecords;
  private Map<Id, Opportunity> newRecordsMap;
  private Map<Id, Opportunity> oldRecordsMap;

  public OpportunityTriggerHandler() {
    super('OpportunityTriggerHandler');
    this.newRecords = (List<Opportunity>) Trigger.new;
    this.oldRecords = (List<Opportunity>) Trigger.old;
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.oldRecordsMap = (Map<Id, Opportunity>) Trigger.oldMap;
  }

  public override void beforeUpdate() {
    for (Opportunity o : newRecords) {
      /* do something */
    }
  }

  public override void afterUpdate() {
    /* do something */
  }

  /* add overrides for other contexts */
}
```

Passing the class name to `super()` is optional, and it makes the handler faster. Without it, the framework works out the name from the running class the first time a bypass or a loop count needs it, and that lookup serializes every field of the handler, including the record lists. Pass the name exactly as `Type.getName()` returns it, so that `TriggerHandler.bypass(OpportunityTriggerHandler.class)` matches. For a top-level class, that is the class name.

A sample [AccountSampleTriggerHandler](https://github.com/dschach/salesforce-trigger-framework/tree/main/sample-handler/main/default/classes) class has been included in this repository, as well as a sample [trigger](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger). The sample is not a package directory, so the Deploy to Salesforce button and `sf project deploy start` install only the framework. To try the sample in a scratch org, run `sf project deploy start --source-dir sample-handler`. The [sample README](sample-handler/README.md) describes what it shows.

### Trigger

To use the trigger handler, you only need to construct an instance of your trigger handler within the trigger itself and call the `run()` method. Here is an example of an Opportunity trigger.

This is the way to write a trigger that will run the trigger handler above. List all 7 contexts, even the ones the handler does not override yet. Then you write the trigger once and never edit it again: a new override in the handler runs without a change to the trigger. A context that the handler does not override costs little, because `run()` calls the empty base method and then `andFinally()`. Some objects do not support every context, for example an object that cannot be undeleted. For such an object, leave out the contexts that it does not support.

```apex
trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().run();
}
```

### Data access

A trigger runs without sharing, so a handler declared `inherited sharing` runs without sharing too. A handler often must read or change records that the running user cannot see or edit, such as related records. So the examples here name `SYSTEM_MODE` on every query and DML statement: `WITH SYSTEM_MODE` in SOQL, and `AccessLevel.SYSTEM_MODE` in `Database` methods. System mode ignores the user's object and field permissions, and the sharing of the class decides record access.

If a handler must respect the running user's object, field, and record permissions, use `WITH USER_MODE` and `AccessLevel.USER_MODE` instead.

## Cool Stuff

### Bypass API

What if you want to tell other trigger handlers to halt execution? That's easy with the bypass api:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler() {
    super('OpportunityTriggerHandler');
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE Id IN :newRecordsMap.keySet() WITH SYSTEM_MODE];

    Account acc = [SELECT Id, Name FROM Account WHERE Id = :opps.get(0).AccountId WITH SYSTEM_MODE];

    TriggerHandler.bypass('AccountTriggerHandler');

    acc.Name = 'No Trigger';
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* won't invoke the AccountTriggerHandler */

    TriggerHandler.clearBypass('AccountTriggerHandler');

    acc.Name = 'With Trigger';
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* will invoke the AccountTriggerHandler */
  }
}
```

Bypass names match regardless of case. You can also bypass by type, as in `TriggerHandler.bypass(AccountTriggerHandler.class)`, so the compiler checks the name. A null or blank name, a null type, or a null list throws `TriggerHandler.TriggerHandlerException`.

### Check Bypass Status

If you need to check if a handler is bypassed, use the `isBypassed` method:

```apex
if (TriggerHandler.isBypassed('AccountTriggerHandler')) {
  /* ... do something if the Account trigger handler is bypassed! */
}
```

### Global Bypass

To bypass all handlers, use the `bypassAll` method:

```apex
TriggerHandler.bypassAll();
```

This also clears the list of named bypasses, and it adds the entry `BypassAll` to the list from `bypassList()` and the set from `bypassSet()`.

To clear all bypasses for the transaction, simply use the `clearAllBypasses` method, as in:

```apex
/* ... done with bypasses! */

TriggerHandler.clearAllBypasses();

/* ... now handlers won't be ignored! */
```

This clears the list of bypassed handlers and the global bypass. To clear only one of them, use `clearBypassList()` or `clearGlobalBypass()`.

### Set Bypass

If you are not sure in a transaction if a handler is bypassed, but want to bypass it (or clear the bypass) and then set it to its original value, use the `setBypass` method:

```apex
Boolean isBypassed = TriggerHandler.isBypassed('AccountTriggerHandler');
TriggerHandler.bypass('AccountTriggerHandler');

/* do something here */

TriggerHandler.setBypass('AccountTriggerHandler', isBypassed);
```

`setBypass(name, false)` also clears the global bypass, because a global bypass cannot leave out 1 handler. So this idiom restores the named bypass, not a global bypass that was active before.

To store all currently bypassed handlers, temporarily bypass all handlers, and then restore the originally bypassed list:

```apex
List<String> bypassedHandlers = TriggerHandler.bypassList();
TriggerHandler.bypassAll();

/* do something here */

TriggerHandler.clearAllBypasses();
TriggerHandler.bypass(bypassedHandlers);
```

If all handlers were bypassed before, the stored list holds `BypassAll`. In that case, call `TriggerHandler.bypassAll()` again instead of restoring the list.

### Max Loop Count

To limit recursion, you can set a maximum loop count for a trigger handler. The count is kept per handler name, and every trigger context the handler runs in uses 1 count, so a trigger on `before update` and `after update` uses 2 counts for 1 update. A DML statement on more than 200 records runs the trigger once for each chunk of 200 records, and each chunk uses counts too. When the count passes the maximum, `run()` writes a warning to the debug log and returns without calling the context method or `andFinally()`.

This handler runs its update logic once for an update of up to 200 records. The update inside `afterUpdate()` fires the trigger again, and those runs are skipped.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler() {
    super('OpportunityTriggerHandler');
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.setMaxLoopCount(2); /* 1 count for before update, 1 for after update */
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id IN :newRecordsMap.keySet() WITH SYSTEM_MODE];
    Database.update(opps, AccessLevel.SYSTEM_MODE);
  }
}
```

`clearMaxLoopCount()` removes the limit, and `TriggerHandler.getLoopCount('OpportunityTriggerHandler')` returns the current count. The count is 0 for a handler that never set a maximum.

In version 1.2, the ability to chain methods was added. Now, you can set the max loop count in a single line in your trigger:

```apex
trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().setMaxLoopCount(5).run();
}
```

### Debug Statements

There are two methods that will show additional information.

`TriggerHandler.showLimits()` will debug Apex query and DML limits when the trigger handler has completed.

`TriggerHandler.showDebug()` will show trigger entry and exit in debug logs. Use sparingly, as it will decrease org performance.

Both flags are static, so they apply to every handler that runs later in the transaction. To use one or both of these, either add them to the *trigger*

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();
new AccountSampleTriggerHandler().run();
TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

or put them in your Apex *trigger handler* code before and after DML statements.

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();

Database.update(leadsList, AccessLevel.SYSTEM_MODE);

TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

In version 1.2, the ability to chain methods *in triggers* was added. Now, you can specify showing debug messages and limits in a single line in your trigger:

```apex
trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().debug().limits().run(); // debug() is the same as debug(true)
}
```

Or stop showing them.

```apex
trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().debug(false).limits(false).run();
}
```

### Universal Action

Version 1.1 added a new method/context: `andFinally()` can contain actions that should happen in every trigger context, after all other actions. It does not run when the handler is bypassed, when the loop limit is exceeded, or when the context method throws an exception. Credit to James Simone for this idea. As he writes, "runs after every context - can be used to easily implement something like apex-rollup!" ([The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/))

## Overridable Methods

Here are all of the methods that you can override. All of the context possibilities are supported.

- `beforeInsert()`
- `beforeUpdate()`
- `beforeDelete()`
- `afterInsert()`
- `afterUpdate()`
- `afterDelete()`
- `afterUndelete()`
- `andFinally()`

A handler can also call 2 protected methods: `getTriggerEvent()` returns the current `System.TriggerOperation`, and `getHandlerName()` returns the handler's name.

## API Reference

Every public member of `TriggerHandler`. The [class documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html) has the full details and examples.

| Member | What it does |
| --- | --- |
| `TriggerHandler()` | Constructor. The handler name is worked out from the running class when it is first needed. |
| `TriggerHandler(String handlerName)` | Constructor with the handler name, which skips the runtime name lookup. |
| `run()` | Called from the trigger. Runs the context method for the current operation, then `andFinally()`. |
| `setMaxLoopCount(Integer max)` | Limits how many times this handler runs. A negative value removes the limit. Returns the handler, for chaining. |
| `clearMaxLoopCount()` | Removes the limit on how many times this handler runs. |
| `static getLoopCount(String handlerName)` | Returns the loop count of a handler, or 0 when no maximum was set for it. |
| `static bypass(String handlerName)` | Bypasses a handler by name. The name matches regardless of case. |
| `static bypass(Type handlerType)` | Bypasses a handler by type, for example `bypass(AccountTriggerHandler.class)`. |
| `static bypass(List<String> handlerNames)` | Bypasses a list of handlers by name. |
| `static bypassAll()` | Bypasses every handler, and clears the list of named bypasses. |
| `static clearBypass(String handlerName)` | Clears the bypass of a handler by name. |
| `static clearBypass(Type handlerType)` | Clears the bypass of a handler by type. |
| `static clearBypass(List<String> handlerNames)` | Clears the bypass of a list of handlers by name. |
| `static isBypassed(String handlerName)` | Returns `true` when the handler is bypassed by name or type, or when all handlers are bypassed. |
| `static isBypassed(Type handlerType)` | The same check, by type. |
| `static bypassList()` | Returns a sorted list of the bypassed handlers, with `BypassAll` when all handlers are bypassed. |
| `static bypassSet()` | Returns a set of the bypassed handlers, with `BypassAll` when all handlers are bypassed. |
| `static setBypass(String handlerName, Boolean desiredValue)` | Bypasses the handler for `true`. For `false`, clears its bypass and the global bypass. |
| `static clearAllBypasses()` | Clears the global bypass and the list of named bypasses. |
| `static clearGlobalBypass()` | Clears only the global bypass. |
| `static clearBypassList()` | Clears only the list of named bypasses. |
| `limits()`, `limits(Boolean enabled)` | Turns the limits debug output on, or on and off. Returns the handler, for chaining. |
| `static showLimits()`, `static showLimits(Boolean enabled)` | The same, without chaining. |
| `debug()`, `debug(Boolean enabled)` | Turns the entry and exit debug output on, or on and off. Returns the handler, for chaining. |
| `static showDebug()`, `static showDebug(Boolean enabled)` | The same, without chaining. |
| `TriggerHandler.TriggerHandlerException` | Thrown when `run()` is called outside a trigger, and when a bypass or loop count method gets a null or blank argument. |
