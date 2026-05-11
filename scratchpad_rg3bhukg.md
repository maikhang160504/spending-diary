# Design Extraction Plan - Figma Prototype

## Task Overview
Capture and document the design of the Figma site: https://detach-online-42718176.figma.site for Flutter implementation.

## Checklist
- [x] Open Figma site and capture initial view
- [x] Identify and navigate through all pages/sections
- [x] Capture screenshots of each page (homepage, navigation, list, detail, etc.)
- [x] Document design language:
    - [x] Color palette
    - [x] Typography
    - [x] Layout structure
    - [x] Navigation patterns
    - [x] Key UI components
    - [x] Icons and images

## Findings
- **Colors:**
    - Primary: Teal/Greenish (`#14B8A6`, `#0F766E` gradient)
    - Secondary/Accents: White, Light Gray (`#F3F4F6`), Pink/Red for expenses.
    - Translucency: `backdrop-blur-sm`, `bg-white/30`.
- **Typography:**
    - Sans-serif font (likely Inter or similar).
    - Large bold numbers for currency.
    - "Muted foreground" for labels.
- **Layout:**
    - Top header with date and greeting.
    - Horizontal scroll for wallet selection.
    - Card-based summary for balance/income/expenses.
    - Segmented control/Tab bar for feed content (Story, Gallery, Calendar).
    - Bottom Navigation Bar with a center prominent button.
    - Floating Action Button (FAB) for chat.
- **Navigation:**
    - Bottom Nav: Home, Report, Camera (Center FAB), Goals, Settings.
    - Home Tabs: Story (Feed), Gallery (Grid), Calendar (Monthly view).
- **Components:**
    - Category chips (e.g., "Ăn uống").
    - Wallet cards with icon and count.
    - Transaction cards with image, description, and price.
    - Monthly calendar with indicator dots for spending.
    - Charts (Bar chart for daily spending, Doughnut chart for category spending).
    - AI Assistant button on Report page and full Chat interface.
    - Mode selection cards (Dui Dẻ/Dận Dữ) on Settings.
    - Toggle switches for Notifications and Dark Mode.
    - List items with icons and chevron arrows.
    - Logout button with red border/text.
    - Goal cards with progress bars and "Add money" buttons.
    - Camera overlay with segmented control (Ảnh/Bill) and large shutter button.
- **Typography Details:**
    - Primary Font: Sans-serif (likely Inter or similar).
    - Large Display Numbers: Bold, high contrast.
    - Captions: Small, light gray (`text-muted-foreground`).
- **Icons:**
    - Outline icons for navigation.
    - Emojis for categories and mode selection.
