import subprocess
import json
import sys
import re

def run_tests():
    print("Running Flutter tests...")

    # Run the flutter test command with --machine flag to get JSON output
    # We allow stderr to pass through or capture it to suppress build logs
    process = subprocess.Popen(
        'flutter test test/widget_test.dart --machine',
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    # Read stdout line by line
    failed = False
    error_message = None
    stack_trace = None

    captured_print_error = ""

    while True:
        line = process.stdout.readline()
        if not line and process.poll() is not None:
            break
        if line:
            try:
                cleaned_line = line.strip()
                if not cleaned_line:
                    continue

                if cleaned_line.startswith('[') and cleaned_line.endswith(']'):
                    events = json.loads(cleaned_line)
                else:
                    events = [json.loads(cleaned_line)]

                for event in events:
                    if not isinstance(event, dict):
                        continue

                    if event.get('type') == 'testDone':
                        if event.get('result') == 'failed' or event.get('result') == 'error':
                            failed = True

                    if event.get('type') == 'error':
                        if not error_message:
                            error_message = event.get('error')
                            stack_trace = event.get('stackTrace')

                    # Capture specific print errors (where assertions usually live in flutter test)
                    if event.get('type') == 'print':
                        msg = event.get('message', '')
                        if "TestFailure" in msg or "EXCEPTION" in msg:
                            captured_print_error += msg + "\n"

            except json.JSONDecodeError:
                pass

    process.wait()

    if failed or process.returncode != 0:
        print(f"[STATUS]: FAIL")

        final_error = captured_print_error if captured_print_error else error_message
        if not final_error:
            stderr_output = process.stderr.read()
            final_error = stderr_output if stderr_output else "Unknown error occurred."

        print(f"[ERROR]: {str(final_error).strip()}")

        if stack_trace and not captured_print_error:
            print(f"[TRACE]: {str(stack_trace).strip()}")

    else:
        print(f"[STATUS]: SUCCESS")

if __name__ == "__main__":
    run_tests()
