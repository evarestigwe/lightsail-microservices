import boto3
import os

client = boto3.client('lightsail', region_name=os.getenv("AWS_REGION"))

PROJECT = os.getenv("PROJECT_NAME")
BUNDLE_ID = os.getenv("BUNDLE_ID")
AZ = os.getenv("AVAILABILITY_ZONE")
SSH_KEY = os.getenv("SSH_KEY_NAME")
MIN_WORKERS = int(os.getenv("MIN_WORKERS"))
MAX_WORKERS = int(os.getenv("MAX_WORKERS"))

def lambda_handler(event, context):
    print("⚙️ Autoscaler invoked")




resource "aws_lambda_function" "lightsail_autoscaler" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "lightsail-autoscaler"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_autoscale.lambda_handler"
  runtime          = "python3.10"
  timeout          = 60
}


    
    # List existing workers
    instances = client.get_instances()['instances']
    workers = [i for i in instances if f"{PROJECT}-worker" in i['name']]
    
    alarm_name = event['detail']['alarmName']
    new_worker_name = f"{PROJECT}-worker-{len(workers)+1}"
    
    # SCALE UP
    if 'high' in alarm_name.lower() and len(workers) < MAX_WORKERS:
        print(f"🚀 Scaling up: Creating {new_worker_name}")
        client.create_instances(
            instanceNames=[new_worker_name],
            availabilityZone=AZ,
            blueprintId="ubuntu_22_04",
            bundleId=BUNDLE_ID,
            keyPairName=SSH_KEY
        )
        print("✅ Scale-up complete")
    
    # SCALE DOWN
    elif 'low' in alarm_name.lower() and len(workers) > MIN_WORKERS:
        # Pick last added worker for deletion
        worker_to_delete = workers[-1]['name']
        print(f"⬇️ Scaling down: Deleting {worker_to_delete}")
        client.delete_instance(instanceName=worker_to_delete)
        print("✅ Scale-down complete")
    else:
        print("ℹ️ No scaling action needed")
