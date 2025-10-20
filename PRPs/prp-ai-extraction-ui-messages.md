# PRP: Improve AI Extraction UI Messages

## Task Overview
Add user-friendly messages to the AI extraction UI to inform users about the extraction process status. Messages should appear in the UI field just above the Title form field and display progress indicators like "Preparing image to send", "Sending image to Claude/OpenAI", etc.

## Context
- **Project**: Delcampe R Shiny application  
- **Module**: `mod_delcampe_export.R`
- **Previous Implementation**: Successfully implemented in October 2025 but needs restoration
- **Memory Reference**: `.serena/memories/ai_notification_implementation_20251009.md`

## Current State
The application has:
- AI extraction functionality working
- An `ai_status` UI output placeholder (`uiOutput(ns(paste0("ai_status_", idx)))`) 
- Extraction handlers that update the status
- Previous implementation that needs to be restored/improved

## Requirements

### 1. Message Display Location
- Messages must appear in the existing `ai_status` UI output
- Located just above the Title form field
- Uses the existing `uiOutput(ns(paste0("ai_status_", idx)))` placeholder

### 2. Message Types and Styling

#### Progress Messages (Blue box with spinner)
```r
# Style: background: #e3f2fd; border-left: 4px solid #2196f3
```
- "🚀 Initializing AI extraction..."
- "📁 Locating image file..."  
- "📊 Checking image size..."
- "🗜️ Compressing image (X.XMB → target 4MB)..." (if needed)
- "🤖 Analyzing with [Model Name]..."
- "📝 Parsing AI response..."

#### Success Message (Green box with checkmark)
```r
# Style: background: #e8f5e9; border-left: 4px solid #4caf50
```
- "✅ Success! Extraction completed in X.Xs"

#### Error Messages (Red box with exclamation)
```r
# Style: background: #ffebee; border-left: 4px solid #f44336
```
- "❌ Error: No image selected"
- "❌ Error: Could not locate image file"
- "❌ Authentication failed - Check API key"
- "❌ Rate limit exceeded - Try again later"

### 3. Implementation Approach

#### Key Principle: NO Asynchronous Functions
- **DO NOT** use `later::later()` for status updates
- **DO NOT** use `promises` or async patterns
- **DO NOT** implement notifications (showNotification)
- Status updates must be **synchronous** and immediate
- The UI placeholder approach is sufficient

#### Status Update Pattern
```r
# Update status immediately when action happens
output[[paste0("ai_status_", i)]] <- renderUI({
  div(
    style = "padding: 12px; background: #e3f2fd; border-left: 4px solid #2196f3; margin-top: 10px;",
    icon("spinner", class = "fa-spin", style = "color: #1976d2;"),
    " Your message here..."
  )
})
```

### 4. Message Flow Sequence

1. **User clicks "Extract with AI"**
   - Show: "🚀 Initializing AI extraction..."

2. **Path Resolution**
   - Show: "📁 Locating image file..."
   - If error: "❌ Error: Could not locate image file"

3. **Configuration Check**  
   - Show: "🔧 Loading configuration..."
   - If no API key: "❌ Please configure API key in Settings"

4. **Image Size Check** (optional)
   - Show: "📊 Checking image size..."
   - If > 4MB: "🗜️ Compressing image..."

5. **API Call**
   - Show: "🤖 Analyzing with [Claude/GPT-4]..."

6. **Response Parsing**
   - Show: "📝 Parsing AI response..."

7. **Success/Error**
   - Success: "✅ Extraction complete! Recommended price: €X.XX"
   - Error: "❌ Error: [specific error message]"

### 5. Code Location

The implementation should modify the AI extraction handler in `mod_delcampe_export.R`:
- Look for: `observeEvent(input[[paste0("extract_ai_", i)]]`
- This is where status updates should be added
- Each major step should update the `ai_status` output

### 6. Testing Requirements

Test scenarios:
1. **Normal extraction** - All progress messages display correctly
2. **Missing API key** - Shows configuration error
3. **File not found** - Shows file location error  
4. **API error** - Shows specific error message
5. **Success** - Shows green success with price

### 7. Important Constraints

1. **No Breaking Changes**
   - Must preserve all existing functionality
   - Form auto-fill must continue working
   - Database saving must continue working

2. **No Async Patterns**
   - Avoid `later::later()` 
   - Avoid promises
   - Keep it simple and synchronous

3. **Maintain Existing Flow**
   - Don't reorganize the extraction logic
   - Just add status updates at key points
   - Use existing error handling

### 8. Reference Implementation

From the memory file, the successful pattern was:
```r
# At each step, update the status output
output[[paste0("ai_status_", i)]] <- renderUI({
  div(
    style = "padding: 12px; background: COLOR; border-left: 4px solid BORDER_COLOR; margin-top: 10px;",
    icon(ICON_NAME, class = OPTIONAL_CLASS, style = "color: ICON_COLOR;"),
    " Message text here"
  )
})
```

Colors:
- Blue (progress): `#e3f2fd` background, `#2196f3` border
- Green (success): `#e8f5e9` background, `#4caf50` border  
- Red (error): `#ffebee` background, `#f44336` border

Icons:
- Progress: `icon("spinner", class = "fa-spin")`
- Success: `icon("check-circle")`
- Error: `icon("exclamation-circle")`

## Success Criteria

1. ✅ User sees clear progress messages during extraction
2. ✅ Messages appear in the correct location (above Title field)
3. ✅ Color-coded messages (blue/green/red) 
4. ✅ Spinner animation during processing
5. ✅ Specific error messages that help users
6. ✅ No breaking changes to existing functionality
7. ✅ No async/promise patterns used

## Files to Modify

- `R/mod_delcampe_export.R` - Add status updates to extraction handler

## Delivery

After implementation:
1. Test all scenarios listed above
2. Verify form auto-fill still works
3. Verify database saving still works
4. Create backup of original file before changes
5. Document any issues or limitations found

## Notes

- Previous successful implementation exists in memory
- Focus on simple, synchronous status updates
- The UI placeholder already exists - just need to populate it
- Don't add complexity with async patterns or notifications
