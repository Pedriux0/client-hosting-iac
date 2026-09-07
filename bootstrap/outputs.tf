output "state_bucket_name" {
  description = "The name of the S3 bucket used to store the Terraform state file"
  value       = aws_s3_bucket.tfstate.id
}