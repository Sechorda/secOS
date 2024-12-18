#!/usr/bin/env python3

import sys
import os
import boto3
import questionary
from botocore.exceptions import ClientError, BotoCoreError, NoCredentialsError
from dotenv import load_dotenv
import CloudFlare

RED = '\033[0;31m'
NC = '\033[0m'  # No Color

# Load environment variables from ~/.env
load_dotenv(os.path.expanduser('~/.env'))

def check_aws_authentication():
    try:
        sts = boto3.client('sts')
        sts.get_caller_identity()
        return True
    except NoCredentialsError:
        print(f"{RED}Error: AWS credentials not found. Please run 'aws configure' to set up your credentials.{NC}")
        return False
    except Exception as e:
        print(f"Error checking AWS authentication: {str(e)}")
        return False

def configure_cloudflare():
    token = questionary.text("Please enter your Cloudflare API token:").ask()
    if not token:
        return None
    
    try:
        # Test the token
        cf = CloudFlare.CloudFlare(token=token)
        cf.zones.get()
        
        # Token works, save it to .env
        env_path = os.path.expanduser('~/.env')
        token_line = f'CLOUDFLARE_TOKEN={token}'
        
        if os.path.exists(env_path):
            with open(env_path, 'r') as f:
                lines = f.readlines()
            
            # Replace existing token or append new one
            token_found = False
            for i, line in enumerate(lines):
                if line.startswith('CLOUDFLARE_TOKEN='):
                    lines[i] = token_line + '\n'
                    token_found = True
                    break
            
            if not token_found:
                lines.append(token_line + '\n')
            
            with open(env_path, 'w') as f:
                f.writelines(lines)
        else:
            with open(env_path, 'w') as f:
                f.write(token_line + '\n')
        
        print("Cloudflare token saved successfully.")
        return cf
    except Exception as e:
        print(f"Error configuring Cloudflare: {str(e)}")
        return None

def get_cloudflare_client():
    cf_token = os.getenv('CLOUDFLARE_TOKEN')
    if not cf_token:
        print("Cloudflare token not found.")
        if questionary.confirm("Would you like to configure Cloudflare now?").ask():
            return configure_cloudflare()
        return None
    
    try:
        cf = CloudFlare.CloudFlare(token=cf_token)
        cf.zones.get()  # Test the connection
        return cf
    except Exception as e:
        print(f"Error with existing Cloudflare token: {str(e)}")
        if questionary.confirm("Would you like to reconfigure Cloudflare?").ask():
            return configure_cloudflare()
        return None

# Create AWS EC2 and Route53 clients using the default credential chain
ec2 = None
route53 = None

def initialize_clients():
    global ec2, route53
    aws_auth = check_aws_authentication()
    
    if aws_auth:
        ec2 = boto3.client('ec2')
        route53 = boto3.client('route53')
        return True
    return False

def handle_aws_error(e, operation):
    if isinstance(e, ClientError):
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        if error_code.endswith('UnauthorizedOperation'):
            print(f"Permission denied: You don't have the necessary permissions to {operation}.")
        else:
            print(f"AWS Error ({error_code}): {error_message}")
    elif isinstance(e, BotoCoreError):
        print(f"AWS Error: {str(e)}")
    else:
        print(f"An unexpected error occurred while trying to {operation}: {str(e)}")

def create_elegant_box(title, content):
    width = max(len(line) for line in content.split('\n')) + 4
    box = f"╔{'═' * (width - 2)}╗\n"
    box += f"║ {title.center(width - 4)} ║\n"
    box += f"╠{'═' * (width - 2)}╣\n"
    for line in content.split('\n'):
        box += f"║ {line.ljust(width - 4)} ║\n"
    box += f"╚{'═' * (width - 2)}╝"
    return box

def list_ec2_instances():
    try:
        response = ec2.describe_instances()
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append({
                    'InstanceId': instance['InstanceId'],
                    'State': instance['State']['Name'],
                    'InstanceType': instance['InstanceType'],
                    'PublicIpAddress': instance.get('PublicIpAddress', 'N/A'),
                    'Tags': instance.get('Tags', [])
                })
        return instances
    except Exception as e:
        handle_aws_error(e, "list EC2 instances")
        return []

