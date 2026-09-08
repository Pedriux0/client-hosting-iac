resource "aws_acm_certificate" "app"{
    domain_name = var.domain_name 
    validation_method = "DNS"

    lifecycle {
      create_before_destroy = true
    }
}

output "acm_validation_record"{
    
    description = "CNAME record to Hostinger to validation"

    value = {

    name  = tolist(aws_acm_certificate.app.domain_validation_options)[0].resource_record_name
    value = tolist(aws_acm_certificate.app.domain_validation_options)[0].resource_record_value

    
    }
}