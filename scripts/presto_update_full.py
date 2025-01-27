#!/usr/bin/env python3
import subprocess
import threading
import sys
import time
import os
from datetime import datetime
import psutil
from tqdm import tqdm

# --- Configuration ---
SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/your/webhook/url"  # Replace with your webhook URL
LOG_DIR = f"/home/{os.environ['USER']}/presto/logs/"
RETRY_LIMIT = 3
SPINNER_INTERVAL = 0.2
BAR_LENGTH = 40

# Create logs directory if it doesn't exist
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, f"docker_update_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Spinner and progress messages
spin_chars = ["⏳", "📦", "🚚", "⬇️ ", "🐋"]
spinner_messages = [
    "Pulling Docker images...",
    "Starting containers...",
    "Building images...",
    "Restarting services...",
    "Pruning container images..."
]

# Spinner control variables
stop_spinner = False
spinner_index = 0

# --- Utility Functions ---
def log_and_print(message):
    """Log messages to both console and log file."""
    print(message)
    with open(log_file, "a") as log:
        log.write(message + "\n")

def colorize(message, color_code):
    return f"\033[{color_code}m{message}\033[0m"

# --- Spinner Function ---
def spinner():
    global spinner_index
    while not stop_spinner:
        message = spinner_messages[spinner_index % len(spinner_messages)]
        sys.stdout.write(f"\r{spin_chars[spinner_index]} {message}")
        sys.stdout.flush()
        time.sleep(SPINNER_INTERVAL)

# --- Progress Bar ---
def progress_bar(current, total):
    progress = int(BAR_LENGTH * current / total)
    bar = "█" * progress + "-" * (BAR_LENGTH - progress)
    sys.stdout.write(f"\r|\033[94m{bar}| {current}/{total} steps completed")
    sys.stdout.flush()

# --- Countdown Timer ---
def countdown(seconds):
    """
    Displays a countdown timer and allows user interruption.

    Args:
        seconds: Number of seconds to count down.

    Returns:
        True if countdown completes without interruption, False otherwise.
    """
    for i in tqdm(range(seconds, 0, -1), desc="Countdown", unit="s", bar_format='{l_bar}{bar}| {n_fmt}/{total_fmt}'):
        time.sleep(1)
        try:
            # Check for user input in a non-blocking way
            if select.select([sys.stdin], [], [], 0)[0]: 
                sys.stdin.readline() 
                print("\n\n[PRESTO] Operation cancelled by user.")
                return False
        except KeyboardInterrupt:
            print("\n\n[PRESTO] Operation cancelled by user.")
            return False
    return True

# --- Run Command with Retries ---
def run_command_with_retries(cmd, capture_output=False):
    for attempt in range(1, RETRY_LIMIT + 1):
        log_and_print(f"\n[PRESTO] Attempt {attempt}/{RETRY_LIMIT}: {cmd}")
        process = subprocess.Popen(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True
        )

        start_time = time.time()
        captured_output = [] if capture_output else None
        while True:
            output = process.stdout.readline()
            if not output and process.poll() is not None:
                break
            if output.strip():
                log_and_print(output.strip())
                if capture_output:
                    captured_output.append(output.strip())

        process.wait()
        end_time = time.time()

        if process.returncode == 0:
            log_and_print(f"{colorize('Command succeeded', '32')} (Duration: {end_time - start_time:.2f}s)")
            if capture_output:
                return True, "\n".join(captured_output)
            return True

        log_and_print(f"{colorize('Command failed. Retrying...', '33')}")

    log_and_print(f"{colorize('Command failed after all retries', '31')}")
    return False, None if capture_output else False

# --- Docker Commands ---
docker_commands = [
    "docker compose down",
    "docker compose pull",
    "docker compose build",
    "docker compose up -d --remove-orphans",
    "docker image prune -a -f"
]

# --- Change Directory and Check User ---
try:
    current_user = os.environ['USER']
    log_and_print(f"Current user: {current_user}")
    os.chdir(f"/home/{current_user}/presto/scripts/")
except KeyError:
    log_and_print("Error: USER environment variable not set.")
    sys.exit(1)
except FileNotFoundError:
    log_and_print("Error: Directory '/home/{current_user}/presto/scripts/' does not exist.")
    sys.exit(1)

total_tasks = len(docker_commands)
completed_tasks = 0
prune_output = ""
resource_summary = []

# --- Main Execution ---
try:
    # Start processing commands
    for i, cmd in enumerate(docker_commands, start=1):
        spinner_index = i - 1
        progress_bar(i - 1, total_tasks)  # Update progress bar for the previous step

        if "docker image prune" in cmd:
            success, output = run_command_with_retries(cmd, capture_output=True)
            if success:
                prune_output = output
        else:
            if not run_command_with_retries(cmd):
                # Uncomment below to send notifications
                # send_slack_notification("Error", f"Command failed: {cmd}")
                sys.exit(1)

        # Record system stats after each command
        cpu = psutil.cpu_percent()
        mem = psutil.virtual_memory().percent
        disk = psutil.disk_usage('/').percent
        resource_summary.append(f"Task {i}: CPU {cpu}% | Memory {mem}% | Disk {disk}%")

        completed_tasks += 1
        progress_bar(completed_tasks, total_tasks)  # Update progress bar for the current step

    log_and_print("\n[PRESTO] All Docker Tasks completed successfully!")
    # Uncomment below to send notifications
    # send_slack_notification("Success", "All commands completed successfully!")

finally:
    pass

# --- Final Log and Cleanup ---
log_and_print(f"\n[PRESTO] Logs saved to: {log_file}")

print("\n[PRESTO] Summary:")
if prune_output:
    print(colorize(f"✅ {prune_output}", '33'))
else:
    print(colorize("✅ Total reclaimed space: 0B", '33'))

#print("\n[PRESTO] System Resource Summary:")
#for summary in resource_summary:
#    print(summary)

print("\n[PRESTO] Updates finished.")
