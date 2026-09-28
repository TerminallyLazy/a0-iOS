---
name: Agent Zero iOS
description: Agent Zero identity adapted to native conversation reading and agent activity.
colors:
  a0-canvas-light: "#fafafa"
  a0-canvas-dark: "#212121"
  a0-panel-light: "#f0f0f0"
  a0-panel-dark: "#1a1a1a"
  a0-tint-light: "#384653"
  a0-tint-dark: "#d4d4d4"
  a0-supporting-light: "rgb(34% 34% 36%)"
typography:
  title:
    fontFamily: "Apple system UI"
    fontWeight: 600
  body:
    fontFamily: "Apple system UI"
  label:
    fontFamily: "Apple system UI"
  code:
    fontFamily: "Apple system monospaced"
rounded:
  generated-input: "10pt"
  code-table: "12pt"
  composer: "16pt"
  panel: "16pt"
spacing:
  compact: "8pt"
  control: "10pt"
  content: "12pt"
  panel: "16pt"
  transcript-inset: "20pt"
  transcript-gap: "24pt"
components:
  message-panel-light:
    backgroundColor: "{colors.a0-panel-light}"
    rounded: "{rounded.panel}"
    padding: "{spacing.panel}"
  message-panel-dark:
    backgroundColor: "{colors.a0-panel-dark}"
    rounded: "{rounded.panel}"
    padding: "{spacing.panel}"
  composer-light:
    backgroundColor: "{colors.a0-panel-light}"
    rounded: "{rounded.composer}"
  composer-dark:
    backgroundColor: "{colors.a0-panel-dark}"
    rounded: "{rounded.composer}"
  latest-light:
    width: "36pt"
    height: "36pt"
    backgroundColor: "{colors.a0-tint-light}"
    textColor: "{colors.a0-canvas-light}"
  latest-dark:
    width: "36pt"
    height: "36pt"
    backgroundColor: "{colors.a0-tint-dark}"
    textColor: "{colors.a0-canvas-dark}"
---

# Design System: Agent Zero iOS

## Overview

**Creative North Star: "Keep conversation reading stable while Agent Zero works."**

Agent Zero's existing identity anchors a native iPhone and iPad companion. The original wordmark and A mark establish recognition; adaptive neutral surfaces and system text styles keep attention on conversations and agent activity.

The interface uses native navigation, restrained tonal layering and progressive disclosure. Replies occupy the open canvas, while user messages, delivery receipts and activity use panels. Expanding details preserves the reader's position; Latest explicitly returns to incoming replies.

**Key Characteristics:**
- Original Agent Zero vector identity and adaptive neutral palette.
- Native Dynamic Type, SF Symbols and safe-area controls.
- Open reply canvas with collapsible activity and long messages.
- Stable reading position with an explicit Latest action.

## Colors

The palette uses light paper and charcoal neutrals, with a muted blue-gray action tint in light appearance and a pale neutral tint in dark appearance.

### Primary

- **A0Tint:** The shared action and link tint. The composer frame and enabled Send surface also use it. Its two appearances are the `a0-tint-light` and `a0-tint-dark` primitives.

### Neutral

- **A0Canvas:** The page and transcript background, using the paired canvas primitives.
- **A0Panel:** User messages, activity, pending deliveries, code, tables and composer interiors, using the paired panel primitives.
- **Project colors:** Server-owned project colors appear as small outlined dots and editor swatches. They label project identity rather than replace the app palette; adjacent names and selection marks remain readable without color. Six- and eight-digit CSS hex values retain their alpha.
- **A0Supporting:** Opaque supporting text in light appearance, defined by `a0-supporting-light`; dark appearance retains UIKit `secondaryLabel`. Used for activity summaries, structured labels, draft status, the composer prompt and Settings supporting text. It is not a replacement for every native secondary foreground.
- Native primary, secondary and tertiary foreground styles elsewhere adapt to appearance; they have no app-owned fixed hex value. Native green marks a current connection, paired with text and an icon. Destructive actions retain the system role.

