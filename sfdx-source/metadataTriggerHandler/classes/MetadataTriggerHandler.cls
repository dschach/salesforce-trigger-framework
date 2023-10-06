/**
 * @description Metadata-driven Trigger Handler that builds on TriggerHandler, allowing both to exist together
 *
 * @author      David Schach
 * @since       2023
 */
public without sharing virtual class MetadataTriggerHandler extends TriggerHandler {
	@TestVisible
	private TriggerHandlerQueryService mts;

	@TestVisible
	private List<TriggerHandler__mdt> triggers;

	@TestVisible
	private TriggerHandler activeHandler;

	protected virtual void execute(List<SObject> newRecords, List<SObject> oldRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
	}

	/**
	 * @description Exception class
	 */
	public class MetadataTriggerHandlerException extends Exception {
	}

	private without sharing class TriggerHandlerQueryService {
		/**
		 * @description Initialize objectTypeName as an empty string to avoid null errors
		 */
		private String objType = '';

		/**
		 * @description Constructor for trigger query service
		 *
		 * @param objectTypeName String The object Type name
		 */
		public TriggerHandlerQueryService(String objectTypeName) {
			this.objType = objectTypeName;
		}
		/**
		 * @description This query finds an ordered list trigger handler classes
		 * to execute. It ignores any classes that are marked as disabled.
		 *
		 * <br>Note: It will exclude any triggerHandler metadata records for which
		 * the user's email address is found in a related `disabled_for__mdt`
		 * record.
		 *
		 * <br>Admins and Developers can selectively disable trigger handlers
		 * for all or selected individuals *without* deploying.
		 * @return      `List<TriggerHandler__mdt>`
		 */
		@SuppressWarnings('PMD.ApexCRUDViolation')
		public List<TriggerHandler__mdt> getMetadataTriggers() {
			List<TriggerHandler__mdt> handlers = [
				SELECT Id, Class__c, Event__c, Order__c
				FROM TriggerHandler__mdt
				WHERE SObject__r.QualifiedAPIName = :this.objType AND Active__c = TRUE
				ORDER BY Order__c ASC NULLS LAST
			];
			return null;
		}

		/**
		 * @description This determines the active sObject type by describing the first
		 * record in the trigger New / Old list
		 *
		 * @param triggerNew List<sObject> The trigger.new list
		 * @param triggerOld List<sObject> The trigger.old list
		 *
		 * @return `String` the ObjectType name
		 *
		 * @throws MetadataTriggerFrameworkException when both triggerNew and triggerOld are null
		 */
		public String getSObjectType(List<SObject> triggerNew, List<SObject> triggerOld) {
			if (triggerNew != null) {
				return getSObjectTypeFromListsFirstObject(triggerNew);
			} else if (triggerOld != null) {
				return getSObjectTypeFromListsFirstObject(triggerOld);
			} else {
				throw new MetadataTriggerHandler.MetadataTriggerHandlerException(
					'Passed values for triggerNew and triggerOld are both null. Are you exercising this method outside of a trigger context?'
				);
			}
		}
		/**
		 * @description Method determines the type of a list from it's first element.
		 * This is potentially incorrect, if your List is defined `List<SObject>` rather than `List<Account>`
		 * or some other specific SObject
		 * <br>Taken from Kevin Poorman's ApexKit project
		 * @author Kevin Poorman
		 *
		 * @param sObjects A list of SObjects
		 *
		 * @return String the name of the SObject type of the first element in the list
		 */
		public String getSObjectTypeFromListsFirstObject(List<SObject> sObjects) {
			return (!sObjects.isEmpty()) ? sObjects.get(0).getSObjectType().getDescribe().getName() : 'sObject';
		}
	}
}