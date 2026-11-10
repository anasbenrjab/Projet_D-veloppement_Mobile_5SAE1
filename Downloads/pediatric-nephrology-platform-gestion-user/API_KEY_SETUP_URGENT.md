# ⚠️ URGENT: API Key Security Action Required

## 🚨 Your API Key Was Exposed Publicly!

The key `AIzaSyDcgWtfgr4F2ZLSUAiKtyEaeJ9CDbvmxfs` was shared in a chat and must be revoked **immediately**.

## ✅ Quick Fix (5 minutes)

### Step 1: Revoke the Old Key (2 min)

1. Open: https://console.cloud.google.com/apis/credentials
2. Find key ending in `...vmxfs`
3. Click ⋮ (three dots) → **Delete**
4. Confirm

### Step 2: Create New Restricted Key (2 min)

1. Click **+ CREATE CREDENTIALS** → **API key**
2. Copy the new key (save it somewhere safe temporarily)
3. Click **RESTRICT KEY**
4. Set **API restrictions**:
   - Select: **Restrict key**
   - Check: ✅ Cloud Vision API
   - Check: ✅ Cloud Translation API (if you want translation too)
5. Set **Application restrictions** (choose one):
   - **HTTP referrers**: Add `http://localhost:4200/*`
   - **IP addresses**: Add your server IP
6. Click **SAVE**

### Step 3: Update Your Configuration (1 min)

**Option A: Environment Variable (Recommended)**

```bash
# In your terminal (before starting the backend):
export GOOGLE_VISION_API_KEY="your_new_key_here"
```

**Option B: Update application.yml**

Edit `backend/prescription-service/src/main/resources/application.yml`:

```yaml
google:
  vision:
    api:
      key: ${GOOGLE_VISION_API_KEY:your_new_key_here}
```

⚠️ **But remember**: This file might be committed to Git! Use Option A instead.

### Step 4: Restart Your Service

```bash
# Restart prescription-service in IntelliJ
# The new key will be loaded
```

## 🎯 Current Status

✅ Key is configured in application.yml  
✅ Dependencies added to pom.xml  
✅ OCR service is ready  
⚠️ **KEY MUST BE REVOKED AND REPLACED**

## 🔒 For Future: Never Share Keys

**Never share API keys in:**
- Chat messages
- Screenshots
- Emails
- Code repositories
- Public forums

**Always use:**
- Environment variables
- Secret management tools
- Encrypted configuration

## 📚 More Information

- Full security guide: `SECURITY_GUIDE.md`
- Setup instructions: `AI_FEATURES_SETUP.md`
- Troubleshooting: `OCR_TROUBLESHOOTING.md`

## ✅ After Fixing

Once you've created a new key and configured it:

1. Test the OCR scanner
2. Upload a prescription image
3. Verify it extracts text correctly
4. Check Google Cloud Console for API calls

## 💰 Cost Monitoring

Set up billing alerts:
1. Go to: https://console.cloud.google.com/billing
2. Create budget: $10/month
3. Set alerts at 50%, 90%, 100%

## 🆘 Need Help?

If you have issues:
1. Check logs in IntelliJ console
2. Verify key is active in Google Cloud Console
3. Ensure Cloud Vision API is enabled
4. Check `OCR_TROUBLESHOOTING.md`

---

**Remember: Security first! Revoke the exposed key NOW, then create a new one.**