**The Adaptive Pair Rule.** Use the matching appearance of A0Canvas, A0Panel and A0Tint together. Latest explicitly pairs its tint background with an A0Canvas foreground.

Source of truth: `App/Assets.xcassets/A0Canvas.colorset`, `A0Panel.colorset` and `A0Tint.colorset`. The supporting color is defined in `App/SettingsView.swift`. Appearance follows the device by default; Settings can override it with Light or Dark. Sidecar tonal ramps and HTML previews are illustrative translations for the design panel; they do not introduce app tokens or replace native component behavior.

## Typography

**Body Font:** Apple system UI, through SwiftUI semantic text styles.
**Label/Mono Font:** Apple system UI for labels; the system monospaced design for code and structured details.

There is no separate display face. The wordmark is artwork rather than typeset text. Semantic styles preserve Dynamic Type instead of fixing a point-size ramp.

### Hierarchy

- **Title:** `.title2` for the empty-conversation heading, generated-reply setup and Markdown level one; `.title3` for Markdown level two; semibold weight. Forecast temperatures use medium `.largeTitle` with monospaced digits; forecast symbols use native large-title sizing.
- **Headline:** `.headline` for message headings, lower Markdown headings and the New chat action.
- **Body:** Default body style for prose and editable message text.
- **Label:** `.subheadline` for author and disclosure labels, `.caption` for metadata, status and code language. Author labels use semibold; disclosure labels use medium weight.
- **Code:** `.callout` in the monospaced design for code and structured field values; Raw event uses monospaced `.caption`. Structured field labels use semibold `.caption`.

**The Semantic Type Rule.** Use native text styles for interface and message hierarchy; reserve the monospaced design for code and structured details.

## Layout

The chat list and conversation share a native `NavigationStack`; the conversation title is inline. Phone and tablet retain the same navigation structure. The Workspace drawer overlays from the leading edge, outside the conversation navigation stack. Its width is the smaller of 400 points and viewport width minus 44 points; a black backdrop at 35% opacity leaves a dismissible edge. It is not a permanently docked sidebar.

The transcript is centered with a maximum width of 760 points, 20-point padding and 24-point gaps between entries. User messages add a 24-point leading inset. Message interiors use 12-point spacing and 16-point panel padding; activity groups use 16-point horizontal and 8-point vertical padding. Expanded activity groups share one outer panel with flat entries and a decorative timeline rail. Code and tables use 12-point padding. Horizontal scrolling contains wide code and tables.

Generated content sits within the same transcript width. Dashboard uses an adaptive native grid with 280-point minimum columns and 20-point gaps; accessibility text sizes use one flexible column. Forecast days scroll horizontally. Chart plots currently use a 220-point height and carousel media a 240-point height; captions, source links and value disclosures sit outside those media regions.

The composer sits in a bottom safe-area inset with 16-point horizontal and 10-point vertical padding. Its input grows from one to six lines. The connection action also lives in a bottom safe-area bar. Custom conversation actions use at least a 44-point label height; icon-only actions provide a 44-by-44-point label. System controls retain native layout and behavior.

## Elevation & Depth

Depth comes from contrasting panel tone, native bar material and system control treatment. The transcript has no custom shadows, blur layer or bespoke glass treatment. Standard separators mark connection status and table headers.

**The Tonal Surface Rule.** Separate conversation content with spacing and panel tone; this implementation does not add custom drop shadows.

## Shapes

Panels have gentle rounded corners, with the `panel` radius for user messages, deliveries and activity groups. The composer uses the `composer` radius; code, tables and carousel clipping use `code-table`. Generated inputs use `generated-input` on an A0Canvas fill within their panel. Native lists, alerts, menus and bordered-prominent controls retain platform-defined shapes rather than an app-owned radius.

## Components

### Buttons

