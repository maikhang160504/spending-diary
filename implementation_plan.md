# Phase 7 & 8: Comprehensive Bug Fixes, AI Logic Enhancement, and UI Redesign

This plan consolidates the remaining requirements from `fix.md`, `fix_logic.md`, and `redesign_Mobile.md`. It addresses critical bugs, refines the AI interaction logic, and overhauls the Mobile UI to meet the "premium" standard requested.

## User Review Required

> [!IMPORTANT]
> **Priority Fixes Acknowledged**: We will prioritize the logout/crash bug ("văng tài khoản"), the UI text overwriting in chat, and the `REPORT_GENERAL` logic, as explicitly requested.
> 
> **Database / Backend**: Some logic changes (like Goal not linking to Wallets, new Budget Suggestion algorithms) will require backend updates and potentially database schema adjustments.
> 
> **AI Prompt Updates**: We will lift the restriction that `Action` intents must return empty responses and enhance prompts for dynamic, tone-aware responses.

## Open Questions

> [!WARNING]
> 1. **Image Storage Flow**: Currently, images are saved to Cloudflare *before* OCR analysis. If OCR fails, the image remains. Should we upload to a temporary bucket first or just delay upload until the user confirms the transaction?
> 2. **Goal Refactoring**: Decoupling Goals from Wallets completely means Goals track arbitrary progress independent of actual account balances. Is this correct?
> 3. **Chat Interruptions**: When a user leaves the app while AI is typing, should we deliver the message via a Push Notification when it finishes?

## Proposed Changes

---

### Part 1: High Priority Bug Fixes

#### Backend & Flutter Logic
- **App Crash / Logout**: Investigate and fix the issue causing users to be suddenly logged out or crash on entry (likely token expiry handling or unhandled exceptions during initial load).
- **Report Screen Crash**: Fix `NoSuchMethodError: Class 'ReportCategory' has no instance method '[]'` in `_MimoInsightCard` at `report_screen.dart:244`.
- **Recurring Rules Layout**: Fix RenderFlex overflow in `recurring_rules_screen.dart` and add exact-time auto-add logic.
- **Undeletable Transactions**: Fix the bug where erroneous transactions persist and cannot be deleted.

### Part 2: AI & Chat Logic Enhancements

#### AI Prompts & Capabilities
- **Diverse Responses**: Remove the empty response rule for Actions. Ensure AI responds intelligently and adheres to the `verbal_style` (dui_de, dan_doi). Send full context data.
- **Chit-chat & Personas**: Improve chit-chat prompts to guide users back to app features. Ensure relationships (parent, lover) and username are correctly applied.
- **Action Overwrites**: Fix the issue where default loading text is overwritten by the LLM response. Differentiate between initial intent recognition and final execution response.
- **Concurrent Messaging**: Handle cases where the user sends a message while the AI is still typing, and handle app-backgrounding during requests.
- **Budget Suggestions (`SUGGEST_BUDGET`)**: Implement an economic algorithm separating Fixed Costs and Variable Costs. Suggest limits for new categories dynamically.
- **Spelling**: Instruct the LLM to output perfect Vietnamese spelling.

#### Chat UI / UX
- **Action Confirmations (Cards)**:
  - `SET_LIMIT`, `ADD_GOAL`, `SET_GOAL`: Fix language (don't mix English/Vietnamese, use "Tạo mục tiêu" instead of "Tăng mục tiêu").
  - **Color Psychology**: Use Gold/Mint for positive actions (Goals) and Neutral Slate for settings (`SET_USERNAME`), avoiding Orange (Warning) for everything.
  - **Flat UI State**: After action confirmation, the card should turn into a flat, disabled log entry.
- **Sticker / Emotion Separation**: Detach AI emotions (stickers) from the text bubble, displaying them floating above the text.
- **Chat Header & Quick Replies**: Fix spacing in the chat header. Bold quick reply text and add a fade gradient for scrollability. Define 20 solid Chat suggestion prompts.

### Part 3: UI Redesign & "Premium" Polish

#### Navigation & Core Structure
- **Bottom Nav Bar**: Update to 5 tabs (Home, Expenses, AI Assistant 🌟, Goals, Settings). Remove the floating chat button. The AI Assistant button opens a Speed Dial popup (Scan Bill, Note/Photo, Chat).
- **Google Material Symbols (Rounded)**: Update all icons across the app to be softer and more modern. Remove custom emoji (🔥, 👋) in favor of vector assets.
- **Remove Error SizedBoxes**: Remove inline loading text above the nav bar; replace with a global top progress banner for background tasks (like OCR).

#### Home & Shared Components
- **Home Header**: Align the Streak button. Increase date contrast. Ensure the Segment Tab (Story/Gallery/Calendar) sits cleanly below the header or is integrated into a solid block.
- **Negative Balance**: Make negative balances bold and red/orange.
- **Wallet Filter**: Add a fade-out gradient to indicate scrollability.

#### Cards & Timelines
- **Card Story (Image)**: Add padding and border-radius to the image itself. Move the amount tag above the image.
- **Card Story (No Image)**: Shrink the Mimo AI chat bubble significantly; use a small inline text `🤖 Mimo: ...` instead of a massive card.
- **Calendar Tab**: Drastically simplify cards to list items (Icon, Note, Time, Amount). Remove the horizontal weekly calendar strip as requested. Reduce vertical spacing.
- **Gallery**: Increase border-radius to 24px. Ensure text on images has a readable gradient backdrop. Map category icons correctly instead of always showing "Other".

#### Details, Reports, and Goals
- **Detail Screen**: Implement full-screen image preview with pinch-to-zoom. Fix bottom button colors (match category). Clean up row layouts. Remove redundant list items for single-item transactions.
- **Report Screen**: Add actionable "Mimo's Insight Card". Make charts interactive (tap for AI insights). Add month-over-month trend lines.
- **Goal Screens**: Disconnect from Wallets. Remove nested cards. Fix the (+/Add) button logic. Enhance progress bar visuals (gradient, thickness, celebration effect at 90%). Add friend invites via link/code.

#### Dark Mode
- **System-wide Accessibility**: Fix severe contrast issues where dark text is rendering on dark backgrounds. Ensure all text meets WCAG standards for dark mode.

## Verification Plan
1. **Critical Bugs**: Verify app startup stability, Report screen rendering, and Recurring rules layout.
2. **AI Logic**: Test all intents (`SET_LIMIT`, `SET_GOAL`, `REPORT_GENERAL`, `SUGGEST_BUDGET`) to ensure cards render correctly, text is not overwritten poorly, and responses are non-empty and formatted.
3. **UI/UX**: Walk through Home, Chat, Gallery, Calendar, and Detail screens in both Light and Dark mode, matching against the redesign specifications.
