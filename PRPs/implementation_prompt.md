# Implementation Request for AI Extraction UI Fix

## Project Context
I'm working on a Shiny R application called Delcampe that processes postal cards. The application:
- Uses the Golem framework for structure
- Has a 3-layer SQLite database architecture
- Uses reticulate for Python integration
- Implements deduplication based on MD5 hashes

## Current Issue
The AI extraction UI fields don't populate with existing data when processing duplicate combined images.

## Important Files
- `R/mod_ai_extraction.R` - AI extraction module
- `R/mod_delcampe_ui.R` - UI module with form fields
- `R/app_server.R` - Main server with combined image creation
- `R/tracking_database.R` - Database functions

## Task
Please read and implement the PRP in: PRPs/fix_ai_extraction_ui_task.md

Focus on:
1. Finding where the UI form fields are created
2. Adding observers to populate fields when `rv$existing_card_data` exists
3. Ensuring the correct file paths are used for hash calculation (not web URLs)

## Expected Implementation
- Add `updateTextInput()`, `updateTextAreaInput()`, etc. calls
- Trigger these updates when existing data is detected
- Verify combined image paths are handled correctly

Please provide:
1. Exact code changes needed
2. File locations and line numbers if possible
3. Any debugging steps to verify the fix

## Use Serena Tools
Please use `serena:find_symbol` and `serena:replace_symbol_body` for code modifications.