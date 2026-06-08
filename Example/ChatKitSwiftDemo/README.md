# ChatKitSwiftDemo

`ChatKitSwiftDemo` is a minimal iOS app for testing `ChatKitSwift` against a backend that mints short-lived OpenAI-hosted ChatKit client secrets.

## Setup

1. Generate the Xcode project:

   ```bash
   cd Example/ChatKitSwiftDemo
   xcodegen generate
   ```

2. Configure a backend endpoint in the Xcode scheme environment:

   ```text
   OPENAI_CHATKIT_SESSION_ENDPOINT=https://yourapp.example.com/api/chatkit/session
   ```

   The endpoint should be owned by your backend. It can call OpenAI with your API key server-side and return:

   ```json
   {
     "client_secret": "ck_...",
     "expires_at": 1780950000
   }
   ```

3. Open `ChatKitSwiftDemo.xcodeproj` and run the app on an iOS simulator.

Do not put an OpenAI API key in the demo app, `.env`, scheme, or app bundle. Keep API keys on your server and expose only the session endpoint to the client app.