The interface uses native controls and SF Symbols with semantic accessibility labels. New chat is a headline action in the list. Send is a 36-point upward-arrow circle inside a 44-point label; eligibility follows connection, draft and storage state. When enabled, its canvas foreground contrasts with the tint fill; disabled Send uses supporting ink with no fill. Latest is a compact 36-point downward-arrow circle within a 44-point hit region, with the accessible label “Jump to latest reply” and the same tint/canvas contrast. Copy actions change to a checkmark and “Copied.” There is no custom hover or focus theme; platform behavior is authoritative.

### Inputs / Fields

The framed composer groups a one-to-six-line input above a controls row. Its panel fill and composer radius surround both regions; a one-point A0Tint border uses 20% opacity at rest and 50% when focused. The input has 14-point top/horizontal padding and 4-point bottom padding, with an A0Supporting “Message Agent Zero” prompt. The lower row places Chat tools plus on the left, Voice and Send on the right, with 44-point action regions. The plus opens Tools, whose first action opens native photo/file selection. Selected files appear in a removable tray above the input. Sending or opening tools clears keyboard focus. The model picker, context meter and draft-options menu sit above it, followed by a trailing 44-point connection button with a 10-point status dot. Connection text lives in its compact detail popover. Routine saving/saved labels are absent; Draft options retains an accessible storage-state value, and storage failures add a visible label, explanation and Retry saving. While the input is focused, a 44-by-44-point keyboard/down-chevron action appears beside Draft options. Hide keyboard resigns focus without sending or modifying the draft; interactive scroll dismissal remains available. Native search filters the chat list.

### Navigation

The original template wordmark anchors the root list. Rows show a chat symbol, a two-line name and a chevron. New chat opens a draft conversation; first-send context assignment preserves that route. Back preserves drafts, while Disconnect clears the route. The root gear opens Settings. Conversation options contain Chats, Chat tools, Settings and Disconnect; the Agents icon opens a read-only inspector. Settings and inspectors use native sheets with inline titles and Done actions.

The Workspace drawer carries the original wordmark, New conversation, search and two-line conversation names. The selected row uses a panel fill plus a checkmark; a waveform marks only a server-reported running conversation. Project dots accompany project-associated chats; Projects and an All projects/project filter are reachable from the drawer and root list. A Tasks section lists available server task names, and Settings remains reachable at the bottom. Selection closes the drawer into the stable conversation route. The fixed header contains the original wordmark and a 44-point close action; a panel-filled search field sits beneath it, and Settings remains outside the scrolling list. Backdrop tap, accessibility Escape and a deliberate left swipe on the header also dismiss. The underlying screen is accessibility-hidden while open; focus moves to Close sidebar, then returns to the opener. Opening dismisses the keyboard. The 0.22-second ease-out leading transition is suppressed for Reduce Motion.

### Messages and Markdown

Agent answers use the open canvas and original A mark. User and activity entries use panel surfaces. Long messages collapse by default, with a local preference to keep them open. Individual activity remains expandable regardless of that preference. Prose previews show up to five lines with Show more; activity uses a two-line readable summary with Show activity. Expanded content offers Show less and optional structured Details.

Markdown uses native headings, inline emphasis, lists, quotes, code, dividers and simple tables. Code scrolls horizontally and has its own copy action. Images embedded in ordinary Markdown remain descriptive text. Explicit generated ImageCarousel components use the separate bounded public-image loader described below. Safe HTTP(S) links require destination confirmation throughout the entire message row; unsupported URLs are discarded. This is a supported Markdown subset, not full browser rendering.

### Agent activity

Consecutive known activity entries share a single “Agent activity” panel by default, with a local preference to show separate entries. Its collapsed state includes a step count, disclosure and the last two non-utility steps, falling back to the latest entry when necessary. Each preview has a readable title, symbol, recorded agent label and up to two summary lines. Multiple recorded agents are identified together. Opening the group reveals flat entries beside a decorative timeline: a 5-point dot and 1-point supporting-ink rail at 25% opacity, without nested panel fills or duplicate interior padding. Warnings, errors, answers and unknown types remain separate.

