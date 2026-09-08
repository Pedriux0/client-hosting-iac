# resource "aws_route53_zone" "app"{
#     name = "app.daily-bugglespiderman.com"

#     tags  = {Name = "${var.project_name}-Zone"}

# }

# output "route_53_nameservers"{
#     description = "NS records with 'app' "
#     value = aws_route53_zone.app.name_servers
# }

//I REALLY TRIED TO IMPLEMENT A NS RECORD FOR ROUTE 53
// JUST LOSE TIME WITH THE HOSTINGER SUPPORT FROM MY DOMAIN