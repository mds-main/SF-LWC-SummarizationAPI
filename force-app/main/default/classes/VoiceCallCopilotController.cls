public with sharing class VoiceCallCopilotController {
    private static final String DEBUG_HEADER = '*** VoiceCallCopilotController *** ';

    public class FlowInputs {
        @InvocableVariable(label='Interaction ID' description='The Genesys Cloud interaction ID' required=true)
        public String interactionId;
        @InvocableVariable(label='Wrap-up Code ID' description='The wrap-up code to be applied' required=true)
        public String wrapUpCodeId;
    }

    public class WrapUpException extends Exception {}

    @AuraEnabled
    public static void updateWrapUpCode(String interactionId, String wrapUpCodeId,
                                      String participantId, String communicationId) {
        System.debug(DEBUG_HEADER + 'Entering updateWrapUpCode');
        try {
            System.debug(DEBUG_HEADER + 'Input parameters:');
            System.debug(DEBUG_HEADER + 'interactionId: ' + interactionId);
            System.debug(DEBUG_HEADER + 'wrapUpCodeId: ' + wrapUpCodeId);
            System.debug(DEBUG_HEADER + 'participantId: ' + participantId);
            System.debug(DEBUG_HEADER + 'communicationId: ' + communicationId);

            if (String.isBlank(interactionId) || String.isBlank(wrapUpCodeId) ||
                String.isBlank(participantId) || String.isBlank(communicationId)) {
                throw new WrapUpException('All parameters are required');
            }

            FlowInputs input = new FlowInputs();
            input.interactionId = interactionId;
            input.wrapUpCodeId = wrapUpCodeId;

            String endpoint = 'callout:GC_Base_API/api/v2/conversations/calls/' +
                            interactionId + '/participants/' +
                            participantId + '/communications/' +
                            communicationId + '/wrapup';

            System.debug(DEBUG_HEADER + 'Constructed endpoint: ' + endpoint);
            String jsonInput = JSON.serialize(input);
            System.debug(DEBUG_HEADER + 'Serialized input: ' + jsonInput);

            futureCallout(jsonInput, endpoint);
            System.debug(DEBUG_HEADER + 'Successfully initiated future callout');

        } catch (Exception e) {
            String errorMsg = 'Error in updateWrapUpCode: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new AuraHandledException(errorMsg);
        }
    }

    @future(callout=true)
    private static void futureCallout(String jsonInput, String endpoint) {
        System.debug(DEBUG_HEADER + 'Entering futureCallout');
        System.debug(DEBUG_HEADER + 'Input: ' + jsonInput);
        System.debug(DEBUG_HEADER + 'Endpoint: ' + endpoint);

        try {
            FlowInputs input = (FlowInputs)JSON.deserialize(jsonInput, FlowInputs.class);
            System.debug(DEBUG_HEADER + 'Deserialized input successfully');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');

            Map<String, String> requestBody = new Map<String, String>{'code' => input.wrapUpCodeId};
            String body = JSON.serialize(requestBody);
            req.setBody(body);

            System.debug(DEBUG_HEADER + 'Request details:');
            System.debug(DEBUG_HEADER + 'Method: ' + req.getMethod());
            System.debug(DEBUG_HEADER + 'Body: ' + body);

            Http http = new Http();
            HttpResponse response = http.send(req);

            System.debug(DEBUG_HEADER + 'API Response Status Code: ' + response.getStatusCode());
            System.debug(DEBUG_HEADER + 'API Response Status: ' + response.getStatus());
            System.debug(DEBUG_HEADER + 'API Response Body: ' + response.getBody());

            // Accept both 200 and 202 status codes as success
            if (response.getStatusCode() != 200 && response.getStatusCode() != 202) {
                throw new WrapUpException('Failed to update wrap-up code: ' + response.getBody());
            }

            System.debug(DEBUG_HEADER + 'Successfully updated wrap-up code');

        } catch (Exception e) {
            String errorMsg = 'Error in futureCallout: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new WrapUpException(errorMsg);
        }
    }
}
