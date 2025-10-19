# -------------------------------------------------------------------
# Package the Lambda function automatically before deployment
# -------------------------------------------------------------------
#data "archive_file" "lambda_zip" {
 # type        = "zip"
  #source_file = "${path.module}/scripts/lambda_autoscale.py"
  #output_path = "${path.module}/scripts/lambda_autoscale.py.zip"
#}
