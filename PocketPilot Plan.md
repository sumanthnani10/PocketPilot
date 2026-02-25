# PocketPilot

PocketPilot is an open-source Android automation project that combines **AI planning** with **RPA-style mobile control**.

The goal is to let users automate mobile tasks using natural language, while keeping execution safe, traceable, and reusable.

Examples:
- “Post my latest photo on Instagram”
- “Open my appliance app and turn on the living room AC”
- “Open app X and complete task Y”

PocketPilot will use:
- **Flutter** for the app UI and orchestration
- **Kotlin (Android)** for native device automation
- **Accessibility APIs** for screen understanding and actions
- **Gemini** for task understanding and step-by-step planning

---

## Vision

PocketPilot should act like a mobile copilot:
1. Understand what the user wants to do
2. Observe what is currently on the phone screen
3. Decide the next best action
4. Perform that action
5. Repeat until the task is complete

If the app cannot reliably automate a task using AI alone, it should allow the user to **teach the task once** and save it as a reusable skill.

---

## What We Want to Implement

We want to build a mobile automation system with two core capabilities:

### 1) AI-guided live automation
- User gives a command in plain language
- AI interprets the intent
- PocketPilot reads the current UI (screen structure)
- AI selects the next action
- PocketPilot executes the action
- Loop continues until completion

### 2) Teach-once, replay-anytime automation
- User performs a task manually once
- PocketPilot records the interaction trace (events/actions, not video)
- PocketPilot saves the trace as a skill
- User can run that skill later with one tap or command

---

## Implementation Phases

## Phase 1 — Live Agent Automation (AI + Screen Actions)

### Objective
Build an agent that can **access the screen**, understand the visible UI, and perform actions such as:
- clicking/tapping
- scrolling
- swiping
- typing text
- going back/home
- opening apps

### What the app should do in Phase 1
1. Accept a user task in natural language
2. Read the current screen state using Android Accessibility APIs
3. Send task + screen context to Gemini
4. Receive the next action from Gemini (through a controlled tool interface)
5. Execute the action on the device
6. Re-check the screen and continue until:
   - task is complete
   - the agent gets stuck
   - the user stops it

### Phase 1 features (target)
- **Task input UI** (text command)
- **AccessibilityService integration**
- **UI tree extraction** (node-based screen understanding)
- **Action executor**
  - tap/click
  - scroll
  - swipe
  - text entry
  - back/home
  - open app
- **Gemini planner integration**
- **Observe → Plan → Act loop**
- **Execution logs / debug view**
- **Basic retries and timeouts**
- **Stop / Pause controls**

### Phase 1 design principles
- Prefer **node-based actions** over raw coordinate taps
- Use **safe tool calls** (whitelisted actions only)
- Keep all execution **traceable** (logs for each step)
- Fall back gracefully if UI is unclear
- Ask for user help when confidence is low

---

## Phase 2 — Action Recording and Replay (Teach Once)

### Objective
Allow users to **teach PocketPilot a task once** by performing it manually, then replay it later as a custom skill.

### What the app should do in Phase 2
1. Start recording mode
2. Capture user interaction trace while the user performs a task
3. Save the recorded actions in a structured format
4. Let user name and save the skill
5. Replay the skill on demand
6. Support parameterized replay later (optional)
   - example: different text input, different item, different image

### What to record (not video)
PocketPilot should record:
- active app/package
- accessibility events
- selected UI elements (resource id, text, content description)
- action type (tap, scroll, type, swipe, back, etc.)
- timestamps / delays
- screen state hints (for validation)
- success/failure of each step

### Phase 2 features (target)
- **Record mode**
- **Trace viewer** (step-by-step recorded actions)
- **Save as skill**
- **Skill library**
- **Replay engine**
- **Step validation / retries**
- **Edit recorded steps** (optional)
- **Parameter support** (optional, later enhancement)

### Why Phase 2 matters
Some apps have:
- complex workflows
- unclear UI labels
- custom screens the AI may not understand

Phase 2 gives users a reliable fallback: **teach once, reuse forever**.

---

## Core Features We Are Looking For

### AI and Planning
- Natural language task understanding
- Step-by-step action planning
- Controlled function/tool calling
- Context-aware retries
- Failure handling when blocked

### Mobile Automation
- Screen inspection through Accessibility
- Node-based click/type/scroll actions
- Gesture dispatch for swipe/tap fallback
- App navigation (open app, back, home)

### Recording and Reuse
- Structured action tracing
- Skill save/load
- Replay and validation
- Reusable user-defined automations

### Safety and Control
- User-visible action logs
- Start/stop/pause controls
- Optional confirmations for risky actions
- Timeouts and retry limits
- Strict action whitelist for AI

### Developer Experience
- Modular architecture
- Clear Flutter ↔ Android bridge
- Debuggable logs and trace playback
- Easy extension for new tools/actions

---

## What the App Has to Be Doing (Behavior Summary)

PocketPilot should behave like a controlled automation agent, not a hidden background bot.

### At runtime, PocketPilot should:
- Wait for a user instruction
- Observe the current screen
- Decide one action at a time
- Execute the action
- Verify the result
- Continue or recover if needed
- Show what it is doing (transparent execution)
- Stop immediately when the user cancels

### If it cannot continue confidently:
- Explain where it is stuck
- Ask the user to intervene or teach the task
- Offer to save a new skill (Phase 2)

---

## Example User Flows

### Flow A — Live AI Automation (Phase 1)
1. User: “Open Instagram and create a new post”
2. PocketPilot reads the screen
3. Gemini chooses next action (open app / tap / scroll)
4. PocketPilot executes step-by-step
5. PocketPilot finishes or asks for help if blocked

### Flow B — Teach and Replay (Phase 2)
1. User starts “Record Task”
2. User performs a task manually in a complex app
3. PocketPilot records events and actions
4. User saves skill as “Turn on AC in appliance app”
5. Later, user runs the skill with one tap

---

## Out of Scope (for now)

- Full iOS support
- Background automation without user visibility
- Unlimited autonomous actions without safeguards
- Video recording-based replay
- Cloud-only execution dependency

---

## High-Level Architecture (Planned)

- **Flutter App (Dart)**
  - UI
  - task input
  - logs/debug screens
  - skill library
- **Android Native Module (Kotlin)**
  - AccessibilityService
  - UI observer
  - action executor
  - recorder/replayer
- **AI Planner (Gemini)**
  - task interpretation
  - action selection through tool calls
- **Local Storage**
  - logs
  - traces
  - saved skills

---

## Success Criteria

### Phase 1 is successful if:
- PocketPilot can observe the screen and perform basic actions
- Gemini can guide multi-step tasks with the tool interface
- The app logs all actions and outcomes clearly

### Phase 2 is successful if:
- Users can record tasks as structured traces
- Saved skills can be replayed reliably
- PocketPilot can reuse user-defined workflows repeatedly

---

## Project Direction

PocketPilot starts with live AI-guided automation (Phase 1) and grows into a teachable mobile automation platform (Phase 2).

The long-term goal is to make mobile automation:
- **easy to trigger**
- **safe to execute**
- **transparent to the user**
- **customizable for any app**