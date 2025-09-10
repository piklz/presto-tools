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
# presto_compose_refresh.py - Automatically update Docker containers and prune images
# Version: 1.0.19
# Author: piklz
# GitHub: https://github.com/piklz/presto-tools
# Web: https://github.com/piklz/presto-tools
# Description:
#   Checks for Docker Compose changes, updates containers using a task sequence, and prunes images.
#   Customizable via a configuration file. Logs to systemd-journald, with rotation managed by journald.
#
# Changelog:
#   Version 1.0.19 (2025-09-10):
#     - Implemented logic to only ask for user confirmation if the --interactive flag is used.
#   Version 1.0.18 (2025-09-09):
#     - Re-implemented a summary of space saved after 'docker image prune'.
#   Version 1.0.17 (2025-09-09):
#    - Fixed an issue where the script would not log to journald if 'docker compose pull' failed.       
# Usage:
#   Run the script with sudo: `sudo python3 presto_compose_refresh.py [OPTIONS]`
#   - Options include --help, --interactive, and -d for debug logging.
#   - Customize settings by editing `$HOME/presto-tools/scripts/presto_config.local`.
#     (Copy presto_config.defaults to presto_config.local and edit.)
#   - Logs can be viewed with: `journalctl -t presto_compose_refresh -n 10`.
#   - Ensure dependencies (docker, docker compose) are installed for full functionality.
#-------------------------------------------------------------------------------------------------

import os
import subprocess
import argparse
import datetime
import sys
import shutil
import time
import threading
import itertools
import re

# Color variables (aligned with presto_bashwelcome.sh)
no_col="\033[0m"
white="\033[37m"
cyan="\033[36m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
magenta="\033[35m"
magenta_dim="\033[35;2m"
grey="\033[1;30m"
grey_dim="\033[2;30m"
lgt_red="\033[1;31m"
lgt_green="\033[1;32m"
lgt_green_inv="\033[7;32m"
TICK="\033[1;32m✓\033[0m"
CROSS="\033[1;31m✗\033[0m"
INFO="\033[33m[i]\033[0m"
DONE="\033[1;32m done!\033[0m"

# Global variables
USER_HOME = os.path.expanduser("~")
INSTALL_DIR = os.path.join(USER_HOME, "presto-tools")
PRESTO_DIR = os.path.join(USER_HOME, "presto")
DOCKER_COMPOSE_FILE = os.path.join(PRESTO_DIR, "docker-compose.yml")
DEBUG_ENABLED = False
spinner_message = ""
spinner_thread = None

# Task list for container operations
TASKS = [
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} down", "message": "Stopping containers... ⏹️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} pull", "message": "Pulling Docker images... ⬇️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} build", "message": "Building Docker images... 🛠️"},
    {"command": f"docker compose -f {DOCKER_COMPOSE_FILE} up -d --remove-orphans", "message": "Starting containers... 🟢"},
    {"command": "docker image prune -a -f", "message": "Pruning unused images... 🗑️"}
]

def update_spinner_message(new_message):
    """Update the message displayed by the spinner."""
    global spinner_message
    spinner_message = new_message

def spinner():
    """Display a spinner animation for a task."""
    spinner_chars = itertools.cycle(['-', '/', '|', '\\'])
    while spinner.running:
        print(f"\r{yellow}{spinner_message} {next(spinner_chars)}{no_col}", end="", flush=True)
        time.sleep(0.1)
    
    # After the loop, clear the last spinner character
    print(f"\r{yellow}{spinner_message} {TICK}{DONE}{no_col}")

def log_message(message, level="INFO", console_message=None, exit_on_error=True):
    """Log a message to systemd-journald with a timestamp."""
    if level == "DEBUG" and not DEBUG_ENABLED:
        return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    journal_message = f"[{timestamp}] [presto_compose_refresh] [{level}] {message}"

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
            ["systemd-cat", "-t", "presto_compose_refresh", "-p", priority],
            input=journal_message,
            text=True,
            check=True
        )
    except subprocess.SubprocessError as e:
        print(f"{red}[presto_compose_refresh] [ERROR] Failed to log to journald: {e}{no_col}", file=sys.stderr)

    # Print to console only for specific ERROR messages
    console_message = console_message or message
    if level == "ERROR" and any(p in console_message.lower() for p in ["not found", "unavailable", "requires root privileges"]):
        print(f"{yellow}{console_message}{no_col}", file=sys.stderr)

    # Exit on error if specified
    if level == "ERROR" and exit_on_error:
        sys.exit(1)

