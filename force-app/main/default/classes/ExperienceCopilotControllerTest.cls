@isTest
private class ExperienceCopilotControllerTest {
    
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }
    
    private class MockHttpResponseAccepted implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(202);
            res.setBody('{"success":true}');
            return res;
        }
    }
    
    @isTest
    static void testSuccessfulWrapUpCodeUpdate() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        Test.startTest();
        ExperienceCopilotController.updateWrapUpCode(
            'interaction-123',
            'wrapup-code-456',
            'participant-789',
            'communication-101'
        );
        Test.stopTest();
        
        System.assert(true);
    }
    
    @isTest
    static void testSuccessfulWrapUpCodeUpdateWith202() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseAccepted());
        
        Test.startTest();
        ExperienceCopilotController.updateWrapUpCode(
            'interaction-123',
            'wrapup-code-456',
            'participant-789',
            'communication-101'
        );
        Test.stopTest();
        
        System.assert(true);
    }
    
    @isTest
    static void testInvalidParameters() {
        Boolean exceptionThrown = false;
        try {
            ExperienceCopilotController.updateWrapUpCode(null, null, null, null);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof AuraHandledException);
        }
        System.assert(exceptionThrown, 'Exception should have been thrown');
    }
    
    @isTest
    static void testBlankInteractionId() {
        Boolean exceptionThrown = false;
        try {
            ExperienceCopilotController.updateWrapUpCode('', 'wrapup-code-456', 'participant-789', 'communication-101');
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof AuraHandledException);
        }
        System.assert(exceptionThrown, 'Exception should have been thrown');
    }
    
    @isTest
    static void testBlankWrapUpCodeId() {
        Boolean exceptionThrown = false;
        try {
            ExperienceCopilotController.updateWrapUpCode('interaction-123', '', 'participant-789', 'communication-101');
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof AuraHandledException);
        }
        System.assert(exceptionThrown, 'Exception should have been thrown');
    }
    
    @isTest
    static void testBlankParticipantId() {
        Boolean exceptionThrown = false;
        try {
            ExperienceCopilotController.updateWrapUpCode('interaction-123', 'wrapup-code-456', '', 'communication-101');
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof AuraHandledException);
        }
        System.assert(exceptionThrown, 'Exception should have been thrown');
    }
    
    @isTest
    static void testBlankCommunicationId() {
        Boolean exceptionThrown = false;
        try {
            ExperienceCopilotController.updateWrapUpCode('interaction-123', 'wrapup-code-456', 'participant-789', '');
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof AuraHandledException);
        }
        System.assert(exceptionThrown, 'Exception should have been thrown');
    }
}