def display_ec2_instances():
    instances = list_ec2_instances()
    if not instances:
        print("No EC2 instances found or unable to list instances.")
        return None

    choices = []
    for instance in instances:
        state = instance['State']
        instance_id = instance['InstanceId']
        instance_type = instance['InstanceType']
        public_ip = instance['PublicIpAddress']
        tags_str = ', '.join([f"{tag['Key']}={tag['Value']}" for tag in instance['Tags']])
        choice = f"{instance_id} - {state} - {instance_type} - IP: {public_ip} - Tags: {tags_str}"
        choices.append(choice)

    choices.append(questionary.Separator())
    choices.append("Go back")

    selected = questionary.select(
        "Select an instance to manage (or 'Go back'):",
        choices=choices
    ).ask()

    if selected == "Go back":
        return None

    selected_instance_id = selected.split(' - ')[0]
    selected_instance = next(instance for instance in instances if instance['InstanceId'] == selected_instance_id)

    if selected_instance['State'] == 'stopped':
        if questionary.confirm(f"Do you want to start the instance {selected_instance_id}?").ask():
            start_ec2_instance(selected_instance_id)
    elif selected_instance['State'] == 'running':
        if questionary.confirm(f"Do you want to stop the instance {selected_instance_id}?").ask():
            stop_ec2_instance(selected_instance_id)
    else:
        print(f"Instance {selected_instance_id} is in '{selected_instance['State']}' state. No action taken.")

    return selected_instance_id

def select_from_menu(options, message):
    return questionary.select(
        message,
        choices=options
    ).ask()

def list_route53_domains():
    try:
        response = route53.list_hosted_zones()
        domains = [zone['Name'][:-1] for zone in response['HostedZones']]  # Remove trailing dot
        return domains
    except Exception as e:
        handle_aws_error(e, "list Route53 domains")
        return []

def list_cloudflare_domains(cf):
    try:
        zones = cf.zones.get()
        return [zone['name'] for zone in zones]
    except Exception as e:
        print(f"Error listing Cloudflare domains: {str(e)}")
        return []

def select_dns_provider():
    providers = []
    if route53:
        providers.append("Route53")
    providers.append("Cloudflare")  # Always show Cloudflare as an option
    
    if not providers:
        print("No DNS providers available. Please check your credentials.")
        return None
    
    selected = select_from_menu(providers + ["Go back"], "Select DNS provider:")
    
    if selected == "Cloudflare":
        cloudflare = get_cloudflare_client()
        if not cloudflare:
            return None
        return "Cloudflare"
    
    return selected

def select_domain(provider):
    if provider == "Route53":
        domains = list_route53_domains()
    elif provider == "Cloudflare":
        cloudflare = get_cloudflare_client()
        if not cloudflare:
            return None
        domains = list_cloudflare_domains(cloudflare)
    else:
        return None

    if not domains:
        print(f"No domains found for {provider} or unable to list domains.")
        return None
    
    return select_from_menu(domains + ["Go back"], f"Select a domain to configure DNS records:")

def update_cloudflare_dns(domain, ip_address):
    cloudflare = get_cloudflare_client()
    if not cloudflare:
        return
    
    try:
        # Get zone ID for the domain
        zones = cloudflare.zones.get(params={'name': domain})
        if not zones:
            print(f"No Cloudflare zone found for domain {domain}")
            return
        
        zone_id = zones[0]['id']
        
        # Update A record for domain
        dns_records = cloudflare.zones.dns_records.get(zone_id, params={'name': domain, 'type': 'A'})
        record_data = {
            'name': domain,
            'type': 'A',
            'content': ip_address,
            'proxied': True
        }
        
        if dns_records:
            # Update existing record
            cloudflare.zones.dns_records.put(zone_id, dns_records[0]['id'], data=record_data)
        else:
            # Create new record
            cloudflare.zones.dns_records.post(zone_id, data=record_data)
        
        # Create CNAME records
        for subdomain in ['xss', 'login']:
            full_name = f'{subdomain}.{domain}'
            dns_records = cloudflare.zones.dns_records.get(zone_id, params={'name': full_name, 'type': 'CNAME'})
            record_data = {
                'name': full_name,
                'type': 'CNAME',
                'content': domain,
                'proxied': True
            }
            
            if dns_records:
                cloudflare.zones.dns_records.put(zone_id, dns_records[0]['id'], data=record_data)
            else:
                cloudflare.zones.dns_records.post(zone_id, data=record_data)
        
        print(f"Cloudflare DNS updated for {domain}. A record points to {ip_address}.")
        print(f"CNAME records created for xss.{domain} and login.{domain}.")
    except Exception as e:
        print(f"Error updating Cloudflare DNS: {str(e)}")