def run_command(command, check=True, message=None):
    """Run a shell command, showing a spinner or streaming output as appropriate."""
    global spinner_message
    global spinner_thread
    
    log_message(f"Executing command: {command}")
    
    # Handle docker compose pull and docker image prune to show native output
    if "pull" in command or "prune" in command:
        print(f"{yellow}{message}{no_col}")
        
        result = subprocess.run(
            command,
            shell=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            check=False
        )
        
        stdout_output = result.stdout.strip()
        print(stdout_output)

        if "prune" in command:
            reclaimed_space = re.search(r"Total reclaimed space:\s+(.*)", stdout_output)
            if reclaimed_space and reclaimed_space.group(1).strip() != "0B":
                space_saved = reclaimed_space.group(1).strip()
                print(f"{green}{TICK} Pruning completed! Reclaimed {space_saved}.{no_col}")
            else:
                print(f"{green}{TICK} Pruning completed, no space reclaimed.{no_col}")
        
        if check and result.returncode != 0:
            error_msg = f"Command '{command}' failed with exit code {result.returncode}"
            log_message(error_msg, "ERROR")
            print(f"\n{red}{CROSS} {error_msg}{no_col}", file=sys.stderr)
            sys.exit(1)
        
        return stdout_output, result.stderr
    
    # Handle other commands with a simple spinner
    else:
        print(f"{yellow}{message}{no_col}")
        
        update_spinner_message("Processing task...")
        spinner.running = True
        spinner_thread = threading.Thread(target=spinner)
        spinner_thread.start()
        
        try:
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
                print(f"{red}{CROSS} {error_msg}{no_col}", file=sys.stderr)
                sys.exit(1)
            
            return result.stdout.strip(), result.stderr.strip()
            
        except subprocess.TimeoutExpired:
            error_msg = f"Command '{command}' timed out after 300 seconds"
            log_message(error_msg, "ERROR")
            print(f"{red}{CROSS} {error_msg}{no_col}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            error_msg = f"Error executing command '{command}': {e}"
            log_message(error_msg, "ERROR")
            print(f"{red}{CROSS} Unexpected error: {e}{no_col}", file=sys.stderr)
            sys.exit(1)
        finally:
            spinner.running = False
            spinner_thread.join()

def check_docker_compose_changes():
    """Check for changes in Docker Compose configuration."""
    log_message("Checking for Docker Compose changes")
    print(f"{yellow}{INFO} Checking for Docker Compose changes...{no_col}")
    if not os.path.isfile(DOCKER_COMPOSE_FILE):
        error_msg = f"Docker Compose file '{DOCKER_COMPOSE_FILE}' not found"
        log_message(error_msg, "ERROR")
        print(f"{red}{CROSS} {error_msg}{no_col}", file=sys.stderr)
        sys.exit(1)
    try:
        stdout, stderr = run_command(f"docker compose -f {DOCKER_COMPOSE_FILE} config --images", message="Checking config...")
        log_message("Docker Compose config checked successfully")
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
    
    for image in after_set:
        if image not in before_set:
            changes.append(f"Image {image} added or updated")
    
    for image in before_set:
        if image not in after_set:
            changes.append(f"Image {image} removed")
    
    return changes

def run_container_tasks(interactive=False):
    """Run the sequence of container tasks, with optional interactive pruning."""
    log_message("Starting container tasks")
    print(f"{yellow}{INFO} Updating Docker containers...{no_col}")
    
    for task in TASKS:
        # Only prompt for pruning if in interactive mode
        if interactive and task["command"].startswith("docker image prune"):
            response = input(f"{yellow}{INFO} Do you want to prune unused Docker images? (y/n): {no_col}").strip().lower()
            if response != 'y':
                log_message("User skipped Docker image pruning")
                print(f"{yellow}{INFO} Skipping Docker image pruning.{no_col}")
                continue
        
        log_message(f"Running task: {task['message']}")
        
        try:
            stdout, stderr = run_command(task["command"], message=task['message'])
            log_message(f"Task completed: {task['message']}")
        
        except SystemExit:
            log_message(f"Task failed: {task['message']}", "ERROR")
            raise

def main():
    """Main function to check and update Docker containers."""
    parser = argparse.ArgumentParser(
        description=f"presto_compose_refresh.py (v1.0.19)\n\nUpdate Docker containers and prune images",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="To see info or warning logs type:\n     journalctl -t presto_compose_refresh -n 10"
    )
    parser.add_argument("--interactive", "-i", action="store_true", help="Run image pruning interactively")
    parser.add_argument("-d", action="store_true", help="Enable debug logging")
    args = parser.parse_args()

    global DEBUG_ENABLED
    DEBUG_ENABLED = args.d

    if not shutil.which("docker"):
        error_msg = "Docker is not installed or not in PATH"
        log_message(error_msg, "ERROR")
        print(f"{red}{CROSS} {error_msg}{no_col}", file=sys.stderr)
        sys.exit(1)

    config_before = check_docker_compose_changes()
    
    # Only ask for user confirmation if in interactive mode
    if args.interactive:
        response = input(f"{yellow}{INFO} Do you want to update Docker containers? (y/n): {no_col}").strip().lower()
        if response != 'y':
            log_message("User skipped Docker container update")
            print(f"{yellow}{INFO} Skipping Docker container update.{no_col}")
            sys.exit(0)
    
    run_container_tasks(args.interactive)
    config_after = check_docker_compose_changes()
    
    if config_before != config_after:
        changes = compare_images(config_before, config_after)
        change_message = "Docker Compose configuration changed after update:\n  " + "\n  ".join(changes)
        log_message(change_message)
        print(f"{yellow}{change_message}{no_col}")
    else:
        log_message("No changes in Docker Compose configuration after update")
        print(f"{yellow}{INFO} No changes in Docker Compose configuration after update.{no_col}")

    log_message("presto_compose_refresh.py completed")
    print(f"{green}{TICK} Update process completed!{no_col}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_message("Script interrupted by user", "WARNING")
        print(f"{red}{CROSS} Script interrupted by user.{no_col}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        log_message(f"Unexpected error: {e}", "ERROR")
        print(f"{red}{CROSS} Unexpected error: {e}{no_col}", file=sys.stderr)
        sys.exit(1)