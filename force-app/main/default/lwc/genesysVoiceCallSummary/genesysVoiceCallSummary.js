import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, updateRecord, refreshApex } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateWrapUpCode from '@salesforce/apex/VoiceCallCopilotController.updateWrapUpCode';

const DEBUG_HEADER = 'genesysVoiceCallSummary.js';

const FIELDS = [
    'VoiceCall.GC_Copilot_wrap_up_1_name__c',
    'VoiceCall.GC_Copilot_wrap_up_1_confidence__c',
    'VoiceCall.GC_Copilot_wrap_up_1_id__c',
    'VoiceCall.GC_Copilot_wrap_up_2_name__c',
    'VoiceCall.GC_Copilot_wrap_up_2_confidence__c',
    'VoiceCall.GC_Copilot_wrap_up_2_id__c',
    'VoiceCall.GC_Copilot_wrap_up_3_name__c',
    'VoiceCall.GC_Copilot_wrap_up_3_confidence__c',
    'VoiceCall.GC_Copilot_wrap_up_3_id__c',
    'VoiceCall.GC_Copilot_summary_text__c',
    'VoiceCall.GC_Copilot_summary_confidence__c',
    'VoiceCall.GC_Copilot_resolution_text__c',
    'VoiceCall.GC_Copilot_resolution_confidence__c',
    'VoiceCall.GC_Copilot_reason_text__c',
    'VoiceCall.GC_Copilot_reason_confidence__c',
    'VoiceCall.GC_Copilot_followup_text__c',
    'VoiceCall.GC_Copilot_followup_confidence__c',
    'VoiceCall.GC_Interaction_Id__c',
    'VoiceCall.GC_Copilot_participant_id__c',
    'VoiceCall.GC_agent_participant_id__c',
    'VoiceCall.GC_Copilot_communication_id__c'
];

export default class VoiceCallCopilotSummary extends LightningElement {
    @api recordId;
    isProcessing = false;

    // Auto-save properties
    summaryAutoSaveTimer = null;
    editedSummary = '';
    isEditingSummary = false;

    // Store wire reference for manual refresh
    wiredVoiceCallResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredVoiceCall(result) {
        this.wiredVoiceCallResult = result;
        if (result.data) {
            console.log(`${DEBUG_HEADER} - Record loaded successfully: ${this.recordId}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 1 ID: ${this.getWrapUpId(1)}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 2 ID: ${this.getWrapUpId(2)}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 3 ID: ${this.getWrapUpId(3)}`);
        } else if (result.error) {
            console.error(`${DEBUG_HEADER} - Error loading record:`, result.error);
            this.showToast('Error', 'Failed to load record data', 'error');
        }
    }

    get getWrapUpBoxClass() {
        return `summary-box custom-summary-box wrap-up-box ${this.isProcessing ? 'processing' : ''}`;
    }

    // Method to manually refresh the wired data
    async refreshData() {
        console.log(`${DEBUG_HEADER} - Refreshing data for record: ${this.recordId}`);
        try {
            await refreshApex(this.wiredVoiceCallResult);
            console.log(`${DEBUG_HEADER} - Data refresh completed`);
        } catch (error) {
            console.error(`${DEBUG_HEADER} - Error refreshing data:`, error);
        }
    }

    connectedCallback() {
        console.log(`${DEBUG_HEADER} - Component initialized with recordId: ${this.recordId}`);
        // Initialize scrollbar visibility after component renders
        setTimeout(() => this.updateScrollbarVisibility(), 100);

        // Set up periodic refresh to check for new data from async operations
        this.startPeriodicRefresh();
    }

    // Start periodic refresh to catch async updates
    startPeriodicRefresh() {
        // Refresh after initial delay to catch async operations
        setTimeout(() => {
            this.refreshData();
        }, 5000); // 5 seconds should be enough for async operations to complete

        // Set up recurring refresh every 10 seconds to catch any missed updates
        this.periodicRefreshInterval = setInterval(() => {
            this.refreshData();
        }, 10000);
    }

    disconnectedCallback() {
        // Clean up interval when component is destroyed
        if (this.periodicRefreshInterval) {
            clearInterval(this.periodicRefreshInterval);
        }
    }

    renderedCallback() {
        // Update scrollbar visibility when component re-renders
        this.updateScrollbarVisibility();
    }

