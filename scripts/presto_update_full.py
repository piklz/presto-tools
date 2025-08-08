#!/usr/bin/env python3

#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______        
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____       
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__      
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_     
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_    
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__   
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____  
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/_____ 
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______

##################################################################################################
#-------------------------------------------------------------------------------------------------
# presto_update_full.py - Automatically update Docker containers and prune images
#--------------------------------------------------------------------------------------------------
# Author        : piklz
# GitHub        : https://github.com/piklz/presto-tools
# Web           : https://github.com/piklz/presto-tools
# Version       : v1.0.6
# Changes since : v1.0.6, 2025-08-08 (Added detailed change reporting for Docker Compose updates)
# Desc          : Checks for Docker Compose changes, updates containers using a task sequence, and prunes images
##################################################################################################

import os
import subprocess
import argparse
import datetime
import sys
import shutil
from pathlib import Path

# ANSI color codes for terminal output
COLOR_GREEN = "\033[92m"
COLOR_RED = "\033[91m"
COLOR_YELLOW = "\033[93m"
COLOR_RESET = "\033[0m"

# Global variables
USER_HOME = os.path.expanduser("~")
INSTALL_DIR = os.path.join(USER_HOME, "presto-tools")
PRESTO_DIR = os.path.join(USER_HOME, "presto")
LOG_DIR = os.path.join(USER_HOME, ".local/state/presto")
LOG_FILE = None
DOCKER_COMPOSE_FILE = os.path.join(PRESTO_DIR, "docker-compose.yml")

# Task list for container operations
TASKS = [
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} down", "message": "Stopping containers... ⏹️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} pull", "message": "Pulling Docker images... ⬇️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} build", "message": "Building Docker images... 🛠️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} up -d --remove-orphans", "message": "Starting containers... 🟢"},
    {"command": "docker image prune -a -f", "message": "Pruning unused images... 🗑️"}
]

def set_log_file_path():
    """Determine the correct log file path based on permissions."""
    global LOG_FILE
    if os.geteuid() == 0:
        LOG_FILE = "/var/log/presto_update_full.log"
    else:
        LOG_FILE = os.path.join(LOG_DIR, "presto_update_full.log")
        os.makedirs(LOG_DIR, exist_ok=True)
        if not os.access(LOG_DIR, os.W_OK):
            print(f"{COLOR_RED}Error: Cannot write to log directory '{LOG_DIR}'.{COLOR_RESET}", file=sys.stderr)
            sys.exit(1)
    
    try:
        Path(LOG_FILE).touch()
        if not os.access(LOG_FILE, os.W_OK):
            print(f"{COLOR_RED}Error: Cannot write to log file '{LOG_FILE}'.{COLOR_RESET}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"{COLOR_RED}Error: Could not create or write to log file '{LOG_FILE}': {e}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)

