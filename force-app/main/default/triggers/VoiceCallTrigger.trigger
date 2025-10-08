trigger VoiceCallTrigger on VoiceCall (after insert, after update) {
    if (Trigger.isAfter) {
        List<GCFetchInteractionSummary.FlowInputs> summaryInputs = new List<GCFetchInteractionSummary.FlowInputs>();
        List<GCGetAgentParticipantId.FlowInputs> agentInputs = new List<GCGetAgentParticipantId.FlowInputs>();

        for (VoiceCall vc : Trigger.new) {
            if (Trigger.isUpdate) {
                VoiceCall oldVc = Trigger.oldMap.get(vc.Id);
                if (vc.IsClosed && !oldVc.IsClosed) {
                    GCFetchInteractionSummary.FlowInputs input = new GCFetchInteractionSummary.FlowInputs();
                    input.interactionId = (String)vc.get('GC_Interaction_Id__c');
                    input.voiceCallId = vc.Id;
                    input.waitTime = 3;
                    summaryInputs.add(input);
                }
            }

            if (Trigger.isInsert && vc.get('GC_Interaction_Id__c') != null) {
                GCGetAgentParticipantId.FlowInputs input = new GCGetAgentParticipantId.FlowInputs();
                input.interactionId = (String)vc.get('GC_Interaction_Id__c');
                input.voiceCallId = vc.Id;
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


