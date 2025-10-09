trigger ExperienceTrigger on genesysps__Experience__c (after insert, after update) {
    if (Trigger.isAfter) {
        List<GCFetchInteractionSummary.FlowInputs> summaryInputs = new List<GCFetchInteractionSummary.FlowInputs>();
        List<GCGetAgentParticipantId.FlowInputs> agentInputs = new List<GCGetAgentParticipantId.FlowInputs>();

        for (genesysps__Experience__c exp : Trigger.new) {
            if (Trigger.isUpdate) {
                genesysps__Experience__c oldExp = Trigger.oldMap.get(exp.Id);
                if (exp.genesysps__Ended__c != null && oldExp.genesysps__Ended__c == null) {
                    GCFetchInteractionSummary.FlowInputs input = new GCFetchInteractionSummary.FlowInputs();
                    input.interactionId = exp.genesysps__Interaction_Id__c;
                    input.experienceId = exp.Id;
                    input.waitTime = 3;
                    summaryInputs.add(input);
                }
            }

            if (Trigger.isInsert && exp.genesysps__Interaction_Id__c != null) {
                GCGetAgentParticipantId.FlowInputs input = new GCGetAgentParticipantId.FlowInputs();
                input.interactionId = exp.genesysps__Interaction_Id__c;
                input.experienceId = exp.Id;
                agentInputs.add(input);
            }
        }

        if (!summaryInputs.isEmpty()) {
            GCFetchInteractionSummary.updateInteractionSummary(summaryInputs);
        }

        if (!agentInputs.isEmpty()) {
            GCGetAgentParticipantId.getAgentParticipantId(agentInputs);
        }
    }
}


