# Goose mobile reference decisions

Reviewed 2026-09-28 from the user-supplied `aaif-goose/goose-mobile` main branch. These are interaction references, not an imported implementation or new dependency. Agent Zero's WebUI remains the visual identity and protocol authority.

| Reference | Useful pattern | Agent Zero application |
| --- | --- | --- |
| [StackedToolCallsView.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/StackedToolCallsView.swift) | Compress consecutive tool activity, expand for inspection | Implemented native activity groups with step counts and expandable individual output. Group only known routine log types; keep warnings/errors/answers separate. Do not invent completed/executing states from a log type. |
| [ToolViews.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ToolViews.swift) | Separate arguments/results and progressive disclosure | Implemented collapsible activity, raw Details disclosure, selectable output and Copy code. Server-side approval actions require their own validated Agent Zero contract. |
| [SidebarView.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/SidebarView.swift) | Searchable sessions, date grouping, favorites and agent navigation | Searchable chat list and stable navigation implemented. Next navigation refinement: iPad split view and phone drawer; date grouping needs verified timestamps, favorites need an explicit persistence design. |
| [LiquidGlassModifier.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/LiquidGlassModifier.swift) | Availability-gated iOS 26 glass with older-system material fallback | Use native navigation and composer bar material now. Keep transcript opaque and readable; reserve custom glass for floating controls after iOS 18/26 accessibility testing. |
| [ContinuousVoiceManager.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ContinuousVoiceManager.swift) | Listening/processing/speaking states, interruption and silence detection | Reference for the planned voice slice, not active in this build. Requires explicit mic permission, interruption/background cleanup and device audio tests. |
| [EnhancedVoiceManager.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/EnhancedVoiceManager.swift) | Distinguish typed, transcription-only and full conversation modes | Prefer editable dictation first. Hands-free auto-send is a distinct opt-in mode and must retain uncertain-delivery protections; no duplicate automatic sends. |
| [AppNoticeOverlay.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/AppNoticeOverlay.swift) and [AppNoticeCenter.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/AppNoticeCenter.swift) | One actionable notice for tunnel/network failure | Existing persistent connection/recovery banner keeps retry and drafts available. Future notice presentation should be scoped to the selected profile, distinguish authentication from transient reachability, and offer recovery without assuming the tunnel provider. |

The source review is not runtime testing of Goose. No Goose source or assets were copied. Voice, favorites, split navigation and server administration are not represented by decorative or inactive controls in this build.


## Settings and tool refinement

The additional [SettingsView.swift reference](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/SettingsView.swift) informed the native Connection/Appearance/About organization. Agent Zero uses its existing session authentication and Keychain contract; credentials are never written to display preferences. Local appearance and reading settings take effect immediately and persist, with an isolated UserDefaults suite for tests. Server changes confirm disconnection and return to the existing Connect screen.

Tool summaries now use Agent Zero's own structured log metadata (`tool_name`, `_tool_name`, `tool_args`, `step`) and WebUI icon-token grammar. Friendly tool names, semantic SF Symbols, compact summaries and flattened step details adapt the supplied Goose tool disclosures without importing code. Raw structured events remain inspectable. The composer has an explicit focus-dismiss control instead of relying only on a scroll gesture.


## Additional source review for generative replies

Read the current Goose directory and these additional implementations before adding A2UI:

| Source | Decision |
| --- | --- |
| [AssistantMessageView.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/AssistantMessageView.swift) and [Message.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/Message.swift) | Separate typed content rendering from message chrome. Agent Zero now routes explicit A2UI response content to GeneratedReplyView while retaining ordinary Markdown and tool rendering. |
| [TaskDetailView.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/TaskDetailView.swift) | Detail surfaces preserve context instead of doing work on behalf of a tap. Generated actions open a native review sheet before insertion into the existing draft. |
| [SharedMessageComponents.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/SharedMessageComponents.swift) | Separate code/table/prose blocks and shared message primitives. The existing native Markdown subset remains alongside the A2UI renderer; no Goose parser or syntax-highlighting dependency is copied. |
| [ChatView.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ChatView.swift) | Keep content composition, session identity and input handling coordinated. A2UI state is scoped to a response and log epoch; it cannot route actions to another chat. |
| [ThemeManager.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ThemeManager.swift) | Theme is centralized, but this source labels itself a stub. Preserve Agent Zero's current adaptive tokens and System/Light/Dark preference instead of importing that implementation. |
| [ConfigurationHandler.swift](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ConfigurationHandler.swift) | Friendly server labels are useful. Keep the existing HTTPS/profile/Keychain boundary; do not copy Goose's serialized secret field into display preferences. |

Voice, sidebar/favorites, attachments and task execution remain separate integrations requiring their actual Agent Zero contracts. This review does not claim those features were implemented or that Goose was runtime-tested.

## Workspace and voice continuation

SidebarView's separate session-selection/new-session callbacks informed the native Workspace drawer, preserving the app-owned route and draft identity. ContinuousVoiceManager, EnhancedVoiceManager, VoiceInputManager and VoiceOutputManager informed separate microphone/output ownership and explicit listening status. The app uses Apple's on-device Speech capability, foreground limits and draft review; Goose's automatic silence-triggered submission is not copied. AssistantMessageView and LiquidGlassModifier remain presentation references; no Goose code, assets or extra dependency was imported, and neutral Agent Zero surfaces remain authoritative. SplashScreenView was reviewed; startup uses truthful restoring/sign-in states instead of a timed decorative splash.
