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

#-------------------------------------------------------------------------------------------------
# presto_update_full.py - Automatically update Docker containers and prune images
# Version: 1.0.8
# Author: piklz
# GitHub: https://github.com/piklz/presto-tools
# Web: https://github.com/piklz/presto-tools
# Description:
#   Checks for Docker Compose changes, updates containers using a task sequence, and prunes images.
#   Customizable via a configuration file. Logs to systemd-journald, with rotation managed by journald.
#
# Changelog:
#   Version 1.0.8 (2025-08-21):
#     - Removed unused file-based logging variables (LOG_DIR, LOG_FILE) and set_log_file_path function.
#   Version 1.0.7 (2025-08-21):
#     - Replaced file-based logging with systemd-cat, added -d flag for debug logging, added version and journal tip to --help.
#   Version 1.0.6 (2025-08-08):
#     - Added detailed change reporting for Docker Compose updates.
#   Version 1.0.5 (2025-07-15):
#     - Improved error handling for Docker Compose configuration checks.
#
# Usage:
#   Run the script with sudo: `sudo python3 presto_update_full.py [OPTIONS]`
#   - Options include --help, --interactive, and -d for debug logging.
#   - Customize settings by editing `$HOME/presto-tools/scripts/presto_config.local`.
#     (Copy presto_config.defaults to presto_config.local and edit.)
#   - Logs can be viewed with: `journalctl -t presto_update_full -n 10`.
#   - Ensure dependencies (docker, docker compose) are installed for full functionality.
#-------------------------------------------------------------------------------------------------

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
DOCKER_COMPOSE_FILE = os.path.join(PRESTO_DIR, "docker-compose.yml")
DEBUG_ENABLED = False

# Task list for container operations
TASKS = [
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} down", "message": "Stopping containers... ⏹️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} pull", "message": "Pulling Docker images... ⬇️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} build", "message": "Building Docker images... 🛠️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} up -d --remove-orphans", "message": "Starting containers... 🟢"},
    {"command": "docker image prune -a -f", "message": "Pruning unused images... 🗑️"}
]

def log_message(message, level="INFO", console_message=None, exit_on_error=True):
    """Log a message to systemd-journald with a timestamp."""
    if level == "DEBUG" and not DEBUG_ENABLED:
        return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    journal_message = f"[{timestamp}] [presto_update_full] [{level}] {message}"

    # Map log level to systemd priority
    priority_map = {
        "DEBUG": "debug",
        "INFO": "info",
        "WARNING": "warning",
        "ERROR": "err"
    }
    priority = priority_map.get(level.upper(), "info")

    # Log to journald using systemd-cat
    try:
        subprocess.run(
            ["systemd-cat", "-t", "presto_update_full", "-p", priority],
            input=journal_message,
            text=True,
            check=True
        )
    except subprocess.SubprocessError as e:
        print(f"{COLOR_RED}[presto_update_full] [ERROR] Failed to log to journald: {e}{COLOR_RESET}", file=sys.stderr)

    # Print to console only for specific ERROR messages
    console_message = console_message or message
    if level == "ERROR" and any(p in console_message.lower() for p in ["not found", "unavailable", "requires root privileges"]):
        print(f"{COLOR_YELLOW}{console_message}{COLOR_RESET}", file=sys.stderr)

    # Exit on error if specified
    if level == "ERROR" and exit_on_error:
        sys.exit(1)

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
    parser = argparse.ArgumentParser(
        description=f"presto_update_full.py (v1.0.8)\n\nUpdate Docker containers and prune images",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="To see info or warning logs type:\n     journalctl -t presto_update_full -n 10"
    )
    parser.add_argument("--interactive", action="store_true", help="Run image pruning interactively")
    parser.add_argument("-d", action="store_true", help="Enable debug logging")
    args = parser.parse_args()

    # Set debug flag
    global DEBUG_ENABLED
    DEBUG_ENABLED = args.d

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