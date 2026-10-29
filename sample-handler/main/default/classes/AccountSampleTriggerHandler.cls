/**
 * @description Account Sample handler
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 * @group-content doc-assets/files/sampletriggerhandlerhome.html
 */
public without sharing class AccountSampleTriggerHandler extends TriggerHandler {
	private List<Account> newRecords;
	private List<Account> oldRecords;
	private Map<Id, Account> newRecordsMap;
	private Map<Id, Account> oldRecordsMap;

	/**
	 * @description Constructor that supplies the class name itself, so the base class never resolves it at runtime
	 * @see AccountSampleTriggerHandler.AccountSampleTriggerHandler[1]
	 */
	public AccountSampleTriggerHandler() {
		this('AccountSampleTriggerHandler');
	}

	/**
	 * @description Constructor with the class name, which skips the runtime name lookup in the base class
	 * <br>We cast all four trigger collections
	 * @param className The name of this class, exactly as `Type.getName()` returns it
	 */
	public AccountSampleTriggerHandler(String className) {
		super(className);
		this.newRecords = (List<Account>) Trigger.new;
		this.oldRecords = (List<Account>) Trigger.old;
		this.newRecordsMap = (Map<Id, Account>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		method1();
	}

	public override void beforeUpdate() {
		method2();
	}

	//public override void beforeDelete(){}

	public override void afterInsert() {
		method3();
	}

	//public override void afterUpdate(){}

	//public override void afterDelete(){}

	//public override void afterUndelete(){}

	private void method1() {
		for (Account a : newRecords) {
			a.Name = a.Name.toUpperCase();
		}
	}

	private void method2() {
		for (Account a : newRecords) {
			a.Name = a.Name.toLowerCase();
		}
	}

	private void method3() {
		List<Contact> acctContacts = [SELECT Id FROM Contact WHERE AccountId IN :newRecordsMap.keyset() WITH SECURITY_ENFORCED];
		if (Contact.getSObjectType().getDescribe().isUpdateable()) {
			update acctContacts; //NOPMD
		}
		// do things here
	}
}