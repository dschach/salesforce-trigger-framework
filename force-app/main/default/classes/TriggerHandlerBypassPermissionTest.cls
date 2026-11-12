/**
 * Tests for the `BypassTriggerHandlers` custom permission of `TriggerHandler`.
 * <br>The test creates a test user and gives it the permission through a permission set. Salesforce allows no DML on permission set objects in a parallel test class, so these tests are in their own class without `isParallel`.
 * @since 2.1.0
 * @group Trigger Handler
 * @see TriggerHandler
 * @see TriggerHandlerTest
 */
@IsTest(testFor='ApexClass:TriggerHandler')
private inherited sharing class TriggerHandlerBypassPermissionTest {
	/**
	 * The methods that the test handler ran, in order. Apex resets it for each test method.
	 * @since 2.1.0
	 */
	private static List<String> calls = new List<String>();

	/**
	 * The name of the test handler, from `Type.getName()`.
	 * @since 2.1.0
	 */
	private static final String HANDLER_NAME = TriggerHandlerBypassPermissionTest.PermissionHandler.class.getName();

	/**
	 * A user with the `BypassTriggerHandlers` permission runs no handler: no context method, no `andFinally()`, and no loop count. The code bypass checks do not report it, and code cannot clear it.
	 * @since 2.1.0
	 */
	@IsTest
	private static void bypassPermissionSkipsEveryHandler() {
		User bypassUser = newUserWithBypassPermission();
		System.runAs(bypassUser) {
			Assert.isTrue(TriggerHandler.hasBypassPermission(), 'the user should have the bypass permission');
			Assert.isTrue(TriggerHandler.isSkipped(HANDLER_NAME), 'the handler should be skipped by name');
			Assert.isTrue(TriggerHandler.isSkipped(TriggerHandlerBypassPermissionTest.PermissionHandler.class), 'the handler should be skipped by type');
			Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'isBypassed() should report only the bypasses that code set');
			Assert.isFalse(TriggerHandler.isGlobalBypassed(), 'isGlobalBypassed() should report only the global bypass that code set');

			TriggerHandlerBypassPermissionTest.PermissionHandler limited = newHandler();
			limited.setMaxLoopCount(5).run();
			Assert.isTrue(calls.isEmpty(), 'the handler should call no method, also not andFinally()');
			Assert.areEqual(0, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_UPDATE), 'a skipped run should not count');

			TriggerHandler.clearAllBypasses();
			newHandler().run();
			Assert.isTrue(calls.isEmpty(), 'clearAllBypasses() should not clear the permission bypass');
		}
	}

	/**
	 * Creates a test user with the profile of the running user, and gives it the `BypassTriggerHandlers` custom permission through a new permission set.
	 * <br>The setup runs in system mode, so that it does not depend on the rights of the user who runs the tests. So this method suppresses `FlagSystemMode`. The permission check under test runs later, in `System.runAs()` for the test user.
	 * @return `User` The test user, for `System.runAs()`.
	 * @since 2.1.0
	 */
	@SuppressWarnings('PMD.FlagSystemMode')
	private static User newUserWithBypassPermission() {
		String uniqueName = 'taf' + String.valueOf(Crypto.getRandomInteger()).remove('-') + '@example.com';
		User bypassUser = new User(
			Username = uniqueName,
			Email = uniqueName,
			LastName = 'Bypass',
			Alias = 'bypass',
			ProfileId = UserInfo.getProfileId(),
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US'
		);
		insert as system bypassUser;

		PermissionSet bypassSet = new PermissionSet(Name = 'TriggerHandlerTestBypass', Label = 'Trigger Handler Test Bypass');
		insert as system bypassSet;
		CustomPermission bypassPermission = [SELECT Id FROM CustomPermission WHERE DeveloperName = :TriggerHandler.BYPASS_PERMISSION WITH SYSTEM_MODE LIMIT 1];
		insert as system new SetupEntityAccess(ParentId = bypassSet.Id, SetupEntityId = bypassPermission.Id);
		insert as system new PermissionSetAssignment(PermissionSetId = bypassSet.Id, AssigneeId = bypassUser.Id);
		return bypassUser;
	}

	/**
	 * Creates a test handler that runs as if a trigger fired after update.
	 * @return `TriggerHandlerBypassPermissionTest.PermissionHandler` A handler with the name `HANDLER_NAME`.
	 * @since 2.1.0
	 */
	private static TriggerHandlerBypassPermissionTest.PermissionHandler newHandler() {
		TriggerHandlerBypassPermissionTest.PermissionHandler fixture = new TriggerHandlerBypassPermissionTest.PermissionHandler();
		fixture.setTestContext(System.TriggerOperation.AFTER_UPDATE);
		return fixture;
	}

	/**
	 * A handler that records its after update context and `andFinally()` in `calls`.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2.1.0
	 */
	private inherited sharing class PermissionHandler extends TriggerHandler {
		/**
		 * Creates the handler with its type, so that its name is `HANDLER_NAME`.
		 * @since 2.1.0
		 */
		private PermissionHandler() {
			super(TriggerHandlerBypassPermissionTest.PermissionHandler.class);
		}

		/**
		 * Records the after update context.
		 * @since 2.1.0
		 */
		public override void afterUpdate() {
			calls.add('afterUpdate');
		}

		/**
		 * Records `andFinally()`.
		 * @since 2.1.0
		 */
		public override void andFinally() {
			calls.add('andFinally');
		}
	}
}