Agent Zero `icon://` heading metadata maps to native SF Symbols and is removed from visible text; it never opens a URL. Known tool names become readable actions such as Search web or Run code. Tool subtitles retain agent attribution, and unknown metadata uses a readable label and safe symbol fallback. Structured arguments take precedence over legacy JSON, with human summaries outside the disclosure. Expanded entries show labeled Details; structured source content remains separately inspectable in Raw event.

The Agents inspector groups recorded entries by agent number, showing the latest tool label and summary. One agent disclosure is open at a time; its entries retain native message details. Agent Zero identifies agent zero and Agent N identifies subordinate responses. Recorded steps do not imply current execution or completion.

The grouping and growing composer draw on the user's Goose reference without importing Goose code, assets or identity.

### Settings

The native form groups Reading, Connection, Privacy & storage, and About. Reading provides System/Light/Dark appearance plus Collapse long messages and Group agent activity. Changes apply immediately and persist locally in UserDefaults; they contain no credentials. Text size continues to follow device settings.

Connection displays server and status, with Change server available for an active session or preview. A confirmation alert offers Disconnect and choose server or Cancel. Confirming returns to the existing connection flow while retaining drafts and pending delivery records; Cancel preserves the session. Settings describes optional Keychain password saving and shows the development-preview identity and version. It does not expose server model configuration.

Rich replies is enabled by default and advertises the supported format with each explicit send, without sending an extra message. The adjacent Generative UI setup screen explains supported components and provides copyable agent instructions. It does not provision or modify a server profile. User-message echoes collapse only the app's exact owned capability suffix under Rich reply instructions; arbitrary user text is preserved.

### Generated replies

Only explicit assistant response payloads opt into the trusted native catalog: an `a2ui` metadata payload or a top-level `a2ui` code fence. Ordinary JSON, quoted examples, user messages and tool content remain ordinary messages. Surrounding prose renders separately as Markdown. The bounded document is validated before rendering; arbitrary HTML, JavaScript, remote themes and SDK remote-media components are not part of the catalog.

An Interactive reply label identifies the surface, inside an A0Panel container with 12-point padding and the panel radius. Receiving, preparing, unavailable and removed states retain plain-language status. A View interface data disclosure keeps the source inspectable. Tapping or acting on the surface pauses transcript following. The catalog inherits A0Tint and the supporting caption color rather than introducing a separate generated identity.

- **Forecast:** Location, supplied update text, condition, native weather symbol and large temperature establish the hierarchy. Day columns use native symbols and high/low values with monospaced digits; the source link remains visible below. Displayed data comes from the reply, not an independent weather service request.
- **Image carousel:** A title and “n of total” count accompany swipe paging. Each selected image has its own caption and source link, plus explicit Previous image and Next image controls. Images scale to fit. Loading, unavailable/Retry and synthetic-preview states remain inside the media region. Only public HTTPS image URLs use the separate cookie-free, credential-free ephemeral loader; redirects are rejected, downloads are bounded to 4 MiB and decoded thumbnails to 1,200 pixels. Ordinary Markdown images still do not fetch.
- **Charts:** Native Swift Charts renders line, bar or area data. The chart includes a title and y-axis descriptor, a series legend when series metadata exists, optional source attribution and a View values disclosure. Lines show point symbols; area charts retain a line above a translucent fill. Series colors come from the native chart treatment and are not new brand palette tokens. Values remain inspectable without interpreting color or plot position alone.
- **Dashboard:** Trusted child components share an adaptive native grid, retaining each component's title, source and disclosures rather than embedding an arbitrary webpage.
- **Forms:** Supported basic native catalog controls include text, checkbox, choice and slider inputs with event buttons. The local A0TextField override keeps a persistent visible label above the editable value; text inputs use a canvas fill and supporting prompt, numeric fields use a decimal keyboard, and obscured values use SecureField. A keyboard toolbar supplies Hide keyboard. Form values are local and unsubmitted values are not saved when leaving the conversation.

**The Reviewed Action Rule.** A generated action opens Review response with its name and labeled values. Cancel dismisses it. The bottom safe-area Add to draft action stays reachable and uses the same contrasting tint/canvas pair as Latest. Adding a response preserves explicit user control of Send; a generated action never sends automatically.

