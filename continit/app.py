# In your merge_apps.py, modify the app spec generation:
def setup_app_config(app_config, team_name):
    app_spec = {
        'id': app_config['id'],
        'container-cpu-request': 1024,
        'container-memory-request': 2048,
        
        # Static environment variables (available during pre-init)
        'container-env': {
            'APP_DIR': '/home/shinyuser',
            'APP_TYPE': app_config.get('type', 'rshiny'),
            'S3_BUCKET': f"{team_name}-sagemaker-globaltech-dev",
            'S3_KEY': app_config.get('s3_key'),
            # Don't put user-specific data here
        },
        
        # HTTP headers for user context (injected on assignment)
        'http-headers': {
            'Authorization': 'Bearer #{oidcUser.accessToken}',
            'X-SP-UserId': '#{proxy.userId}',
            'X-SP-UserGroups': '#{proxy.userGroups}',
            'X-SP-Username': '#{oidcUser.preferredUsername}',
            'X-SP-Email': '#{oidcUser.email}'
        }
    }
    
    # Add pre-initialization settings
    if 'seats' in app_config:
        app_spec['container-pre-initialization-seats'] = app_config['seats']
    
    return app_spec
