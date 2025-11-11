#!/usr/bin/env python3

"""
validate-stack-files.py - Docker Stack File Validator

This script validates Docker Stack YAML files for Docker Swarm compatibility.
It checks for common issues that prevent successful swarm deployment:
- YAML syntax errors
- Swarm-incompatible features (build contexts, depends_on, etc.)
- Missing required sections (version, services)
- Deployment configuration best practices

Usage:
    python3 scripts/validate-stack-files.py

Exit codes:
    0 - All stack files are valid
    1 - One or more stack files have errors

Files checked:
    - docker-stack.yml (main swarm stack)
    - docker-stack-internal.yml (internal services)
    - docker-stack-nfs.yml.template (NFS volume template)
"""

import yaml
import sys

def validate_stack_file(filename):
    """Validate a Docker Stack file for Swarm compatibility"""
    print(f"Validating {filename}...")
    
    try:
        with open(filename, 'r') as f:
            data = yaml.safe_load(f)
    except Exception as e:
        print(f"❌ YAML syntax error in {filename}: {e}")
        return False
    
    errors = []
    warnings = []
    
    # Check version
    if 'version' not in data:
        errors.append("Missing version field")
    elif not data['version'].startswith('3.'):
        warnings.append(f"Version {data['version']} may not be compatible with Docker Swarm")
    
    # Check services (optional for template files)
    if 'services' not in data:
        if filename.endswith('.template'):
            print(f"ℹ️  {filename} is a template file with no services section")
        else:
            errors.append("No services defined")
            return False
    else:
        services = data['services']
        
        for service_name, service_config in services.items():
            service_errors = []
            service_warnings = []
            
            # Check for Swarm-incompatible features
            if 'build' in service_config:
                service_errors.append("'build' is not supported in Swarm mode")
            
            if 'depends_on' in service_config:
                service_warnings.append("'depends_on' is ignored in Swarm mode")
            
            if 'container_name' in service_config:
                service_warnings.append("'container_name' is ignored in Swarm mode")
            
            if 'links' in service_config:
                service_warnings.append("'links' is deprecated and ignored in Swarm mode")
            
            # Check deploy section
            if 'deploy' not in service_config:
                service_warnings.append("No deploy section - will use defaults")
            else:
                deploy = service_config['deploy']
                if 'restart_policy' not in deploy:
                    service_warnings.append("No restart_policy specified")
            
            # Report service-specific issues
            if service_errors:
                errors.extend([f"Service '{service_name}': {err}" for err in service_errors])
            if service_warnings:
                warnings.extend([f"Service '{service_name}': {warn}" for warn in service_warnings])
    
    # Report results
    if errors:
        print(f"❌ {filename} has errors:")
        for error in errors:
            print(f"   - {error}")
        return False
    
    if warnings:
        print(f"⚠️  {filename} has warnings:")
        for warning in warnings:
            print(f"   - {warning}")
    
    print(f"✅ {filename} is valid for Docker Swarm")
    return True

if __name__ == "__main__":
    files_to_check = [
        "docker-stack.yml",
        "docker-stack-internal.yml", 
        "docker-stack-nfs.yml.template"
    ]
    
    all_valid = True
    for filename in files_to_check:
        try:
            valid = validate_stack_file(filename)
            all_valid = all_valid and valid
            print()
        except FileNotFoundError:
            print(f"❌ {filename} not found")
            all_valid = False
        except Exception as e:
            print(f"❌ Error validating {filename}: {e}")
            import traceback
            traceback.print_exc()
            all_valid = False
    
    if all_valid:
        print("🎉 All stack files are valid for Docker Swarm!")
        sys.exit(0)
    else:
        print("💥 Some stack files have issues")
        sys.exit(1)