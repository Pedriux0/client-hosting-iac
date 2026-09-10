/// TIER 1 for THE ALB , only one open to Internet 

resource "aws_security_groups" "alb"{
    name = "${var.project_name}-alb-sg"
    description = "ALLOWS HTTP AND HTTPS conections"
    vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http"{
    security_group_id = aws_security_group_alb.id
    description = "HTTP from 0.0.0.0(anywhere), to HTTPS (no main in the middle)"


//RESOURCES should be only able to connect from port 80 defualt http
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}


//EGRESS RULE TO FROWARD THE TRAFFIC  TO THE WEB TIER
resource "aws_vpc_security_group_ingress_rule" "alb_https"{
    security_group_id = aws_security_group.alb.id
    description = "egress rule to move the traffic to the web"

    referenced_security_group_id = aws_security_group.web.id
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}



# --- TIer 2 : Web tier , only from the ALB

resource "aws_security_group" "web"{

    name = "${var.project_name} web-sg"

    description = "Traffic coming from the ALB"

    vpc_id = aws_vpc.main.id

    tags = {Name = "${var.project.name} -web-sg"}

}   

resource "aws_vpc_security_group_ingress_rule" "web_from_alb"{
    security_group_id =  aws_security_group.web.id

    description = "HTTP FROM THE ALB SG"

    referenced_security_group_id = aws_security_group.alb.id

    from_port = 80

    to_port = 80

    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_to_db"{
    security_group_id = aws_security_group.web.id

    description = "MYSQL to the DB tier"

    referenced_security_group_id = aws_security_group.db.id

    from_port = 3306
    to_port =  3306
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_https_out"{
    security_group_id = aws_security_group.web.id
    description =  "HTTPS out for the package installs and ECR containters"

    cidr_ipv4 = "0.0.0.0/0"
    from_port =  443
    to_port = 443
    ip_protocol = "tcp"
}

///TIER 3 : DB only ffrom the web tier

resource "aws_security_group" "db" {
    name = "${var.project.name} DB SG"
    description = "Accept SQL from the Web"

    vpc_id = aws_vpc.main

    tags = {Name =  "${var.project.name} - db -sg"}
}

resource "aws_vpc_security_group_ingress_rule" "db_from_the_web"{
    security_group_id = aws_security_group.db.id 
    description = "SG FROM THE WEB TIER"

    referenced_security_group_id = aws_security_group.web.id
    from_port = 3306
    to_port = 3306
    ip_protocol = "tcp"
}