    updateScrollbarVisibility() {
        const threshold = 12; // px tolerance to avoid false positives due to rounding
        const textareas = this.template.querySelectorAll('.custom-textarea, .summary-textarea');
        textareas.forEach(textarea => {
            const needsScroll = (textarea.scrollHeight - textarea.clientHeight) > threshold;
            textarea.style.overflowY = needsScroll ? 'auto' : 'hidden';
            textarea.style.overflowX = 'hidden';
        });
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredVoiceCall({ error, data }) {
        if (data) {
            console.log(`${DEBUG_HEADER} - Record loaded successfully: ${this.recordId}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 1 ID: ${this.getWrapUpId(1)}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 2 ID: ${this.getWrapUpId(2)}`);
            console.log(`${DEBUG_HEADER} - Wrap-up 3 ID: ${this.getWrapUpId(3)}`);
        } else if (error) {
            console.error(`${DEBUG_HEADER} - Error loading record:`, error);
            this.showToast('Error', 'Failed to load record data', 'error');
        }
    }

    getWrapUpId(index) {
        if (!this.voiceCall?.data) {
            console.log(`${DEBUG_HEADER} - No voice call data available`);
            return null;
        }
        const fieldName = `VoiceCall.GC_Copilot_wrap_up_${index}_id__c`;
        const id = getFieldValue(this.voiceCall.data, fieldName);
        console.log(`${DEBUG_HEADER} - Retrieved wrap-up ID for index ${index}: ${id}`);
        return id;
    }

    get wrapUp1() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_1_name__c') || '';
    }

