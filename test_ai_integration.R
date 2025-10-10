# Test script to verify AI integration components
# Run this from the R console to check if all pieces are in place

cat("\n=== Testing AI Integration Components ===\n\n")

# 1. Check if ai_api_helpers.R functions exist
cat("1. Checking ai_api_helpers.R functions...\n")
source("R/ai_api_helpers.R")
cat("   ✓ get_llm_config:", exists("get_llm_config"), "\n")
cat("   ✓ call_claude_api:", exists("call_claude_api"), "\n")
cat("   ✓ call_openai_api:", exists("call_openai_api"), "\n")
cat("   ✓ build_enhanced_postal_card_prompt:", exists("build_enhanced_postal_card_prompt"), "\n")
cat("   ✓ parse_enhanced_ai_response:", exists("parse_enhanced_ai_response"), "\n")

# 2. Check LLM config file
cat("\n2. Checking LLM configuration...\n")
if (file.exists("data/llm_config.rds")) {
  config <- readRDS("data/llm_config.rds")
  cat("   ✓ Config file exists\n")
  cat("   ✓ Claude API key length:", nchar(config$claude_api_key %||% ""), "\n")
  cat("   ✓ OpenAI API key length:", nchar(config$openai_api_key %||% ""), "\n")
  cat("   ✓ Default model:", config$default_model, "\n")
} else {
  cat("   ✗ Config file NOT found at data/llm_config.rds\n")
}

# 3. Test enhanced prompt generation
cat("\n3. Testing enhanced prompt generation...\n")
prompt <- build_enhanced_postal_card_prompt("individual", 1)
cat("   ✓ Prompt generated, length:", nchar(prompt), "characters\n")
cat("   ✓ Contains PRICE:", grepl("PRICE:", prompt), "\n")
cat("   ✓ Contains CONDITION:", grepl("CONDITION:", prompt), "\n")
cat("   ✓ Contains TITLE:", grepl("TITLE:", prompt), "\n")
cat("   ✓ Contains DESCRIPTION:", grepl("DESCRIPTION:", prompt), "\n")

# 4. Test response parsing
cat("\n4. Testing response parsing...\n")
test_response <- "TITLE: Vintage Postcard - Paris Eiffel Tower, 1920s
DESCRIPTION: Beautiful view of the Eiffel Tower from the Seine River. The postcard shows excellent color preservation and minimal wear.
CONDITION: good
PRICE: 3.50"

parsed <- parse_enhanced_ai_response(test_response)
cat("   ✓ Title extracted:", !is.null(parsed$title) && parsed$title != "", "\n")
cat("   ✓ Description extracted:", !is.null(parsed$description) && parsed$description != "", "\n")
cat("   ✓ Condition extracted:", parsed$condition, "\n")
cat("   ✓ Price extracted: €", parsed$price, "\n")
cat("   ✓ Price is numeric:", is.numeric(parsed$price), "\n")

# 5. Check if later package is available
cat("\n5. Checking dependencies...\n")
cat("   ✓ later package:", require("later", quietly = TRUE), "\n")
cat("   ✓ httr2 package:", require("httr2", quietly = TRUE), "\n")
cat("   ✓ base64enc package:", require("base64enc", quietly = TRUE), "\n")

cat("\n=== All Checks Complete ===\n\n")
