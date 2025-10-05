# EC2 Instance Module

Production-ready EC2 instance module with Auto Scaling Group support.

## Features
- Auto Scaling Groups
- Launch Templates
- EBS volume management
- User data support
- Security group integration
- CloudWatch monitoring

## Usage

```hcl
module "web_servers" {
  source = "../../../modules/ec2"

  name          = "web-server"
  instance_type = "t3.medium"
  ami_id        = data.aws_ami.amazon_linux_2.id
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  min_size         = 2
  max_size         = 10
  desired_capacity = 4
  
  user_data = filebase64("${path.module}/user-data.sh")
  
  tags = {
    Environment = "production"
    Application = "web"
  }
}
```
