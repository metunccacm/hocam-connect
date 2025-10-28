# HC-50 Testing Guide

## How to Test Network Error Handling

### Prerequisites
- Flutter app installed on device/emulator
- Access to WiFi/Mobile Data settings

### Test Scenarios

---

## ✅ Scenario 1: Cafeteria Menu - No Internet at Load

**Steps:**
1. Turn OFF WiFi and Mobile Data
2. Open Hocam Connect app
3. Navigate to **Cafeteria Menu**
4. Observe the screen

**Expected Result:**
```
┌─────────────────────────────────┐
│        [WiFi Off Icon]          │
│                                 │
│    ┌─────────────────────┐     │
│    │ Error Code: HC-50   │     │
│    └─────────────────────┘     │
│                                 │
│  Network Connection Error       │
│                                 │
│  Unable to load cafeteria menu  │
│                                 │
│    ┌──────────────┐             │
│    │  Try Again   │             │
│    └──────────────┘             │
└─────────────────────────────────┘
```

**Verify:**
- ✅ HC-50 error code is displayed
- ✅ Network icon (wifi_off) is shown
- ✅ Message says "Unable to load cafeteria menu"
- ✅ "Try Again" button is visible
- ✅ App does NOT crash

**Recovery Test:**
5. Turn ON WiFi or Mobile Data
6. Tap **"Try Again"** button
7. Verify menu loads successfully

---

## ✅ Scenario 2: GPA Calculator - Internet Loss During Use

**Steps:**
1. Make sure internet is ON
2. Navigate to **GPA Calculator**
3. Wait for data to load
4. Turn OFF WiFi and Mobile Data
5. Try to save changes or refresh

**Expected Result:**
- HC-50 error appears when trying to save
- User can still view loaded data
- App doesn't crash

**Verify:**
- ✅ Error message appears with HC-50 code
- ✅ Previously loaded data remains visible
- ✅ User can retry after connection restored

---

## ✅ Scenario 3: Marketplace - No Connection

**Steps:**
1. Turn OFF internet
2. Navigate to **Marketplace**

**Expected Result:**
```
┌─────────────────────────────────┐
│        [WiFi Off Icon]          │
│                                 │
│    ┌─────────────────────┐     │
│    │ Error Code: HC-50   │     │
│    └─────────────────────┘     │
│                                 │
│  Network Connection Error       │
│                                 │
│  Unable to load marketplace     │
│  products                       │
│                                 │
│    ┌──────────────┐             │
│    │  Try Again   │             │
│    └──────────────┘             │
└─────────────────────────────────┘
```

**Verify:**
- ✅ HC-50 error displayed
- ✅ Retry button works when connection restored

---

## ✅ Scenario 4: Hitchhike - Create Post Without Internet

**Steps:**
1. Turn OFF internet
2. Navigate to **Hitchhike**
3. Try to create a new ride post
4. Fill out the form
5. Submit

**Expected Result:**
- HC-50 error appears when submitting
- Form data is not lost
- User can retry after connection

**Verify:**
- ✅ Error shows HC-50 code
- ✅ Network error message displayed
- ✅ App doesn't crash
- ✅ Can retry successfully after reconnection

---

## ✅ Scenario 5: Splash Screen - No Internet on App Boot

**Steps:**
1. Force close the app completely
2. Turn OFF WiFi and Mobile Data
3. Open Hocam Connect app

**Expected Result:**
```
┌─────────────────────────────────┐
│         [App Logo]              │
│                                 │
│   Checking your connection…     │
│                                 │
│  Polishing the antenna…         │
│  (rotating funny messages)      │
│                                 │
│    [Loading Spinner]            │
└─────────────────────────────────┘
```

Then after check:
```
┌─────────────────────────────────┐
│         [WiFi Off Icon]         │
│                                 │
│   No Internet Connection        │
│                                 │
│  Please check your Wi-Fi or     │
│  mobile data and try again.     │
│                                 │
│    ┌──────────────┐             │
│    │  Try Again   │             │
│    └──────────────┘             │
└─────────────────────────────────┘
```

