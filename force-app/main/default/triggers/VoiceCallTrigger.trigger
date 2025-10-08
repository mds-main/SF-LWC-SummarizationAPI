trigger VoiceCallTrigger on VoiceCall (after insert, after update) {
    if (Trigger.isAfter) {
        List<GCFetchInteractionSummary.FlowInputs> summaryInputs = new List<GCFetchInteractionSummary.FlowInputs>();
        List<GCGetAgentParticipantId.FlowInputs> agentInputs = new List<GCGetAgentParticipantId.FlowInputs>();

        for (VoiceCall vc : Trigger.new) {
            // Handle agent participant ID fetching on insert
            if (Trigger.isInsert && vc.get('GC_Interaction_Id__c') != null) {
                GCGetAgentParticipantId.FlowInputs input = new GCGetAgentParticipantId.FlowInputs();
                input.interactionId = (String)vc.get('GC_Interaction_Id__c');
                input.voiceCallId = vc.Id;
                agentInputs.add(input);
            }

            // Handle summary fetching when call duration is available (indicates call completion)
            if (Trigger.isUpdate && vc.CallDurationInSeconds != null && vc.CallDurationInSeconds > 0) {
                VoiceCall oldVc = Trigger.oldMap.get(vc.Id);
                // Check if CallDurationInSeconds was null/0 before and now has a value
                if ((oldVc.CallDurationInSeconds == null || oldVc.CallDurationInSeconds == 0) &&
                    vc.CallDurationInSeconds > 0) {
                    GCFetchInteractionSummary.FlowInputs input = new GCFetchInteractionSummary.FlowInputs();
                    input.interactionId = (String)vc.get('GC_Interaction_Id__c');
                    input.voiceCallId = vc.Id;
                    input.waitTime = 3;
                    summaryInputs.add(input);
                }
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


