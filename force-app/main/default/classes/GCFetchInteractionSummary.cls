public with sharing class GCFetchInteractionSummary {
    private static final String DEBUG_HEADER = '*** GCFetchInteractionSummary *** ';
    private static final Integer MAX_RETRIES = 3;
    private static final Integer DEFAULT_WAIT_TIME = 1;

    public class FlowInputs {
        @InvocableVariable(label='Interaction ID' description='The Genesys Cloud interaction ID' required=true)
        public String interactionId;

        @InvocableVariable(label='Voice Call ID' description='The ID of the related Voice Call' required=false)
        public String voiceCallId;

        @InvocableVariable(label='Experience ID' description='The ID of the related Experience' required=false)
        public String experienceId;

        @InvocableVariable(label='Wait Time' description='Number of seconds to wait before each API call' required=false)
        public Integer waitTime;
    }

    public class GCSummaryException extends Exception {}

    @InvocableMethod(label='GC Fetch Interaction Summary')
    public static void updateInteractionSummary(List<FlowInputs> inputs) {
        System.debug(DEBUG_HEADER + 'Entering updateInteractionSummary');
        try {
            if (inputs == null || inputs.isEmpty()) {
                throw new GCSummaryException('No input parameters provided');
            }

            FlowInputs input = inputs[0];

            System.debug(DEBUG_HEADER + 'Input parameters:');
            System.debug(DEBUG_HEADER + 'interactionId: ' + input.interactionId);
            System.debug(DEBUG_HEADER + 'voiceCallId: ' + input.voiceCallId);
            System.debug(DEBUG_HEADER + 'experienceId: ' + input.experienceId);
            System.debug(DEBUG_HEADER + 'waitTime: ' + input.waitTime);

            if (String.isBlank(input.interactionId)) {
                throw new GCSummaryException('Interaction ID is required');
            }
            if (String.isBlank(input.voiceCallId) && String.isBlank(input.experienceId)) {
                throw new GCSummaryException('Either Voice Call ID or Experience ID must be provided');
            }

            if (input.waitTime == null || input.waitTime <= 0) {
                System.debug(DEBUG_HEADER + 'Setting default wait time of ' + DEFAULT_WAIT_TIME + ' seconds');
                input.waitTime = DEFAULT_WAIT_TIME;
            }

            String jsonInput = JSON.serialize(input);
            System.debug(DEBUG_HEADER + 'Serialized input: ' + jsonInput);
            futureCallout(jsonInput);

            System.debug(DEBUG_HEADER + 'Successfully initiated future callout');

        } catch (Exception e) {
            String errorMsg = 'Error in updateInteractionSummary: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }

    @future(callout=true)
    private static void futureCallout(String jsonInput) {
        System.debug(DEBUG_HEADER + 'Entering futureCallout');
        System.debug(DEBUG_HEADER + 'Input: ' + jsonInput);

        FlowInputs input = (FlowInputs)JSON.deserialize(jsonInput, FlowInputs.class);
        Datetime processingStart = System.now();

        try {
            Boolean success = false;
            Integer retryCount = 0;

            // Initial wait before first attempt
            if (input.waitTime != null && input.waitTime > 0) {
                Datetime initialWaitStart = System.now();
                Datetime initialWaitEnd = initialWaitStart.addSeconds(input.waitTime);
                System.debug(DEBUG_HEADER + 'Initial wait of ' + input.waitTime + ' seconds before first API call');
                while (System.now() < initialWaitEnd) {
                }
            }

            while (!success && retryCount < MAX_RETRIES) {
                System.debug(DEBUG_HEADER + 'Starting attempt ' + (retryCount + 1) + ' of ' + MAX_RETRIES);

                if (retryCount > 0) {
                    Datetime waitStart = System.now();
                    System.debug(DEBUG_HEADER + 'Starting wait period of ' + input.waitTime + ' seconds');
                    System.debug(DEBUG_HEADER + 'Wait start time: ' + waitStart);
                    Datetime waitEndTime = waitStart.addSeconds(input.waitTime);
                    System.debug(DEBUG_HEADER + 'Expected wait end time: ' + waitEndTime);

                    while(System.now() < waitEndTime) {
                        // Active wait
                    }

                    System.debug(DEBUG_HEADER + 'Wait period completed. Actual end time: ' + System.now());
                }

                System.debug(DEBUG_HEADER + 'Making API call for interaction: ' + input.interactionId);
                HttpResponse response = makeAPICall(input.interactionId);

                System.debug(DEBUG_HEADER + 'API Response Status Code: ' + response.getStatusCode());
                System.debug(DEBUG_HEADER + 'API Response Status: ' + response.getStatus());
                System.debug(DEBUG_HEADER + 'API Response Body: ' + response.getBody());

                if (response.getStatusCode() == 200) {
                    if (isSummaryCompleted(response.getBody())) {
                        System.debug(DEBUG_HEADER + 'Summary completed successfully');
                        processResponse(response.getBody(), input.voiceCallId, input.experienceId);
                        success = true;
                    } else {
                        retryCount++;
                        System.debug(DEBUG_HEADER + 'Summary not yet completed. Attempt ' + retryCount + ' of ' + MAX_RETRIES);
                        if (retryCount >= MAX_RETRIES) {
                            throw new GCSummaryException('Summary generation not completed after ' + MAX_RETRIES + ' attempts');
                        }
                    }
                } else if (response.getStatusCode() == 404 && isNotFoundError(response.getBody())) {
                    // Retry for "No summaries found in DB for this hashkey" error
                    retryCount++;
                    System.debug(DEBUG_HEADER + 'No summaries found in DB, retrying... Attempt ' + retryCount + ' of ' + MAX_RETRIES);
                    if (retryCount >= MAX_RETRIES) {
                        throw new GCSummaryException('No summaries found in DB after ' + MAX_RETRIES + ' attempts');
                    }
                } else {
                    String errorMsg = 'Error calling Genesys Cloud API. Status: ' + response.getStatus() +
                        ', Status Code: ' + response.getStatusCode() + ', Body: ' + response.getBody();
                    System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
                    throw new GCSummaryException(errorMsg);
                }
            }

            Datetime processingEnd = System.now();
            Integer totalProcessingTime = (Integer)((processingEnd.getTime() - processingStart.getTime())/1000);
            System.debug(DEBUG_HEADER + 'Total processing time: ' + totalProcessingTime + ' seconds');

        } catch (Exception e) {
            String errorMsg = 'Error in futureCallout: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }

    private static Boolean isSummaryCompleted(String responseBody) {
        System.debug(DEBUG_HEADER + 'Checking if summary is completed');
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            List<Object> sessionSummaries = (List<Object>)responseMap.get('sessionSummaries');

            if (sessionSummaries != null && !sessionSummaries.isEmpty()) {
                for (Integer i = sessionSummaries.size() - 1; i >= 0; i--) {
                    Map<String, Object> summary = (Map<String, Object>)sessionSummaries[i];
                    String text = (String)summary.get('text');
                    List<Object> participants = (List<Object>)summary.get('participants');
                    String status = (String)summary.get('status');
                    if (String.isNotBlank(text) && participants != null && !participants.isEmpty() && status == 'Completed') {
                        System.debug(DEBUG_HEADER + 'Detected completed summary with participants at index ' + i);
                        return true;
                    }
                }
            }

            System.debug(DEBUG_HEADER + 'No session summaries found');
            return false;

        } catch (Exception e) {
            String errorMsg = 'Error checking summary completion: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }

    private static Boolean isNotFoundError(String responseBody) {
        System.debug(DEBUG_HEADER + 'Checking if this is a "No summaries found" error');
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            String message = (String)responseMap.get('message');
            return message != null && message.contains('No summaries found in DB for this hashkey');
        } catch (Exception e) {
            System.debug(DEBUG_HEADER + 'Error checking if this is a not found error: ' + e.getMessage());
            return false;
        }
    }

    private static HttpResponse makeAPICall(String interactionId) {
        System.debug(DEBUG_HEADER + 'Making API call for interaction: ' + interactionId);
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = 'callout:GC_Base_API/api/v2/conversations/' + interactionId + '/summaries';
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');

            System.debug(DEBUG_HEADER + 'API Endpoint: ' + endpoint);
            System.debug(DEBUG_HEADER + 'API Method: ' + req.getMethod());

            Http http = new Http();
            HttpResponse response = http.send(req);

            return response;

        } catch (Exception e) {
            String errorMsg = 'Error making API call: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }

    private static void processResponse(String responseBody, String voiceCallId, String experienceId) {
        System.debug(DEBUG_HEADER + 'Processing response');
        System.debug(DEBUG_HEADER + 'Voice Call ID: ' + voiceCallId);
        System.debug(DEBUG_HEADER + 'Experience ID: ' + experienceId);

        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            List<Object> sessionSummaries = (List<Object>)responseMap.get('sessionSummaries');
            if (sessionSummaries == null || sessionSummaries.isEmpty()) {
                throw new GCSummaryException('No session summaries found in response');
            }

            // Find the last non-empty session summary with participants
            Map<String, Object> summary = null;
            for (Integer i = sessionSummaries.size() - 1; i >= 0; i--) {
                Map<String, Object> currentSummary = (Map<String, Object>)sessionSummaries[i];
                String text = (String)currentSummary.get('text');
                List<Object> participantsCheck = (List<Object>)currentSummary.get('participants');
                if (String.isNotBlank(text) && participantsCheck != null && !participantsCheck.isEmpty()) {
                    summary = currentSummary;
                    break;
                }
            }

            if (summary == null) {
                throw new GCSummaryException('No non-empty session summaries with participants found in response');
            }
            Map<String, Object> fieldValues = new Map<String, Object>();

            fieldValues.put('GC_Copilot_session_summary_id__c', (String)summary.get('id'));
            fieldValues.put('GC_Copilot_summary_text__c', (String)summary.get('text'));
            fieldValues.put('GC_Copilot_summary_confidence__c', (Decimal)summary.get('confidence'));

            List<Object> participants = (List<Object>)summary.get('participants');
            if (participants != null && !participants.isEmpty()) {
                Map<String, Object> participant = (Map<String, Object>)participants[0];
                fieldValues.put('GC_Copilot_participant_id__c', (String)participant.get('id'));
            }

            Map<String, Object> communication = (Map<String, Object>)summary.get('communication');
            if (communication != null) {
                fieldValues.put('GC_Copilot_communication_id__c', (String)communication.get('id'));
            }

            mapNestedField(fieldValues, (Map<String, Object>)summary.get('followup'), 'followup');
            mapNestedField(fieldValues, (Map<String, Object>)summary.get('reason'), 'reason');
            mapNestedField(fieldValues, (Map<String, Object>)summary.get('resolution'), 'resolution');

            List<Object> wrapUpCodes = (List<Object>)summary.get('predictedWrapupCodes');
            if (wrapUpCodes != null && !wrapUpCodes.isEmpty()) {
                mapWrapUpCodes(fieldValues, wrapUpCodes);
            }

            System.debug(DEBUG_HEADER + 'Field values to update:');
            for (String field : fieldValues.keySet()) {
                System.debug(DEBUG_HEADER + field + ': ' + fieldValues.get(field));
            }

            if (String.isNotBlank(voiceCallId)) {
                System.debug(DEBUG_HEADER + 'Updating Voice Call record: ' + voiceCallId);
                updateRecord('VoiceCall', voiceCallId, fieldValues);
            }
            if (String.isNotBlank(experienceId)) {
                System.debug(DEBUG_HEADER + 'Updating Experience record: ' + experienceId);
                updateRecord('genesysps__Experience__c', experienceId, fieldValues);
            }

        } catch (Exception e) {
            String errorMsg = 'Error processing response: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }

    private static void mapNestedField(Map<String, Object> fieldValues, Map<String, Object> sourceMap, String prefix) {
        System.debug(DEBUG_HEADER + 'Mapping nested field for prefix: ' + prefix);
        if (sourceMap != null) {
            fieldValues.put('GC_Copilot_' + prefix + '_confidence__c', (Decimal)sourceMap.get('confidence'));
            fieldValues.put('GC_Copilot_' + prefix + '_text__c', (String)sourceMap.get('text'));
            System.debug(DEBUG_HEADER + 'Mapped ' + prefix + ' confidence: ' + sourceMap.get('confidence'));
            System.debug(DEBUG_HEADER + 'Mapped ' + prefix + ' text: ' + sourceMap.get('text'));
        } else {
            System.debug(DEBUG_HEADER + 'Source map is null for prefix: ' + prefix);
        }
    }

    private static void mapWrapUpCodes(Map<String, Object> fieldValues, List<Object> wrapUpCodes) {
        System.debug(DEBUG_HEADER + 'Mapping wrap-up codes');
        for (Integer i = 0; i < Math.min(3, wrapUpCodes.size()); i++) {
            Map<String, Object> wrapUp = (Map<String, Object>)wrapUpCodes[i];
            Integer index = i + 1;
            fieldValues.put('GC_Copilot_wrap_up_' + index + '_confidence__c', (Decimal)wrapUp.get('confidence'));
            fieldValues.put('GC_Copilot_wrap_up_' + index + '_name__c', (String)wrapUp.get('name'));
            fieldValues.put('GC_Copilot_wrap_up_' + index + '_id__c', (String)wrapUp.get('id'));
            System.debug(DEBUG_HEADER + 'Mapped wrap-up code ' + index + ': ' + wrapUp.get('name') +
                       ' with confidence: ' + wrapUp.get('confidence') +
                       ' and ID: ' + wrapUp.get('id'));
        }
    }

    private static void updateRecord(String objectType, String recordId, Map<String, Object> fieldValues) {
        System.debug(DEBUG_HEADER + 'Updating ' + objectType + ' record: ' + recordId);
        try {
            SObject record = Schema.getGlobalDescribe().get(objectType).newSObject();
            record.put('Id', recordId);

            for (String field : fieldValues.keySet()) {
                record.put(field, fieldValues.get(field));
                System.debug(DEBUG_HEADER + 'Setting field ' + field + ' to: ' + fieldValues.get(field));
            }

            update record;
            System.debug(DEBUG_HEADER + 'Successfully updated ' + objectType + ' record');

        } catch (DmlException e) {
            String errorMsg = 'DML Error updating record: Type=' + objectType +
                            ', Id=' + recordId +
                            ', Error=' + e.getMessage() +
                            ', Fields=' + JSON.serialize(fieldValues) +
                            '\nStack trace: ' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        } catch (Exception e) {
            String errorMsg = 'Unexpected error updating record: Type=' + objectType +
                            ', Id=' + recordId +
                            ', Error=' + e.getMessage() +
                            ', Fields=' + JSON.serialize(fieldValues) +
                            '\nStack trace: ' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, DEBUG_HEADER + errorMsg);
            throw new GCSummaryException(errorMsg);
        }
    }
}