**Verify:**
- ✅ Splash screen shows checking message
- ✅ Funny messages rotate every 2 seconds
- ✅ No internet screen appears after check
- ✅ App stays on no internet screen (doesn't proceed)

**Recovery:**
6. Turn ON internet
7. Tap "Try Again"
8. App proceeds to login/home screen

---

## ✅ Scenario 6: Connection Lost Banner During Use

**Steps:**
1. Open app with internet ON
2. Navigate to any feature (Marketplace, Menu, etc.)
3. Wait for data to load
4. Turn OFF internet while viewing

**Expected Result:**
```
┌─────────────────────────────────┐
│ ┌─────────────────────────────┐ │
│ │ [!] No internet connection  │ │
│ │                    [Retry]  │ │
│ └─────────────────────────────┘ │
│                                 │
│  (Existing content visible)     │
│                                 │
└─────────────────────────────────┘
```

**Verify:**
- ✅ Orange banner appears at top
- ✅ Banner says "No internet connection"
- ✅ Banner has "Retry" button
- ✅ Existing content remains visible (NOT blocked)
- ✅ User can still interact with loaded data

**Recovery:**
5. Turn ON internet
6. Tap "Retry" on banner OR wait for auto-detection
7. Banner disappears
8. App functions normally

---

## Test Checklist

### Features to Test:
- [ ] Cafeteria Menu
- [ ] GPA Calculator
- [ ] Marketplace
- [ ] Hitchhike (view & create)
- [ ] Social Media
- [ ] Splash Screen
- [ ] Connection Lost Banner

### Error Scenarios:
- [ ] No internet on app boot
- [ ] No internet when loading feature
- [ ] Lost internet during use
- [ ] Retry after connection restored
- [ ] Multiple retry attempts
- [ ] Weak/slow connection

### Verification Points:
For each scenario verify:
- [ ] "Error Code: HC-50" is displayed
- [ ] Error message is user-friendly
- [ ] "Try Again"/"Retry" button appears
- [ ] App does NOT crash
- [ ] Previously loaded data remains visible (if applicable)
- [ ] Retry works after connection restored
- [ ] No generic error messages (like "SocketException")

---

## Common Issues to Look For

### ❌ BAD - Generic Error
```
Error: SocketException: Failed host lookup
```

### ✅ GOOD - HC-50 Error
```
┌─────────────────────┐
│ Error Code: HC-50   │
└─────────────────────┘
Network Connection Error
Unable to reach server
```

---

## Testing Different Connection States

### 1. Airplane Mode
- Turn on Airplane Mode
- Test all features
- Should show HC-50 immediately

### 2. WiFi Disabled
- Turn off WiFi only
- Should fall back to mobile data OR show HC-50

### 3. Mobile Data Disabled
- Turn off mobile data only
- Should fall back to WiFi OR show HC-50

### 4. Weak Signal
- Move to area with weak signal
- Should show HC-50 or timeout gracefully

### 5. Slow Connection
- Use network throttling if available
- Should eventually timeout and show HC-50

---

## Success Criteria

✅ All features show HC-50 error code when offline
✅ No crashes occur due to network issues
✅ Retry buttons work correctly
✅ Connection restoration is detected
✅ User can continue using app with loaded data
✅ Splash screen blocks until connection (first boot only)
✅ Banner appears for connection loss during use
✅ Error messages are clear and helpful
✅ No technical jargon in user-facing errors

---

## Reporting Bugs

If HC-50 error handling is NOT working:

1. Note the feature name
2. Note the exact steps to reproduce
3. Screenshot the error (if not HC-50)
4. Note device/OS version
5. Report with tag: `HC-50-BUG`

Example Bug Report:
```
Feature: Social Media
Issue: Shows generic error instead of HC-50
Steps:
1. Turn off internet
2. Navigate to Social feed
3. Try to load posts
Expected: HC-50 error
Actual: "Exception: No internet"
Device: Android 12
```
