def merge_apps_into_proxy_config(appproxy_application_config, team_name):
    try:
        # ... existing code ...
        
        for app_spec in specs:
            # Enable pre-initialization for specific apps
            if app_spec.get('pre-initialize', False):
                # Set minimum seats
                min_seats = app_spec.get('minimum-seats-available', 2)
                app_spec['container-instances-min'] = min_seats
                
                # Configure container pooling
                app_spec['container-wait-time'] = 60000
                app_spec['container-pool-size'] = min_seats * 2
                
                # Set up authentication headers
                app_spec['container-env']['SHINYPROXY_AUTH_TYPE'] = 'header'
                app_spec['http-headers'] = {
                    'Authorization': 'Bearer #{oidcUser.accessToken}',
                    'X-SP-USERNAME': '#{proxy.userId}',
                    'X-SP-GROUPS': '#{proxy.userGroups}',
                    'X-SP-ATTRIBUTES': '#{proxy.userAttributes}'
                }
                
                # Configure sharing if specified
                if 'allowed-users' in app_spec or 'allowed-groups' in app_spec:
                    setup_user_sharing_config(
                        app_spec,
                        app_spec.get('allowed-users'),
                        app_spec.get('allowed-groups')
                    )
            
            # Add namespace for Redis isolation
            if 'container-env' not in app_spec:
                app_spec['container-env'] = {}
            app_spec['container-env']['REDIS_NAMESPACE'] = f"{team_name}:{app_spec['id']}"
            
        return appproxy_application_config
        
    except Exception as e:
        print(f"Error in merge_apps_into_proxy_config: {e}")
        raise