### Follow and connection state

Reading history or opening details pauses following. Latest resumes and moves to the bottom, using a short ease-out animation unless Reduce Motion is enabled. A compact status strip retains textual connection state and reveals recovery information when relevant. A separate working strip is shown for actual server progress, paused state or synchronization with retained content. It uses server-derived presentation text, a progress indicator for working/synchronizing, and an icon otherwise; it does not infer work from an open connection or recorded agent steps. Local delivery receipts show their actual state, including uncertain outcomes, without implying successful delivery.

### Conversation tools

The plus and Chat tools affordance open a compact native Tools popover, retaining popover presentation on compact devices. Its plain list is 320 points wide, with a Dynamic Type-scaled base height of 340 points; inspection adds 100 points, capped at 560. History and Context push a selectable result view within the popover, with Back to tools. Agent actions expose Pause/Resume and Nudge; inspection actions expose History and Context in a dedicated reading destination, with selectable text, token counts when supplied and Back to tools. Controls require a current connected conversation and disable while busy. Nudge explains its interruption effect before confirmation. Unconfirmed mutating actions show a Check the previous action section and require an explicit outcome check before another control action; they are never replayed automatically.

Open full WebUI confirms the destination before handing its HTTPS origin to the browser, where a separate sign-in may be needed. Attachments, project file management, knowledge, memory, skills, project-scoped preset selection, provider credentials, broader administration, goal mode and terminal remain WebUI functions; the native project editor covers only its implemented settings.

### Launch and model presets

The branded startup cover centers the original mark and wordmark on A0Canvas with a native opening/restoring progress label below. It lasts only for real profile/session startup. Successful authenticated cold launch opens the new-chat draft with the sidebar closed; older drafts and receipts remain available. Returning from background within the same process keeps the current conversation.

The composer model picker uses a brain symbol, current preset/Main-model label and disclosure chevron. Its native popover is ideally 360 points wide, capped at 420, with a Dynamic Type-scaled 400-point height capped at 620. The header and Edit presets action remain outside the scrolling list. Each preset shows a name, selected checkmark and aligned Main/Utility/Embed/applicable Vision rows with model and provider. Scope text distinguishes an inherited choice from a current-chat override; unavailable overrides and new drafts explain why selection is disabled.

Edit presets is a native navigation sheet with a prominent shared-server scope explanation. Rows lead into labeled model forms; advanced settings and a monospaced JSON editor keep dense parameters behind disclosure. Add/remove/rename are staged, Default is protected, and the bottom safe-area Save shared presets action is explicit. Reset and removal explain their shared impact. A changed server baseline presents a refresh instruction rather than silently overwriting. Provider credentials and project-scoped selection hand off to WebUI.

### Projects

Native project lists use compact server-color dots, title/description rows and an active-project checkmark. The color dot has a subtle outline so pale colors remain visible; color never substitutes for the name. Project filtering stays within chat navigation, and a conversation-level project label opens the same project workspace.

Creation, clone and edit use native forms. The color grid presents 24-point swatches inside 44-point actions, with a 34-point selection ring and a manual hex field. Identity and instructions are primary; file-structure preferences, variables, MCP JSON and opt-in masked secrets use disclosure where appropriate. The bottom safe-area save action contrasts A0Tint with A0Canvas. Clone has a separately labeled optional secure token field. Deletion uses its own sheet with explicit consequences and an exact folder-name field before enabling the destructive action. Advanced project functions use a confirmed browser handoff rather than placeholder native screens.

### Context meter

The circular context meter scales from 32 points with the native caption style inside a minimum 44-point composer action. Its two-point ring uses primary ink over a supporting-ink track, with a semantic caption percentage and a full accessibility value; missing usage displays a chart symbol instead of a fabricated number. The popover uses a 320-point preferred width, expanding to 420 points at accessibility text sizes, and scrolls within a 560-point height. Category labels stack above their values at accessibility sizes. Numeric counts and percentages stay intact; totals and their units reflow as separate groups instead of wrapping digits. It shows server tokens/window, used percentage, a native progress bar, available category rows and free space using monospaced digits. Provider cache and input/output counts remain a separate section. Missing breakdowns and stale retained reports have explicit text. This is server accounting, not a measure of visible transcript length.

