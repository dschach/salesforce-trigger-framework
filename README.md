[![codecov](https://codecov.io/gh/dschach/salesforce-trigger-framework/branch/main/graph/badge.svg?token=1StpM73gpE)](https://codecov.io/gh/dschach/salesforce-trigger-framework)
[![CI](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml)
[![Twitter](https://img.shields.io/twitter/follow/dschach.svg?style=social)](https://img.shields.io/twitter/follow/dschach.svg?style=social)

# Salesforce Trigger Framework

## Credit

Based on Kevin O'Hara's famous framework [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework)

## Documentation

[Class Documentation](https://dschach.github.io/salesforce-trigger-framework/index.html)

## Overview

(from Kevin O'Hara)

Triggers should (IMO) be logicless. Putting logic into your triggers creates un-testable, difficult-to-maintain code. It's widely accepted that a best-practice is to move trigger logic into a handler class.

This trigger framework bundles a single **TriggerHandler** base class that you can inherit from in all of your trigger handlers. The base class includes context-specific methods that are automatically called when a trigger is executed.

The base class also provides a secondary role as a supervisor for Trigger execution. It acts like a watchdog, monitoring trigger activity and providing an api for controlling certain aspects of execution and control flow.

But the most important part of this framework is that it's minimal and simple to use.

**Deploy to SFDX Scratch Org:**
[Deploy instructions](./DEPLOY.md)

**Deploy to Salesforce Org:**
[![Deploy](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=dschach&repo=salesforce-trigger-framework)

## Usage

### Trigger Handler

To create a trigger handler, you simply need to create a class that inherits from [TriggerHandler.cls](https://github.com/dschach/salesforce-trigger-framework/blob/main/force-app/main/default/classes/TriggerHandler.cls). Here is an example for creating an Opportunity trigger handler.

```java
public class OpportunityTriggerHandler extends TriggerHandler {
```

In your trigger handler, to add logic to any of the trigger contexts, you only need to override them in your trigger handler. Here is how we would add logic to a `beforeUpdate, afterUpdate` trigger.

A sample [AccountSampleTriggerHandler](https://github.com/dschach/salesforce-trigger-framework/tree/main/sample-handler/main/default/classes) class has been included in this repository, as well as a sample [trigger](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger).

**Note:** When referencing the Trigger static maps within a class, SObjects are returned versus SObject subclasses like Opportunity, Account, etc. This means that you must cast when you reference them in your trigger handler. You could do this in your constructor if you wanted. Technically, you only need to cast for oldMap and newMap, but for completeness, I encourage casting Trigger.new and Trigger.old as well.

```java
public class OpportunityTriggerHandler extends TriggerHandler {
  private List<Opportunity> newRecords;
  private List<Opportunity> oldRecords;
  private Map<Id, Opportunity> newRecordsMap;
  private Map<Id, Opportunity> oldRecordsMap;

  public OpportunityTriggerHandler(){
    super('OpportunityTriggerHandler');
    this.newRecords = Trigger.new;
    this.oldRecords = Trigger.old;
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.oldRecordsMap = (Map<Id, Opportunity>) Trigger.oldMap;
  }

  public override void beforeUpdate() {
    for(Opportunity o : newRecords) {
      /* do something */
    }
  }

  public override void afterUpdate() {
      /* do something */
  }

  /* add overrides for other contexts */

}
```
### Trigger

To use the trigger handler, you only need to construct an instance of your trigger handler within the trigger handler itself and call the `run()` method. Here is an example of an Opportunity trigger.

This is the way to write a trigger that will run the trigger handlers below. Note that some objects do not work in every context, so ensure that you list only applicable trigger contexts in your trigger definition and that you only override those contexts. If you include extra contexts, they will not be covered by Apex tests, which could lead to deployment problems.

```java
trigger OpportunityTrigger on Opportunity (before update, after update) {
  new OpportunityTriggerHandler().run();
}
```

## Cool Stuff

### Bypass API

What if you want to tell other trigger handlers to halt execution? That's easy with the bypass api:

```java
public class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  /* Optional Constructor - better performance */
  public OpportunityTriggerHandler(){
    super('OpportunityTriggerHandler');
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE Id IN :newRecordsMap.keySet()];

    Account acc = [SELECT Id, Name FROM Account WHERE Id = :opps.get(0).AccountId];

    TriggerHandler.bypass('AccountTriggerHandler');

    acc.Name = 'No Trigger';
    update acc; /* won't invoke the AccountTriggerHandler */

    TriggerHandler.clearBypass('AccountTriggerHandler');

    acc.Name = 'With Trigger';
    update acc; /* will invoke the AccountTriggerHandler */

  }

}
```
### Check Bypass Status

If you need to check if a handler is bypassed, use the `isBypassed` method:

```java
if (TriggerHandler.isBypassed('AccountTriggerHandler')) {
  /* ... do something if the Account trigger handler is bypassed! */
}
```
### Global Bypass

To bypass all handlers, set the global bypass variable:

```java
TriggerHandler.setGlobalBypass();
```

This will also add an entry 'bypassAll' to the list of handlers returned in `bypassList`.

To clear all bypasses for the transaction, simply use the `clearAllBypasses` method, as in:

```java
/* ... done with bypasses! */

TriggerHandler.clearAllBypasses();

/* ... now handlers won't be ignored! */
```

This will clear the list of bypassed handlers and set the `globalBypass` Boolean to false.

### Set Bypass

If you are not sure in a transaction if a handler is bypassed, but want to bypass it (or clear the bypass) and then set it to its original value, use the `setBybass` method:

```java
Boolean isBypassed = TriggerHandler.isBypassed('AccountTriggerHandler');
TriggerHandler.bypass('AccountTriggerHandler');

/* do something here */

TriggerHandler.setBypass('AccountTriggerHandler', isBypassed);
```

To store all currently bypassed handlers, temporarily bypass all handlers, and then restore the originally bypassed list:

```java
List<String> bypassedHandlers = TriggerHandler.bypassList();
TriggerHandler.bypassAll();

/* do something here */

TriggerHandler.clearAllBypasses(); /* or TriggerHandler.clearGlobalBypass() */
TriggerHandler.bypass(bypassedHandlers);
```

### Max Loop Count

To prevent recursion, you can set a max loop count for Trigger Handler. If this max is exceeded, and exception will be thrown. A great use case is when you want to ensure that your trigger runs once and only once within a single execution. Example:

```java
public class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler(){
    /* Optional Constructor overload - better performance */
    super('OpportunityTriggerHandler');
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.setMaxLoopCount(1);
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id IN :newRecordsMap.keySet()];
    update opps;
  }
}
```

### Debug Statements

There are two methods that will show additional information.

`TriggerHandler.showLimits()` will show Apex query and DML limits when the trigger handler has completed

`TriggerHandler.showDebug()` will show trigger entry and exit, but only during Apex testing. This is to ensure org performance.

To use one or both of these, add them to the trigger:
```java
TriggerHandler.showLimits();
TriggerHandler.showDebug();
new AccountSampleTriggerHandler().run();
```
or just put them in your Apex code before and after DML statements.

## Overridable Methods

Here are all of the methods that you can override. All of the context possibilities are supported.

- `beforeInsert()`
- `beforeUpdate()`
- `beforeDelete()`
- `afterInsert()`
- `afterUpdate()`
- `afterDelete()`
- `afterUndelete()`
