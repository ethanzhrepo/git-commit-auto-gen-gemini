#!/bin/bash

# Gemini-Powered Auto-Commit Script
# This script uses the Gemini CLI to generate a commit message based on staged changes.

set -e # Exit on any error

# --- Prerequisites ---
# 1. Ensure the Gemini CLI is installed and accessible in your PATH.
#    You can check this by running: command -v gemini
# 2. Ensure you are authenticated with the Gemini API.

# Function to display help
show_help() {
    echo "Gemini-Powered Auto-Commit Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto-add    Automatically add all changes to staging (git add .)"
    echo "  --help        Show this help message"
    echo ""
    echo "Description:"
    echo "  This script uses the Gemini CLI to generate a commit message based on staged changes."
    echo "  By default, it only commits already staged changes. Use --auto-add to automatically"
    echo "  stage all changes before generating the commit message."
    echo ""
    echo "Examples:"
    echo "  $0                # Commit staged changes with generated message"
    echo "  $0 --auto-add     # Add all changes, then commit with generated message"
    echo "  $0 --help         # Show this help message"
}

# Parse command line arguments
AUTO_ADD=false
for arg in "$@"; do
    case $arg in
        --auto-add)
            AUTO_ADD=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "Use --help to see available options."
            exit 1
            ;;
    esac
done

# Check if gemini cli is installed
if ! command -v gemini > /dev/null 2>&1
then
    echo "❌ Error: The 'gemini' command-line tool is not installed or not in your PATH."
    echo "Please install it to use this script."
    echo "You can check this by running: command -v gemini"
    exit 1
fi

echo "🔎 Checking git status..."
git status --short

# Only add changes if --auto-add flag is provided
if [ "$AUTO_ADD" = true ]; then
    echo "➕ Adding all changes to staging..."
    git add .
fi

# Check if there are any changes to commit
if git diff --cached --quiet; then
    echo "ℹ️ No changes to commit. Exiting."
    exit 0
fi

echo "🤖 Generating commit message with Gemini..."

# Get the diff of staged changes. This will be the context for Gemini.
DIFF_CONTENT=$(git diff --cached)

# Create a clear prompt for the Gemini CLI.
# We instruct it to act as an expert and to only return the raw commit message.
PROMPT="As an expert programmer, analyze the following code changes from 'git diff --cached' and generate a concise, conventional commit message. The message should follow the Conventional Commits specification (e.g., 'feat:', 'fix:', 'docs:', 'refactor:').

Do not include any introduction, explanation, or markdown formatting. Only output the raw commit message text.

Here is the diff:
---
${DIFF_CONTENT}"

# Try to execute the gemini command, passing the prompt with -p, and check if it was successful
if ! COMMIT_MSG=$(gemini -p "$PROMPT"); then
    echo "❌ Error: The 'gemini' command failed to execute."
    echo "   Please check your API key, network connection, or run the command manually to see the full error."
    # Undo staging to make debugging easier
    echo "   Undoing 'git add' so you can inspect the changes."
    git reset
    exit 1
fi

# Safety check: if Gemini returns an empty message, abort.
if [ -z "$COMMIT_MSG" ]; then
    echo "❌ Gemini returned an empty message, but the command succeeded. Aborting commit."
    echo "   Undoing 'git add' so you can inspect the changes."
    git reset
    exit 1
fi

# Commit with the generated message
echo "📝 Committing changes with the following message:"
echo "----------------------------------------"
echo "$COMMIT_MSG"
echo "----------------------------------------"

git commit -m "$COMMIT_MSG"


echo "✅ Successfully committed changes."

