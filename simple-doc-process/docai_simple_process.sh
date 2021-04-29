#!/bin/bash

# Update Values to with DocAI Processor Information
export LOCATION="us" #Enter the DocumentAI Processor location
export PROCESSOR_ID="617440e88ba39de9"  #Enter the DocumentAI Processor ID

# Update Values to Reflect Form and Entity Details
export FORM_FILE_PATH="../sample-forms/form.pdf" #Enter path to form
export LOAN_ID="2345678" #Enter a unique ID to categorize the forms. This ID will be used in the GCS output path and as a ID in the BQ table.
FORM_NAME="Health Intake Form" #Enter the form name. The BQ table will take on this name.
ASSOCIATION_NAME="Bank of Farms" # Enter the association name. The GCS output directory and BQ dataset will take on this name.

export PROJECT_ID="$(gcloud config get-value project)"

# Update Values if Different from Environment Prep or Rerun Enviorment Prep to Reset Client Configuration
DOCUMENT_BUCKET="${PROJECT_ID}-docai-import" # For storing documents in GCS
OUTPUT_BUCKET="${PROJECT_ID}-docai-output" # For storing document parsing output in GCS
# REGION="us-east1" # Location for GCS bucket
# export GOOGLE_APPLICATION_CREDENTIALS="key.json"
# gcloud config set project ${PROJECT_ID} -q
# gcloud config set compute/region ${REGION} -q
# gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS} -q

# Do not Edit Below 
OUTPUT_FILE_NAME="${FORM_NAME// /_}.json"
DATASET_NAME="${ASSOCIATION_NAME// /_}"
TABLE_NAME="${FORM_NAME// /_}"
OUTPUT_DIR_UUID="${ASSOCIATION_NAME// /_}"/"${LOAN_ID// /_}"

mkdir -p "${OUTPUT_DIR_UUID// /_}"

# If not created during enviorment prep, create a new storage bucket for importing form files
if [[ "$(gsutil ls | grep gs://${DOCUMENT_BUCKET}/)" = "" ]]; then 
    gsutil -q mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} -b on gs://${DOCUMENT_BUCKET}
fi

# If not created during environment prep, create json output GCS bucket location
if [[ "$(gsutil ls | grep gs://${OUTPUT_BUCKET}/)" = "" ]]; then 
    gsutil -q mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} -b on gs://${OUTPUT_BUCKET}
fi

# Python Code to Process the Document

read -r -d '' PYTHON_SCRIPT1 <<-"EOF"

import os
import json
import sys
import re

def process_document_sample(
    project_id=os.environ['PROJECT_ID'], 
    location=os.environ['LOCATION'], 
    processor_id=os.environ['PROCESSOR_ID'], 
    file_path=os.environ['FORM_FILE_PATH'],
    loan_id=os.environ['LOAN_ID']
):
    from google.cloud import documentai_v1 as documentai

    # You must set the api_endpoint if you use a location other than 'us', e.g.:
    opts = {}
    if location == "eu":
        opts = {"api_endpoint": "eu-documentai.googleapis.com"}

    client = documentai.DocumentProcessorServiceClient(client_options=opts)

    # The full resource name of the processor, e.g.:
    # projects/project-id/locations/location/processor/processor-id
    # You must create new processors in the Cloud Console first
    name = f"projects/{project_id}/locations/{location}/processors/{processor_id}"

    with open(file_path, "rb") as image:
        image_content = image.read()

    # Read the file into memory
    document = {"content": image_content, "mime_type": "application/pdf"}

    # Configure the process request
    request = {"name": name, "raw_document": document}

    # Recognizes text entities in the PDF document
    result = client.process_document(request=request)

    document = result.document
    document_text = document.text

    # print("Document processing complete.")
    # print("Text: {}".format(document_text)) 

    # For a full list of Document object attributes, please reference this page: https://googleapis.dev/python/documentai/latest/_modules/google/cloud/documentai_v1beta3/types/document.html#Document

    document_pages = document.pages

    # Read the text recognition output from the processor
    for page in document_pages:
        print ("{")
        print (json.dumps("loanId")+":"+json.dumps(loan_id)+",")
        # print(json.dumps("PageNumber_"+str(page.page_number))+":[")
        for form_field in page.form_fields:
            fieldName=get_text(form_field.field_name,document)
            fieldNameJson=re.sub('[^a-zA-Z0-9_]', '', fieldName)
            nameConfidence = round(form_field.field_name.confidence,4)
            fieldValue = get_text(form_field.field_value,document)
            fieldValueJson=fieldValue.replace('\n', '') 
            valueConfidence = round(form_field.field_value.confidence,4)
            print(json.dumps(fieldNameJson)+":{"+json.dumps("value")+":"+json.dumps(fieldValueJson)+","+json.dumps("keyConfidence")+":"+json.dumps(str(nameConfidence))+","+json.dumps("valueConfidence")+":"+json.dumps(str(valueConfidence))+","+json.dumps("pageNumber")+":"+json.dumps(str(page.page_number))+"},")
        print("}")
        print()



# Extract shards from the text field
def get_text(doc_element: dict, document: dict):
    """
    Document AI identifies form fields by their offsets
    in document text. This function converts offsets
    to text snippets.
    """
    response = ""
    # If a text segment spans several lines, it will
    # be stored in different text segments.
    for segment in doc_element.text_anchor.text_segments:
        start_index = (
            int(segment.start_index)
            if segment in doc_element.text_anchor.text_segments
            else 0
        )
        end_index = int(segment.end_index)
        response += document.text[start_index:end_index]
    return response

process_document_sample()

# [END documentai_process_document]
EOF

# Convert and Clean DocAI output to Biq Query Acceptable JSON format

python -c "$PYTHON_SCRIPT1" > tmp1.json
sed 'H;1h;$!d;x;s/\(.*\),/\1/' tmp1.json > tmp2.json
sed -e :a -e '$!N; s/\n/ /; ta' tmp2.json > "${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}"
rm -rf tmp* # Comment out to troubleshoot json conversion

# Upload ${OUTPUT_FILE_NAME} to GCS bucket
gsutil -q cp "${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}" "gs://${OUTPUT_BUCKET}/${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}"

# echo "The json output file is stored locally at $PWD/${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}" 
# echo "A copy was also uploaded to GCS under the following path gs://${OUTPUT_BUCKET}/${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}"

# Create a Biq Query Dataset

if [ -z $(bq ls | grep "${DATASET_NAME}") ]; then 
bq --location=${LOCATION} mk \
--dataset \
--description "Dataset for the ${DATASET_NAME} association" \
"${PROJECT_ID}":"${DATASET_NAME}"
fi

# Create and Load a Big Query Table

bq --location=${LOCATION} load \
--autodetect \
--replace \
--source_format=NEWLINE_DELIMITED_JSON \
"${DATASET_NAME}"."${TABLE_NAME}" \
"$PWD/${OUTPUT_DIR_UUID}/${OUTPUT_FILE_NAME}"