def update_route53_dns(domain, ip_address):
    try:
        hosted_zone = route53.list_hosted_zones_by_name(DNSName=domain)['HostedZones'][0]
        zone_id = hosted_zone['Id'].split('/')[-1]

        # Update A record for domain
        route53.change_resource_record_sets(
            HostedZoneId=zone_id,
            ChangeBatch={
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': domain,
                            'Type': 'A',
                            'TTL': 300,
                            'ResourceRecords': [{'Value': ip_address}]
                        }
                    }
                ]
            }
        )

        # Create CNAME records
        for subdomain in ['xss', 'login']:
            route53.change_resource_record_sets(
                HostedZoneId=zone_id,
                ChangeBatch={
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': {
                                'Name': f'{subdomain}.{domain}',
                                'Type': 'CNAME',
                                'TTL': 300,
                                'ResourceRecords': [{'Value': domain}]
                            }
                        }
                    ]
                }
            )

        print(f"Route53 DNS updated for {domain}. A record points to {ip_address}.")
        print(f"CNAME records created for xss.{domain} and login.{domain}.")
    except Exception as e:
        handle_aws_error(e, "update Route53 DNS")

def update_dns(ip_address):
    provider = select_dns_provider()
    if not provider or provider == "Go back":
        return
    
    domain = select_domain(provider)
    if not domain or domain == "Go back":
        return
    
    if provider == "Route53":
        update_route53_dns(domain, ip_address)
    elif provider == "Cloudflare":
        update_cloudflare_dns(domain, ip_address)

def start_ec2_instance(instance_id):
    try:
        ec2.start_instances(InstanceIds=[instance_id])
        print(f"Starting EC2 instance {instance_id}")
        
        waiter = ec2.get_waiter('instance_running')
        waiter.wait(InstanceIds=[instance_id])
        
        response = ec2.describe_instances(InstanceIds=[instance_id])
        public_ip = response['Reservations'][0]['Instances'][0].get('PublicIpAddress', 'N/A')
        
        print(f"EC2 instance {instance_id} is now running.")
        print(f"Public IP: {public_ip}")
        
        update_dns(public_ip)
    except Exception as e:
        handle_aws_error(e, "start the EC2 instance")

def stop_ec2_instance(instance_id):
    try:
        ec2.stop_instances(InstanceIds=[instance_id])
        print(f"Stopping EC2 instance {instance_id}")
        
        waiter = ec2.get_waiter('instance_stopped')
        waiter.wait(InstanceIds=[instance_id])
        
        print(f"EC2 instance {instance_id} has been stopped.")
    except Exception as e:
        handle_aws_error(e, "stop the EC2 instance")

