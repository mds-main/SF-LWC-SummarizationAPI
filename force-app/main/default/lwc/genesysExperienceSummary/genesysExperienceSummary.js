import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateWrapUpCode from '@salesforce/apex/ExperienceCopilotController.updateWrapUpCode';

const DEBUG_HEADER = 'genesysExperienceSummary.js';

const FIELDS = [
    'genesysps__Experience__c.GC_Copilot_wrap_up_1_name__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_1_confidence__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_1_id__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_2_name__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_2_confidence__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_2_id__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_3_name__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_3_confidence__c',
    'genesysps__Experience__c.GC_Copilot_wrap_up_3_id__c',
    'genesysps__Experience__c.GC_Copilot_summary_text__c',
    'genesysps__Experience__c.GC_Copilot_summary_confidence__c',
    'genesysps__Experience__c.GC_Copilot_resolution_text__c',
    'genesysps__Experience__c.GC_Copilot_resolution_confidence__c',
    'genesysps__Experience__c.GC_Copilot_reason_text__c',
    'genesysps__Experience__c.GC_Copilot_reason_confidence__c',
    'genesysps__Experience__c.GC_Copilot_followup_text__c',
    'genesysps__Experience__c.GC_Copilot_followup_confidence__c',
    'genesysps__Experience__c.genesysps__Interaction_Id__c',
    'genesysps__Experience__c.GC_Copilot_participant_id__c',
		'genesysps__Experience__c.GC_agent_participant_id__c',
    'genesysps__Experience__c.GC_Copilot_communication_id__c'
];

export default class ExperienceCopilotSummary extends LightningElement {
    @api recordId;
    isProcessing = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    experience;

    get getWrapUpBoxClass() {
        return `summary-box custom-summary-box wrap-up-box ${this.isProcessing ? 'processing' : ''}`;
    }

    connectedCallback() {
        console.log(`${DEBUG_HEADER} - Component initialized with recordId: ${this.recordId}`);
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredExperience({ error, data }) {
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
        if (!this.experience?.data) {
            console.log(`${DEBUG_HEADER} - No experience data available`);
            return null;
        }
        const fieldName = `genesysps__Experience__c.GC_Copilot_wrap_up_${index}_id__c`;
        const id = getFieldValue(this.experience.data, fieldName);
        console.log(`${DEBUG_HEADER} - Retrieved wrap-up ID for index ${index}: ${id}`);
        return id;
    }

    get wrapUp1() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_1_name__c') || '';
    }

    get wrapUp2() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_2_name__c') || '';
    }

    get wrapUp3() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_3_name__c') || '';
    }

    get summary() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_summary_text__c') || '';
    }

    get resolution() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_resolution_text__c') || '';
    }

    get reason() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_reason_text__c') || '';
    }

    get followup() {
        return getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_followup_text__c') || '';
    }

    getConfidenceColor(confidence) {
        console.log(`${DEBUG_HEADER} - Calculating confidence color for value: ${confidence}`);
        if (!confidence) return '#e5e5e5';

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
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_1_confidence__c'));
    }

    get wrapUp2Style() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_2_confidence__c'));
    }

    get wrapUp3Style() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_wrap_up_3_confidence__c'));
    }

    get summaryStyle() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_summary_confidence__c'));
    }

    get resolutionStyle() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_resolution_confidence__c'));
    }

    get reasonStyle() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_reason_confidence__c'));
    }

    get followupStyle() {
        return this.generateStyle(getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_followup_confidence__c'));
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
								interactionId: getFieldValue(this.experience.data, 'genesysps__Experience__c.genesysps__Interaction_Id__c'),
								wrapUpCodeId: wrapUpId,
								participantId: getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_agent_participant_id__c'),
								communicationId: getFieldValue(this.experience.data, 'genesysps__Experience__c.GC_Copilot_communication_id__c')
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

    showToast(title, message, variant) {
        console.log(`${DEBUG_HEADER} - Showing toast - Title: ${title}, Message: ${message}, Variant: ${variant}`);
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
