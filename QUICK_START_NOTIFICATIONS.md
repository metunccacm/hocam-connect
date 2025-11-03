# Quick Start: Fix Push Notifications for E2EE

## TL;DR
**Your encryption is CORRECT. Don't change it!** Push notifications with E2EE must be generic ("User sent you a message") because the backend can't decrypt messages. This is how WhatsApp and Signal work.

## Immediate Action Required

### Step 1: Apply Database Migration (2 minutes)

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run this file: `supabase_profiles_fcm_columns.sql`
3. Verify:
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name IN ('fcm_token', 'fcm_platform');
```

### Step 2: Test Current State (5 minutes)

#### Test In-App Notifications (Should Already Work ✅)
```bash
# Device 1: User A
flutter run

# Device 2: User B  
flutter run
# On User B: Navigate to any screen (NOT chat with User A)
# On User A: Send message to User B
# Expected: User B sees in-app notification with decrypted message
```

#### Test Push Notifications (Needs Backend)
```bash
# User B: Close app or put in background
# User A: Send message to User B
# Expected: User B receives push "User A sent you a message"
# User B: Tap notification → Opens chat → See decrypted messages
```

### Step 3: Implement Backend Notification Sender

**Quick Test (Before Full Implementation):**

```bash
# Get FCM token from database
SELECT fcm_token FROM profiles WHERE id = 'USER_B_ID';

# Send test notification using curl
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_FCM_SERVER_KEY" \
  -d '{
    "to": "PASTE_FCM_TOKEN_HERE",
    "notification": {
      "title": "Test User",
      "body": "Sent you a message"
    },
    "data": {
      "type": "chat",
      "conversation_id": "SOME_UUID",
      "sender_id": "USER_A_ID",
      "sender_name": "Test User"
    },
    "priority": "high"
  }'
```

**Full Implementation: Supabase Edge Function**

Create `supabase/functions/send-chat-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { conversation_id, sender_id } = await req.json()
    
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // 1. Get sender name
    const { data: sender } = await supabaseClient
      .from('profiles')
      .select('name, surname')
      .eq('id', sender_id)
      .single()
    
    const senderName = sender 
      ? `${sender.name} ${sender.surname}`.trim()
      : 'Someone'
    
    // 2. Get recipients' FCM tokens
    const { data: participants } = await supabaseClient
      .from('participants')
      .select('user_id')
      .eq('conversation_id', conversation_id)
      .neq('user_id', sender_id)
    
    if (!participants || participants.length === 0) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const { data: tokens } = await supabaseClient
      .from('profiles')
      .select('fcm_token, fcm_platform')
      .in('id', participants.map(p => p.user_id))
      .not('fcm_token', 'is', null)
    
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // 3. Send FCM notifications
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    
    for (const recipient of tokens) {
      await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `key=${fcmServerKey}`
        },
        body: JSON.stringify({
          to: recipient.fcm_token,
          notification: {
            title: senderName,
            body: 'Sent you a message',  // Generic - NO MESSAGE CONTENT
          },
          data: {
            type: 'chat',
            conversation_id,
            sender_id,
            sender_name: senderName,
          },
          priority: 'high',
          content_available: true,
        })
      })
    }
    
    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

**Deploy Edge Function:**
```bash
# In your project root
supabase functions deploy send-chat-notification

# Set FCM server key
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key_here
```

**Create Database Trigger:**
```sql
-- Call edge function when new message is inserted
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-chat-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('request.header.authorization')
    ),
    body := jsonb_build_object(
      'conversation_id', NEW.conversation_id,
      'sender_id', NEW.sender_id
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_message_send_notification
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

## Troubleshooting

### Issue: "Still showing encrypted text"

**Check:**
```dart
// In-app notifications should show decrypted text
// Push notifications should show "User sent you a message"
```

If push shows encrypted text, your backend is sending message content. It should send generic text instead.

### Issue: "Not receiving push notifications"

**Debug:**
```dart
// Check FCM token saved
flutter run
// Look for: ✅ FCM token saved to profiles table successfully

// Verify in database
SELECT id, fcm_token, fcm_platform FROM profiles;
```

### Issue: "iOS not working"

**Requirements:**
- ✅ Real iOS device (not simulator)
- ✅ Push Notifications capability in Xcode
- ✅ APNs key uploaded to Firebase
- ✅ Bundle ID matches Firebase config

## What You Get

### Lock Screen Notification:
```
┌────────────────────────────────┐
│ 💬 John Doe                     │
│ Sent you a message             │
│                         now    │
└────────────────────────────────┘
```

### After Tapping (Chat Opens):
```
┌────────────────────────────────┐
│ 💬 John Doe                     │
│                                │
│ Hey, want to meet for coffee?  │
│ Where should we go?            │
│ I'm free this afternoon!       │
│                                │
└────────────────────────────────┘
```

### In-App Notification (App Open):
```
┌────────────────────────────────┐
│ 💬 John Doe                     │
│ Hey, want to meet for coffee?  │
│                          [X]   │
└────────────────────────────────┘
```

## Files Changed

✅ `lib/services/notification_service.dart` - Updated notification handling
✅ `supabase_profiles_fcm_columns.sql` - Database migration
✅ `E2EE_PUSH_NOTIFICATION_GUIDE.md` - Backend guide
✅ `CLIENT_NOTIFICATION_ARCHITECTURE.md` - Client docs
✅ `PUSH_NOTIFICATION_SOLUTION.md` - Full explanation

## Final Checklist

- [ ] Database migration applied (fcm_token columns added)
- [ ] FCM tokens saving to profiles table
- [ ] Backend notification sender implemented (Edge Function)
- [ ] Test notification received (curl or Firebase Console)
- [ ] Test notification tap opens correct chat
- [ ] Messages decrypt after opening chat
- [ ] In-app notifications show decrypted content
- [ ] Push notifications show generic text

## Remember

**DO NOT change your encryption!** It's perfect. The "issue" is actually the correct behavior for E2EE. Generic push notifications are:
- ✅ Industry standard (WhatsApp, Signal, Telegram Secret Chats)
- ✅ Privacy-preserving (backend can't read messages)
- ✅ Secure (keys never leave device)
- ✅ What users expect from E2EE apps

---

**Need help? Read the full guides in the documentation files! 📚**
