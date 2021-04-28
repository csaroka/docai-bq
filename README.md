# Integrating Google Cloud Document AI and Big Query Data Warehouse

## Prerequisites

Install the Google Cloud SDK \
https://cloud.google.com/sdk/docs/install \
Install jq \
https://github.com/stedolan/jq/wiki/Installation\
Install Python 3 \
https://www.python.org/downloads/ \
Create a GCP project \
https://cloud.google.com/resource-manager/docs/creating-managing-projects

## Prepare the Environment

Clone the repository and change directory to `docai-bq/`

```bash
git clone https://github.com/csaroka/docai-bq.git
cd docai-bq
```

Open the `environment_prep.sh` file and update the PROJECT_ID value. Optionally, update the others or proceed with the default values.

```bash
PROJECT_ID="<PROJECT NAME>" # Existing Project ID
SERVICE_ACCOUNT_ID="docai-sa"
DOCUMENT_BUCKET="${PROJECT_ID}-docai-import"
OUTPUT_BUCKET="${PROJECT_ID}-docai-output"
REGION="us-east1"
```

Save and close the file. Then, make `environment_prep.sh` executable

```bash
chmod a+x environment_prep.sh
```

Run the script to prepare the project resources and client configuration

```bash
./environment_prep.sh
```

## Create a Document AI "Form Parser" Processor

*Note: This operations is currently only supported in the Google Cloud console
https://cloud.google.com/document-ai/docs/create-processor*

1. In the Google Cloud Console, in the Document AI section, go to the Processors page.
2. Go to the Processors page
3. Select add **Create processor**.
4. Click on **Form Parser**.

    *Note: Access is restricted to certain processors. If a processor is restricted access you must request access and be approved to be able to create the processor.*

5. In the side Create processor window specify a **Processor name**.
6. Select your **Region** from the list.
7. Click **Create** to create your processor.
8. After the processor has been created, record the Processor ID. For example, 99334450b516e321

## Prepare the Simple Document AI Processing Script

Change to the `simple-doc-process\` directory

```bash
cd simple-doc-process
```

Open the `docai_simple_process.sh` file and update the following values:

```bash
LOCATION="us" #DocumentAI Processor location
PROCESSOR_ID="99334450b516e321"#DocumentAI Processor ID
FORM_FILE_PATH="../sample-forms/form.pdf" #Enter path to form
LOAN_ID="2345678" #Enter a unique ID
FORM_NAME="Intake Form" #Enter the form name
ASSOCIATION_NAME="Bank of SC Farms" #Enter the association name
```

Save and close the file. Then, make `docai_simple_process.sh` executable

```bash
chmod a+x docai_simple_process.sh
```

Run the script to process the document and output the results into a Big Query dataset

```bash
./docai_simple_process.sh
```
