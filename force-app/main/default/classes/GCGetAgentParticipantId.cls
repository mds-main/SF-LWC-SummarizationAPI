public with sharing class GCGetAgentParticipantId {
    private static final String DEBUG_HEADER = '*** GCGetAgentParticipantId *** ';

    public class FlowInputs {
        @InvocableVariable(label='Interaction ID' description='The Genesys Cloud interaction ID' required=true)
        public String interactionId;

        @InvocableVariable(label='Voice Call ID' description='The ID of the related Voice Call' required=false)
        public String voiceCallId;

        @InvocableVariable(label='Experience ID' description='The ID of the related Experience' required=false)
        public String experienceId;
    }

    public class GCAgentException extends Exception {}

    @InvocableMethod(label='GC Get Agent Participant ID')
    public static void getAgentParticipantId(List<FlowInputs> inputs) {
        System.debug(DEBUG_HEADER + 'Entering getAgentParticipantId');
        try {
            if (inputs == null || inputs.isEmpty()) {
                throw new GCAgentException('No input parameters provided');
            }

            FlowInputs input = inputs[0];

            System.debug(DEBUG_HEADER + 'Input parameters:');
            System.debug(DEBUG_HEADER + 'interactionId: ' + input.interactionId);
            System.debug(DEBUG_HEADER + 'voiceCallId: ' + input.voiceCallId);
            System.debug(DEBUG_HEADER + 'experienceId: ' + input.experienceId);

            if (String.isBlank(input.interactionId)) {
                throw new GCAgentException('Interaction ID is required');
            }
            if (String.isBlank(input.voiceCallId) && String.isBlank(input.experienceId)) {
                throw new GCAgentException('Either Voice Call ID or Experience ID must be provided');
            }

            String jsonInput = JSON.serialize(input);
            System.debug(DEBUG_HEADER + 'Serialized input: ' + jsonInput);
            futureCallout(jsonInput);

        } catch (Exception e) {
            String errorMsg = 'Error in getAgentParticipantId: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        }
    }

    @future(callout=true)
    private static void futureCallout(String jsonInput) {
        System.debug(DEBUG_HEADER + 'Entering futureCallout');
        System.debug(DEBUG_HEADER + 'Input: ' + jsonInput);

        FlowInputs input = (FlowInputs)JSON.deserialize(jsonInput, FlowInputs.class);

        try {
            HttpResponse response = makeAPICall(input.interactionId);

            System.debug(DEBUG_HEADER + 'API Response Status Code: ' + response.getStatusCode());
            System.debug(DEBUG_HEADER + 'API Response Status: ' + response.getStatus());
            System.debug(DEBUG_HEADER + 'API Response Body: ' + response.getBody());

            if (response.getStatusCode() == 200) {
                String agentParticipantId = extractAgentParticipantId(response.getBody());
                if (String.isNotBlank(agentParticipantId)) {
                    updateRecords(input.voiceCallId, input.experienceId, agentParticipantId);
                } else {
                    throw new GCAgentException('No agent participant found in response');
                }
            } else {
                throw new GCAgentException('Error calling Genesys Cloud API. Status: ' + response.getStatus() +
                    ', Status Code: ' + response.getStatusCode() + ', Body: ' + response.getBody());
            }

        } catch (Exception e) {
            String errorMsg = 'Error in futureCallout: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        }
    }

    private static HttpResponse makeAPICall(String conversationId) {
        System.debug(DEBUG_HEADER + 'Making API call for conversation: ' + conversationId);
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = 'callout:GC_Base_API/api/v2/analytics/conversations/' + conversationId + '/details';
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');

            System.debug(DEBUG_HEADER + 'API Endpoint: ' + endpoint);
            System.debug(DEBUG_HEADER + 'API Method: ' + req.getMethod());

            Http http = new Http();
            return http.send(req);

        } catch (Exception e) {
            String errorMsg = 'Error making API call: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        }
    }

    private static String extractAgentParticipantId(String responseBody) {
        System.debug(DEBUG_HEADER + 'Extracting agent participant ID from response');
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            List<Object> participants = (List<Object>)responseMap.get('participants');

            if (participants != null) {
                for (Object participantObj : participants) {
                    Map<String, Object> participant = (Map<String, Object>)participantObj;
                    if ('agent'.equals(participant.get('purpose'))) {
                        String participantId = (String)participant.get('participantId');
                        System.debug(DEBUG_HEADER + 'Found agent participant ID: ' + participantId);
                        return participantId;
                    }
                }
            }

            System.debug(DEBUG_HEADER + 'No agent participant found in response');
            return null;

        } catch (Exception e) {
            String errorMsg = 'Error extracting agent participant ID: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        }
    }

    private static void updateRecords(String voiceCallId, String experienceId, String agentParticipantId) {
        System.debug(DEBUG_HEADER + 'Updating records with agent participant ID: ' + agentParticipantId);
        try {
            if (String.isNotBlank(voiceCallId)) {
                System.debug(DEBUG_HEADER + 'Updating Voice Call record: ' + voiceCallId);
                SObject voiceCall = Schema.getGlobalDescribe().get('VoiceCall').newSObject();
                voiceCall.put('Id', voiceCallId);
                voiceCall.put('GC_agent_participant_id__c', agentParticipantId);
                update voiceCall;
            }

            if (String.isNotBlank(experienceId)) {
                System.debug(DEBUG_HEADER + 'Updating Experience record: ' + experienceId);
                SObject experience = Schema.getGlobalDescribe().get('genesysps__Experience__c').newSObject();
                experience.put('Id', experienceId);
                experience.put('GC_agent_participant_id__c', agentParticipantId);
                update experience;
            }

        } catch (DmlException e) {
            String errorMsg = 'DML Error updating records: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        } catch (Exception e) {
            String errorMsg = 'Error updating records: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCAgentException(errorMsg);
        }
    }
}