def get_latest_debian_ami():
    try:
        response = ec2.describe_images(
            Owners=['136693071363'],
            Filters=[
                {'Name': 'name', 'Values': ['debian-12-amd64-*']},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        images = sorted(response['Images'], key=lambda x: x['CreationDate'], reverse=True)
        return images[0]['ImageId'] if images else None
    except Exception as e:
        handle_aws_error(e, "fetch the latest Debian 12 AMI")
        return None

def get_private_amis():
    try:
        response = ec2.describe_images(Owners=['self'])
        return response['Images']
    except Exception as e:
        handle_aws_error(e, "fetch private AMIs")
        return []

def select_ami():
    choices = [
        "Use latest Debian 12 AMI",
        "Select from private AMIs",
        "Go back"
    ]
    selected = select_from_menu(choices, "Select AMI option:")
    
    if selected == "Use latest Debian 12 AMI":
        ami_id = get_latest_debian_ami()
        if ami_id:
            print(f"Using latest Debian 12 AMI: {ami_id}")
            return ami_id
        else:
            print("Failed to get latest Debian 12 AMI. Please select from private AMIs.")
            return select_ami()
    elif selected == "Select from private AMIs":
        private_amis = get_private_amis()
        if not private_amis:
            print("No private AMIs found. Using latest Debian 12 AMI.")
            return get_latest_debian_ami()
        
        ami_options = [f"{ami['ImageId']} - {ami.get('Name', 'N/A')}" for ami in private_amis]
        ami_options.append("Go back")
        selected_ami = select_from_menu(ami_options, "Select a private AMI:")
        if selected_ami == "Go back":
            return select_ami()
        return selected_ami.split()[0]
    else:
        return None

def create_ssh_security_group():
    try:
        response = ec2.create_security_group(
            GroupName='SSH-Only',
            Description='Security group for SSH access only'
        )
        security_group_id = response['GroupId']
        
        ec2.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                }
            ]
        )
        print(f"Created new security group: {security_group_id}")
        return security_group_id
    except ClientError as e:
        if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
            print("SSH-Only security group already exists. Fetching its ID...")
            response = ec2.describe_security_groups(GroupNames=['SSH-Only'])
            return response['SecurityGroups'][0]['GroupId']
        else:
            handle_aws_error(e, "create the security group")
            return None

def create_ec2_instance():
    ami_id = select_ami()
    if not ami_id:
        print("No AMI selected. Aborting instance creation.")
        return

    security_group_id = create_ssh_security_group()
    if not security_group_id:
        print("Failed to create or fetch SSH-Only security group. Aborting instance creation.")
        return

    try:
        response = ec2.run_instances(
            ImageId=ami_id,
            InstanceType='t2.micro',
            MinCount=1,
            MaxCount=1,
            SecurityGroupIds=[security_group_id],
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [
                        {
                            'Key': 'Name',
                            'Value': 'SSHOnlyInstance'
                        },
                    ]
                },
            ]
        )
        
        instance_id = response['Instances'][0]['InstanceId']
        print(f"Creating EC2 instance {instance_id}")
        
        waiter = ec2.get_waiter('instance_running')
        waiter.wait(InstanceIds=[instance_id])
        
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance_info = response['Reservations'][0]['Instances'][0]
        public_ip = instance_info.get('PublicIpAddress', 'N/A')
        private_ip = instance_info.get('PrivateIpAddress', 'N/A')
        instance_type = instance_info.get('InstanceType', 'N/A')
        
        instance_details = f"Instance ID: {instance_id}\n"
        instance_details += f"Public IP: {public_ip}\n"
        instance_details += f"Private IP: {private_ip}\n"
        instance_details += f"Instance Type: {instance_type}\n"
        
        elegant_box = create_elegant_box("EC2 Instance Created Successfully", instance_details)
        print(elegant_box)
        
        update_dns(public_ip)
    except Exception as e:
        handle_aws_error(e, "create the EC2 instance")
        print("Note: The instance may have been created despite the error. Please check your AWS console.")

def main():
    if not initialize_clients():
        sys.exit(1)

    choices = [
        "List and manage EC2 instances",
        "Create a new SSH-only EC2 instance",
        "Exit"
    ]
    
    while True:
        try:
            selected = select_from_menu(choices, "Select an action:")
            
            if selected == "List and manage EC2 instances":
                display_ec2_instances()
            elif selected == "Create a new SSH-only EC2 instance":
                create_ec2_instance()
            elif selected == "Exit":
                print("Exiting the program.")
                break
            else:
                print("Invalid selection. Please try again.")
        except KeyboardInterrupt:
            print("\nExiting the program.")
            break
        except Exception as e:
            print(f"An unexpected error occurred: {str(e)}")
            print("Please try again or exit the program.")

if __name__ == "__main__":
    main()