    get wrapUp2() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_2_name__c') || '';
    }

    get wrapUp3() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_3_name__c') || '';
    }

    get summary() {
        if (this.isEditingSummary) {
            return this.editedSummary;
        }
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_summary_text__c') || '';
    }

    get resolution() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_resolution_text__c') || '';
    }

    get reason() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_reason_text__c') || '';
    }

    get followup() {
        return getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_followup_text__c') || '';
    }

    getConfidenceColor(confidence) {
        console.log(`${DEBUG_HEADER} - Calculating confidence color for value: ${confidence}`);

        // Use darkest green for confidence=1 or when confidence is not set
        if (!confidence || confidence === 1) {
            console.log(`${DEBUG_HEADER} - Using darkest green for confidence: ${confidence}`);
            return 'rgb(0, 200, 0)';
        }

        const confidenceValue = confidence * 100;

        const colorStops = [
            { confidence: 40, color: { r: 255, g: 0, b: 0 } },
            { confidence: 50, color: { r: 255, g: 50, b: 50 } },
            { confidence: 60, color: { r: 255, g: 195, b: 0 } },
            { confidence: 70, color: { r: 255, g: 214, b: 51 } },
            { confidence: 80, color: { r: 0, g: 255, b: 0 } },
            { confidence: 100, color: { r: 0, g: 200, b: 0 } }
        ];

        if (confidenceValue <= 40) return 'rgb(255, 0, 0)';
        if (confidenceValue >= 80) return 'rgb(0, 200, 0)';

        let lowerStop = colorStops[0];
        let upperStop = colorStops[colorStops.length - 1];

        for (let i = 0; i < colorStops.length - 1; i++) {
            if (confidenceValue >= colorStops[i].confidence &&
                confidenceValue <= colorStops[i + 1].confidence) {
                lowerStop = colorStops[i];
                upperStop = colorStops[i + 1];
                break;
            }
        }

        const range = upperStop.confidence - lowerStop.confidence;
        const percentInRange = (confidenceValue - lowerStop.confidence) / range;

        const r = Math.round(lowerStop.color.r + (upperStop.color.r - lowerStop.color.r) * percentInRange);
        const g = Math.round(lowerStop.color.g + (upperStop.color.g - lowerStop.color.g) * percentInRange);
        const b = Math.round(lowerStop.color.b + (upperStop.color.b - lowerStop.color.b) * percentInRange);

        const color = `rgb(${r}, ${g}, ${b})`;
        console.log(`${DEBUG_HEADER} - Generated confidence color: ${color}`);
        return color;
    }

    generateStyle(confidence) {
        const borderColor = this.getConfidenceColor(confidence);
        const style = `border: 2px solid ${borderColor};
                background-color: white;
                transition: all 0.3s ease;`;
        console.log(`${DEBUG_HEADER} - Generated style with confidence ${confidence}: ${style}`);
        return style;
    }

    get wrapUp1Style() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_1_confidence__c'));
    }

    get wrapUp2Style() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_2_confidence__c'));
    }

    get wrapUp3Style() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_wrap_up_3_confidence__c'));
    }

    get summaryStyle() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_summary_confidence__c'));
    }

    get resolutionStyle() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_resolution_confidence__c'));
    }

    get reasonStyle() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_reason_confidence__c'));
    }

    get followupStyle() {
        return this.generateStyle(getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_followup_confidence__c'));
    }

    async handleWrapUpClick(event) {
        console.log(`${DEBUG_HEADER} - Wrap-up click handler started`);

        if (this.isProcessing) {
            console.log(`${DEBUG_HEADER} - Click ignored - already processing`);
            return;
        }

        const index = event.currentTarget.dataset.index;
        console.log(`${DEBUG_HEADER} - Clicked wrap-up index: ${index}`);

        const wrapUpId = this.getWrapUpId(index);
        console.log(`${DEBUG_HEADER} - Retrieved wrap-up ID: ${wrapUpId}`);

        if (!wrapUpId) {
            console.error(`${DEBUG_HEADER} - No wrap-up ID found for index ${index}`);
            this.showToast('Error', 'No wrap-up code ID available', 'error');
            return;
        }

        this.isProcessing = true;
        console.log(`${DEBUG_HEADER} - Starting update process for ID: ${wrapUpId}`);

        try {
            await updateWrapUpCode({
                interactionId: getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Interaction_Id__c'),
                wrapUpCodeId: wrapUpId,
                participantId: getFieldValue(this.voiceCall.data, 'VoiceCall.GC_agent_participant_id__c'),
                communicationId: getFieldValue(this.voiceCall.data, 'VoiceCall.GC_Copilot_communication_id__c')
            });

            console.log(`${DEBUG_HEADER} - Update successful for wrap-up ID: ${wrapUpId}`);
            this.showToast('Success', 'Wrap-up code update sent', 'success');
        } catch (error) {
            const errorMessage = error.body?.message || 'Error updating wrap-up code';
            console.error(`${DEBUG_HEADER} - Update failed:`, error);
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isProcessing = false;
            console.log(`${DEBUG_HEADER} - Update process completed`);
        }
    }

    handleSummaryInput(event) {
        this.isEditingSummary = true;
        this.editedSummary = event.target.value;

        // Clear existing timer
        if (this.summaryAutoSaveTimer) {
            clearTimeout(this.summaryAutoSaveTimer);
        }

        // Set new timer for auto-save after 2 seconds of inactivity
        this.summaryAutoSaveTimer = setTimeout(() => {
            this.saveSummary();
        }, 2000);
    }

    handleSummaryBlur(event) {
        // Save immediately when user leaves the field
        if (this.isEditingSummary) {
            this.saveSummary();
        }
    }

    async saveSummary() {
        if (!this.isEditingSummary || !this.recordId) {
            return;
        }

        console.log(`${DEBUG_HEADER} - Auto-saving summary: ${this.editedSummary}`);

        try {
            const fields = {};
            fields['Id'] = this.recordId;
            fields['GC_Copilot_summary_text__c'] = this.editedSummary;

            const recordInput = {
                fields: fields
            };

            // Update the record
            await updateRecord(recordInput);

            // Reset editing state
            this.isEditingSummary = false;
            this.editedSummary = '';

            // Clear timer
            if (this.summaryAutoSaveTimer) {
                clearTimeout(this.summaryAutoSaveTimer);
                this.summaryAutoSaveTimer = null;
            }

            this.showToast('Success', 'Summary update sent', 'success');

        } catch (error) {
            console.error(`${DEBUG_HEADER} - Error saving summary:`, error);
            this.showToast('Error', 'Failed to save summary', 'error');

            // Reset editing state on error
            this.isEditingSummary = false;
            this.editedSummary = '';
            if (this.summaryAutoSaveTimer) {
                clearTimeout(this.summaryAutoSaveTimer);
                this.summaryAutoSaveTimer = null;
            }
        }
    }

    showToast(title, message, variant) {
        console.log(`${DEBUG_HEADER} - Showing toast - Title: ${title}, Message: ${message}, Variant: ${variant}`);
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
