I have been hours debugging and by mistake i just deleted the original branch with the comments to learn from them.

from now on remember to keep all the git comments and if creation of another branch remember to keep it until done

Well, i can descrite what i have learned: 1 the config of the VPC publics are facing the internet so it goes to the route tables association goes to the private ( no IGW ) we can also implement a NAT but not yet 

2.Terraform loged with Github so easier implementation, controll billing in ueast-1 only 

3.typos with internet_gateaway and a lot of other fixed , variables separated from the others files 


4.Remember that if you have more than one account and ssh key for github in machine try to authentice with the one that you want to use instead of changing everytime that you need each account a config file help me to solve this with just ONE account 

5.Delegation of Domains can be a pain so instead of a custom NS record for subdomain ( which hostinger did not allow ) i use the ACM certification in Terraform with the AWS ACM , so we use a CNAME recod which hostinger can provide 
