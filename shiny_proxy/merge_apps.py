#!/usr/bin/env python3
import boto3
import yaml
import json
import os
import sys
from typing import Dict, List, Optional, Any
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ShinyProxyConfigManager:
    """Manages ShinyProxy configuration with pre-initialization support"""
    
    def __init__(self, team_name: str):
        self.team_name = team_name
        self.s3_client = boto3.client('s3')
        self.ssm_client = boto3.client('ssm')
        self.secrets_client = boto3.client('secretsmanager')
        
    def get_secret(self, secret_name: str) -> Dict[str, Any]:
        """Retrieve secret from AWS Secrets Manager"""
        try:
            response = self.secrets_client.get_secret_value(SecretId=secret_name)
            return json.loads(response['SecretString'])
        except Exception as e:
            logger.error(f"Error retrieving secret {secret_name}: {e}")
            raise
    
    def get_parameter(self, parameter_name: str) -> str:
        """Retrieve parameter from AWS Parameter Store"""
        try:
            response = self.ssm_client.get_parameter(
                Name=parameter_name,
                WithDecryption=True
            )
            return response['Parameter']['Value']
        except Exception as e:
            logger.error(f"Error retrieving parameter {parameter_name}: {e}")
            raise
    
    def read_s3_yaml(self, bucket: str, key: str) -> Dict[str, Any]:
        """Read YAML file from S3"""
        try:
            response = self.s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            return yaml.safe_load(content)
        except Exception as e:
            logger.error(f"Error reading S3 file {bucket}/{key}: {e}")
            raise
    
    def setup_base_config(self) -> Dict[str, Any]:
        """Set up base application configuration"""
        config = {
            'server': {
                'forward-headers-strategy': 'native',
                'use-forward-headers': True
            },
            'logging': {
                'level': {
                    'root': 'INFO',
                    'eu.openanalytics': 'DEBUG',
                    'org.springframework.web': 'INFO'
                }
            },
            'management': {
                'metrics': {
                    'export': {
                        'cloudwatch': {
                            'enabled': True,
                            'namespace': f'ShinyProxy/{self.team_name}',
                            'step': '1m'
                        }
                    }
                }
            },
            'spring': {
                'session': {
                    'store-type': 'redis',
                    'redis': {
                        'namespace': f'shinyproxy:{self.team_name}',
                        'flush-mode': 'immediate'
                    }
                },
                'redis': {
                    'host': os.getenv('REDIS_HOST', 'localhost'),
                    'port': int(os.getenv('REDIS_PORT', '6379')),
                    'password': os.getenv('REDIS_PASSWORD', '')
                }
            }
        }
        return config
    
    def setup_proxy_config(self) -> Dict[str, Any]:
        """Set up proxy-specific configuration with pre-initialization support"""
        return {
            'title': f'{self.team_name} Analytics Platform',
            'logo-url': f'https://www.openanalytics.eu/shinyproxy/logo.png',
            'landing-page': '/',
            'heartbeat-rate': 10000,
            'heartbeat-timeout': 60000,
            'port': 8080,
            'authentication': 'openid',
            'admin-groups': ['shinyproxy-admins', f'{self.team_name}-admins'],
            'container-backend': 'ecs',
            'container-wait-time': 60000,
            'container-log-path': f'/var/log/shinyproxy/{self.team_name}',
            # Pre-initialization specific settings
            'support-container-re-use': True,
            'container-cleanup-interval': 3600000,  # 1 hour
            'max-container-age': 0,  # Unlimited for pre-initialized containers
            'track-app-url': True,
            'store-mode': 'Redis',
            # Recovery settings for pre-initialized containers
            'recover-running-proxies': True,
            'recover-running-proxies-from-different-config': False
        }
    
    def setup_ecs_config(self) -> Dict[str, Any]:
        """Set up ECS-specific configuration"""
        cluster_name = os.getenv('CLUSTER_NAME', f'{self.team_name}-cluster')
        return {
            'ecs': {
                'cluster': cluster_name,
                'region': os.getenv('AWS_REGION', 'us-east-1'),
                'security-groups': [os.getenv('SECURITY_GROUP')],
                'subnets': os.getenv('SUBNETS', '').split(','),
                'enable-cloudwatch': True,
                'task-role': os.getenv('TASK_ROLE_ARN'),
                'execution-role': os.getenv('EXECUTION_ROLE_ARN')
            }
        }
    
    def setup_openid_config(self) -> Dict[str, Any]:
        """Set up OpenID Connect configuration"""
        client_secret = self.get_secret(f'{self.team_name}/openid/client-secret')
        
        return {
            'openid': {
                'auth-url': 'https://login.microsoftonline.com/oauth/v2.0/authorize',
                'token-url': 'https://login.microsoftonline.com/oauth/v2.0/token',
                'jwks-url': 'https://login.microsoftonline.com/discovery/v2.0/keys',
                'logout-url': 'https://login.microsoftonline.com/common/oauth2/v2.0/logout',
                'client-id': self.get_parameter(f'/{self.team_name}/openid/client-id'),
                'client-secret': client_secret['value'],
                'scopes': ['openid', 'profile', 'email', 'offline_access'],
                'username-attribute': 'preferred_username',
                'roles-claim': 'groups'
            }
        }
    
    def configure_pre_initialization(self, app_spec: Dict[str, Any]) -> Dict[str, Any]:
        """Configure app for pre-initialization with proper header mapping"""
        
        # Enable pre-initialization settings
        pre_init_config = app_spec.get('pre-initialization', {})
        
        if pre_init_config.get('enabled', False):
            # Set minimum instances
            min_seats = pre_init_config.get('minimum-seats', 1)
            app_spec['container-instances-min'] = min_seats
            app_spec['container-instances-max'] = pre_init_config.get('max-seats', min_seats * 3)
            
            # Configure container pooling
            app_spec['container-wait-time'] = pre_init_config.get('wait-time', 60000)
            app_spec['container-idle-timeout'] = pre_init_config.get('idle-timeout', 3600000)
            
            # Set up authentication headers for pre-initialized containers
            if 'http-headers' not in app_spec:
                app_spec['http-headers'] = {}
            
            app_spec['http-headers'].update({
                'X-SP-UserId': '#{proxy.userId}',
                'X-SP-UserGroups': '#{proxy.userGroups}',
                'X-SP-UserAttributes': '#{proxy.userAttributes}',
                'X-SP-AccessToken': '#{oidcUser.accessToken}',
                'X-SP-IdToken': '#{oidcUser.idToken}',
                'X-SP-RefreshToken': '#{oidcUser.refreshToken}',
                'X-SP-SessionId': '#{proxy.sessionId}',
                'X-SP-TeamName': self.team_name
            })
            
            # Add environment variables for backward compatibility
            if 'container-env' not in app_spec:
                app_spec['container-env'] = {}
            
            app_spec['container-env'].update({
                'SP_CONTAINER_PRE_INIT': 'true',
                'SP_AUTH_TYPE': 'header',
                'SP_TEAM_NAME': self.team_name,
                'SP_APP_INSTANCE_ID': '#{proxy.appInstanceId}'
            })
            
            # Configure container sharing if specified
            if 'sharing' in pre_init_config:
                sharing_config = pre_init_config['sharing']
                if sharing_config.get('enabled', False):
                    app_spec['container-sharing-enabled'] = True
                    if 'allowed-users' in sharing_config:
                        app_spec['access-users'] = sharing_config['allowed-users']
                    if 'allowed-groups' in sharing_config:
                        app_spec['access-groups'] = sharing_config['allowed-groups']
                    app_spec['container-sharing-groups'] = sharing_config.get('allowed-groups', [])
        
        return app_spec
    
    def configure_app_resources(self, app_spec: Dict[str, Any]) -> Dict[str, Any]:
        """Configure ECS task resources for the app"""
        
        # Default resource allocation
        default_cpu = app_spec.get('container-cpu-request', 1024)
        default_memory = app_spec.get('container-memory-request', 2048)
        
        # ECS-specific configuration
        if 'ecs' not in app_spec:
            app_spec['ecs'] = {}
        
        app_spec['ecs'].update({
            'task-definition': f"{self.team_name}-{app_spec['id']}-task",
            'cpu': str(default_cpu),
            'memory': str(default_memory),
            'enable-execute-command': True,
            'log-configuration': {
                'logDriver': 'awslogs',
                'options': {
                    'awslogs-group': f'/ecs/{self.team_name}/{app_spec["id"]}',
                    'awslogs-region': os.getenv('AWS_REGION', 'us-east-1'),
                    'awslogs-stream-prefix': 'ecs'
                }
            }
        })
        
        return app_spec
    
    def merge_apps_config(self, base_config: Dict[str, Any]) -> Dict[str, Any]:
        """Merge apps from S3 with base configuration"""
        
        # Read apps from S3
        bucket_name = f'{self.team_name}-shinyproxy-config'
        apps_config = self.read_s3_yaml(bucket_name, 'apps.yml')
        
        specs = []
        for app_spec in apps_config.get('specs', []):
            logger.info(f"Processing app: {app_spec['id']}")
            
            # Configure pre-initialization
            app_spec = self.configure_pre_initialization(app_spec)
            
            # Configure resources
            app_spec = self.configure_app_resources(app_spec)
            
            # Add Redis namespace for session isolation
            if 'container-env' not in app_spec:
                app_spec['container-env'] = {}
            app_spec['container-env']['REDIS_NAMESPACE'] = f"{self.team_name}:{app_spec['id']}"
            
            # Add app-specific metadata
            app_spec['metadata'] = {
                'team': self.team_name,
                'created': datetime.utcnow().isoformat(),
                'version': '2.0'
            }
            
            specs.append(app_spec)
        
        base_config['proxy']['specs'] = specs
        return base_config
    
    def generate_config(self) -> Dict[str, Any]:
        """Generate complete ShinyProxy configuration"""
        logger.info(f"Generating configuration for team: {self.team_name}")
        
        # Build base configuration
        config = self.setup_base_config()
        
        # Add proxy configuration
        config['proxy'] = self.setup_proxy_config()
        
        # Add authentication
        config.update(self.setup_openid_config())
        
        # Add ECS backend configuration
        config['proxy'].update(self.setup_ecs_config())
        
        # Merge apps configuration
        config = self.merge_apps_config(config)
        
        return config
    
    def write_config(self, config: Dict[str, Any], output_path: str):
        """Write configuration to file"""
        with open(output_path, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)
        logger.info(f"Configuration written to: {output_path}")

def main():
    """Main entry point"""
    team_name = os.getenv('TEAM_NAME')
    if not team_name:
        logger.error("TEAM_NAME environment variable not set")
        sys.exit(1)
    
    try:
        manager = ShinyProxyConfigManager(team_name)
        config = manager.generate_config()
        manager.write_config(config, '/opt/shinyproxy/application.yml')
        logger.info("Configuration generation completed successfully")
    except Exception as e:
        logger.error(f"Configuration generation failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
