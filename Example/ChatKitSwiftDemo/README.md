# ChatKitSwiftDemo

`ChatKitSwiftDemo` is a minimal iOS app for testing `ChatKitSwift` against OpenAI-hosted ChatKit.

## Setup

1. Generate the Xcode project:

   ```bash
   cd Example/ChatKitSwiftDemo
   xcodegen generate
   ```

2. Create a local `.env` file next to `project.yml`:

   ```bash
   cp .env.example .env
   ```

3. Fill in:

   ```text
   OPENAI_API_KEY=...
   OPENAI_CHATKIT_WORKFLOW_ID=...
   OPENAI_CHATKIT_USER_ID=chatkitswift-demo-user
   ```

4. Open `ChatKitSwiftDemo.xcodeproj` and run the app on an iOS simulator.

The `.env` file is intentionally ignored by git. The app also checks process environment variables first, so CI or custom schemes can provide the same values without a local file.
