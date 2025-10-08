trigger VoiceCallTrigger on VoiceCall (after insert, after update) {
    if (Trigger.isAfter) {
        List<GCFetchInteractionSummary.FlowInputs> summaryInputs = new List<GCFetchInteractionSummary.FlowInputs>();
        List<GCGetAgentParticipantId.FlowInputs> agentInputs = new List<GCGetAgentParticipantId.FlowInputs>();

        for (VoiceCall vc : Trigger.new) {
            // For now, only handle insert for agent participant ID
            // TODO: Determine the correct field to detect when VoiceCall is "completed"
            // Common VoiceCall completion fields might be: Status, CallEndTime, etc.

            if (Trigger.isInsert && vc.get('GC_Interaction_Id__c') != null) {
                GCGetAgentParticipantId.FlowInputs input = new GCGetAgentParticipantId.FlowInputs();
                input.interactionId = (String)vc.get('GC_Interaction_Id__c');
                input.voiceCallId = vc.Id;
                agentInputs.add(input);
            }

            // Note: Summary fetching for VoiceCall requires determining the correct
            // completion field. For now, this can be triggered manually or via
            // Process Builder/Flow when the appropriate completion condition is met.
        }

        if (!agentInputs.isEmpty()) {
            GCGetAgentParticipantId.getAgentParticipantId(agentInputs);
        }
    }
}