def log_message(message, level="INFO"):
    """Log a message to the log file with a timestamp."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {level}: {message}"
    try:
        with open(LOG_FILE, "a") as f:
            f.write(log_entry + "\n")
    except Exception as e:
        print(f"{COLOR_RED}Error: Failed to write to log file '{LOG_FILE}': {e}{COLOR_RESET}", file=sys.stderr)

def run_command(command, check=True, stream_output=False):
    """Run a shell command, optionally streaming output to terminal."""
    log_message(f"Executing command: {command}")
    try:
        if stream_output:
            process = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            stdout_lines = []
            stderr_lines = []
            
            # Stream output in real-time
            while True:
                stdout_line = process.stdout.readline()
                stderr_line = process.stderr.readline()
                
                if stdout_line:
                    print(stdout_line, end="")
                    stdout_lines.append(stdout_line)
                if stderr_line:
                    print(stderr_line, end="", file=sys.stderr)
                    stderr_lines.append(stderr_line)
                
                if process.poll() is not None and not stdout_line and not stderr_line:
                    break
            
            # Wait for process to complete with timeout
            process.wait(timeout=300)
            
            if check and process.returncode != 0:
                error_msg = f"Command '{command}' failed with exit code {process.returncode}: {''.join(stderr_lines)}"
                log_message(error_msg, "ERROR")
                print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
                sys.exit(1)
            
            return "".join(stdout_lines).strip(), "".join(stderr_lines).strip()
        
        else:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=300
            )
            if check and result.returncode != 0:
                error_msg = f"Command '{command}' failed with exit code {result.returncode}: {result.stderr}"
                log_message(error_msg, "ERROR")
                print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
                sys.exit(1)
            return result.stdout.strip(), result.stderr.strip()
    
    except subprocess.TimeoutExpired:
        error_msg = f"Command '{command}' timed out after 300 seconds"
        log_message(error_msg, "ERROR")
        print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        error_msg = f"Error executing command '{command}': {e}"
        log_message(error_msg, "ERROR")
        print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)

def check_docker_compose_changes():
    """Check for changes in Docker Compose configuration."""
    log_message("Checking for Docker Compose changes")
    print(f"{COLOR_YELLOW}Checking for Docker Compose changes...{COLOR_RESET}")
    if not os.path.isfile(DOCKER_COMPOSE_FILE):
        error_msg = f"Docker Compose file '{DOCKER_COMPOSE_FILE}' not found"
        log_message(error_msg, "ERROR")
        print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)
    try:
        stdout, stderr = run_command(f"docker compose -f {DOCKER_COMPOSE_FILE} config --images")
        log_message("Docker Compose config checked successfully")
        # Split output into list of images, stripping whitespace
        images = [line.strip() for line in stdout.splitlines() if line.strip()]
        return images
    except SystemExit:
        log_message("Failed to check Docker Compose config", "ERROR")
        raise

def compare_images(before, after):
    """Compare two lists of images and return differences."""
    changes = []
    before_set = set(before)
    after_set = set(after)
    
    # Images added or updated
    for image in after_set:
        if image not in before_set:
            changes.append(f"Image {image} added or updated")
    
    # Images removed
    for image in before_set:
        if image not in after_set:
            changes.append(f"Image {image} removed")
    
    return changes

def run_container_tasks(interactive=False):
    """Run the sequence of container tasks, with optional interactive pruning."""
    log_message("Starting container tasks")
    print(f"{COLOR_YELLOW}Updating Docker containers...{COLOR_RESET}")
    
    for task in TASKS:
        # Handle pruning task interactively if requested
        if task["command"].startswith("docker image prune") and interactive:
            response = input(f"{COLOR_YELLOW}Do you want to prune unused Docker images? (y/n): {COLOR_RESET}").strip().lower()
            if response != 'y':
                log_message("User skipped Docker image pruning")
                print(f"{COLOR_YELLOW}Skipping Docker image pruning.{COLOR_RESET}")
                continue
        
        log_message(f"Running task: {task['message']}")
        print(f"{COLOR_YELLOW}{task['message']}{COLOR_RESET}")
        
        # Stream output only for pruning task
        stream_output = task["command"].startswith("docker image prune")
        try:
            stdout, stderr = run_command(task["command"], stream_output=stream_output)
            log_message(f"Task completed: {task['message']}")
            print(f"{COLOR_GREEN}Task completed successfully.{COLOR_RESET}")
            
            # Check for no pruning needed
            if task["command"].startswith("docker image prune"):
                if "Total reclaimed space: 0B" in stdout or not stdout.strip():
                    log_message("No images pruned, system already clean")
                    print(f"{COLOR_GREEN}Pruning finished, didn’t need to, already clean! ✨{COLOR_RESET}")
        
        except SystemExit:
            log_message(f"Task failed: {task['message']}", "ERROR")
            raise

def main():
    """Main function to check and update Docker containers."""
    parser = argparse.ArgumentParser(description="Update Docker containers and prune images")
    parser.add_argument("--interactive", action="store_true", help="Run image pruning interactively")
    args = parser.parse_args()

    # Set up logging
    set_log_file_path()
    log_message("Starting presto_update_full.py")

    # Check if Docker is available
    if not shutil.which("docker"):
        error_msg = "Docker is not installed or not in PATH"
        log_message(error_msg, "ERROR")
        print(f"{COLOR_RED}{error_msg}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)

    # Check Docker Compose changes
    config_before = check_docker_compose_changes()
    
    # Prompt user to update
    response = input(f"{COLOR_YELLOW}Do you want to update Docker containers? (y/n): {COLOR_RESET}").strip().lower()
    if response == 'y':
        run_container_tasks(args.interactive)
        config_after = check_docker_compose_changes()
        if config_before != config_after:
            changes = compare_images(config_before, config_after)
            change_message = "Docker Compose configuration changed after update:\n  " + "\n  ".join(changes)
            log_message(change_message)
            print(f"{COLOR_YELLOW}{change_message}{COLOR_RESET}")
        else:
            log_message("No changes in Docker Compose configuration after update")
            print(f"{COLOR_YELLOW}No changes in Docker Compose configuration after update.{COLOR_RESET}")
    else:
        log_message("User skipped Docker container update")
        print(f"{COLOR_YELLOW}Skipping Docker container update.{COLOR_RESET}")

    log_message("presto_update_full.py completed")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_message("Script interrupted by user", "WARNING")
        print(f"{COLOR_RED}Script interrupted by user.{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        log_message(f"Unexpected error: {e}", "ERROR")
        print(f"{COLOR_RED}Unexpected error: {e}{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)