### Voice

The composer microphone starts Dictate message directly, with live speech appearing in the existing message field. The 36-point microphone/stop treatment sits within a 44-point action; active voice uses the contrasting tint/canvas circle. Status appears below the input after activation. Stop voice replaces the microphone while requesting permission, recording or reading a reply. The adjacent chevron opens Voice options. Continuous listening remembers its local setting across launches, defaults off and never starts automatically; recording remains foreground-limited. Backgrounding, leaving/changing the conversation or audio interruption stops it. Unsupported local recognition leaves an explanation and typing available.

Partial results replace only the current dictation insertion, preserving the starting draft; manual edits end recording rather than being overwritten. There is no separate transcript-adoption sheet. Review happens in the normal editable composer and Send remains explicit. Read reply is optional user-triggered system speech of the latest assistant prose, excluding code; playback and recording are mutually exclusive. Supported on-device cleanup acts on the whole draft and opens Review suggestion with Original, Suggested edit, Keep original and a bottom Use suggestion action. A changed draft invalidates the proposal. The owner confirmed prior physical dictation; new inline-flow and cleanup-quality acceptance remain separate from component availability. See `docs/VOICE.md`.

### Session continuity

Ordinary background/foreground transitions retain the mounted conversation, transcript and generated reply views while transport pauses and a fresh snapshot gates sending. After process termination, a valid saved session restores authentication and opens the new-chat draft with the drawer closed. Previous conversation drafts/receipts remain available; reopening a conversation refetches its content without replaying login or mutations. Expired authentication returns to sign-in; offline relaunch cannot show an archived transcript. Unsaved generated form values, carousel position and recognizer buffers are not durable after termination; text already inserted by dictation follows ordinary draft persistence. Explicit Disconnect removes active session restoration. See `docs/SESSION-RESTORATION.md` for the storage and recovery contract.

## Do's and Don'ts

### Do:
- Do reuse the original Agent Zero wordmark and A mark as template assets.
- Do keep actions reachable above the keyboard and place the minimum hit area inside each custom button label.
- Do pause following when the reader scrolls into history or expands content; offer Latest to resume.
- Do preserve native text scaling, semantic labels and Reduce Motion behavior.
- Do validate external links and confirm the destination in message headings, previews and expanded content.
- Do translate icon metadata into native symbols and readable labels, while keeping structured and raw tool details available on demand.
- Do preserve drafts when dismissing the keyboard or changing servers, and honor local reading preferences immediately.
- Do keep generated input labels persistent, source attribution visible and chart values inspectable.
- Do review generated actions before adding them to a draft; leave Send as an explicit user action.
- Do distinguish server-reported working state from recorded agent history.
- Do require explicit voice activation, preserve existing draft text and leave review before Send; apply cleanup suggestions only after confirmation.
- Do expose native server controls honestly and hand remaining WebUI features to a confirmed browser destination.
- Do pair project colors with names and preserve explicit confirmation for server-side deletion.
- Do distinguish server context estimates from provider usage and unavailable values.
- Do distinguish current-chat model overrides from shared preset edits and inherited defaults.
- Do keep startup progress tied to real work and preserve earlier drafts when landing on a new conversation.

### Don't:
- Don't use color alone to communicate connection or delivery state.
- Don't replace readable agent responses with an always-collapsed activity panel.
- Don't execute HTML or fetch images embedded in ordinary Markdown; generated carousel media must use the dedicated validated loader.
- Don't imply full WebUI parity or successful live voice/control acceptance from native component availability.

Browser captures use a 160-point contain-fit card and a quieter globe/caption footer within agent activity. Up to three recent captures remain visible when activity is collapsed. Tapping presents a bounded popover with an image region capped at 440 points and explicit Close. Raster content stays separate from raw event data; loading and retry preserve the card footprint.
