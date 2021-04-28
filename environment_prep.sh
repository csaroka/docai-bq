#!/bin/bash

PROJECT_ID="cs-docai-demo3" # Existing Project ID
SERVICE_ACCOUNT_ID="docai-sa"  # New service account created for Document AI
DOCUMENT_BUCKET="${PROJECT_ID}-docai-import" # New bucket created from script for storing documents in GCS
OUTPUT_BUCKET="${PROJECT_ID}-docai-output" # New bucket created from script for storing document parsing output in GCS
REGION="us-east1" # Location for GCS bucket

# Set client env

gcloud config set project ${PROJECT_ID}
gcloud config set compute/region ${REGION}

# Enable Base Services and Document AI API
gcloud services enable \
compute.googleapis.com \
iam.googleapis.com \
cloudresourcemanager.googleapis.com \
bigquery.googleapis.com \
bigquerystorage.googleapis.com \
documentai.googleapis.com

# Create a Document AI Service Account, download key, and set env variable to credentials
if [[ $(gcloud iam service-accounts list | grep "${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com") = "" ]]; then 
  gcloud iam service-accounts create ${SERVICE_ACCOUNT_ID} --display-name "docai-service-account"
  gcloud iam service-accounts keys create key.json --iam-account docai-sa@${PROJECT_ID}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/owner"
fi

# Create a new storage bucket for importing form files
if [[ "$(gsutil ls | grep gs://${DOCUMENT_BUCKET}/)" = "" ]]; then 
    gsutil -q mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} -b on gs://${DOCUMENT_BUCKET}
fi

# Create json output GCS bucket location
if [[ "$(gsutil ls | grep gs://${OUTPUT_BUCKET}/)" = "" ]]; then 
    gsutil -q mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} -b on gs://${OUTPUT_BUCKET}
fi

# Activate Service Account
gcloud auth activate-service-account --key-file=key.json
export GOOGLE_APPLICATION_CREDENTIALS="key.json"
gcloud auth application-default print-access-token


# Sample form download
if [ ! -f sample-forms/scott_walker.pdf ]; then
   curl -O -o sample-forms/scott_walker.pdf https://storage.googleapis.com/practical-ml-vision-book/images/scott_walker.pdf 
fi

if [ ! -f sample-forms/loan_form.pdf ]; then
   gsutil -q cp gs://cloud-samples-data/documentai/loan_form.pdf sample-forms/loan_form.pdf
fi

if [ ! -f sample-forms/form.pdf ]; then
  gsutil -q cp gs://cloud-samples-data/documentai/form.pdf sample-forms/form.pdf
fi

# Upload sample form to GCS bucket location
gsutil -q cp sample-forms/scott_walker.pdf gs://${DOCUMENT_BUCKET}/sample-forms/scott_walker.pdf
gsutil -q cp sample-forms/loan_form.pdf gs://${DOCUMENT_BUCKET}/sample-forms/loan_form.pdf
gsutil -q cp sample-forms/form.pdf gs://${DOCUMENT_BUCKET}/sample-forms/form.pdf

echo ""
echo "The Document AI service account name is ${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Sample Forms are stored locally in the sample-forms directory and have been uploaded to gs://${DOCUMENT_BUCKET}/sample-forms/"
