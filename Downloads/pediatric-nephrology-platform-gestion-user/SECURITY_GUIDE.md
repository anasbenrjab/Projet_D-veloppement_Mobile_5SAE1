# 🔒 Security Guide - API Keys Management

## ⚠️ CRITICAL: Your API Key Was Exposed!

**The API key `AIzaSyDcgWtfgr4F2ZLSUAiKtyEaeJ9CDbvmxfs` was shared publicly and MUST be revoked immediately!**

## 🚨 Immediate Actions Required

### 1. Revoke the Exposed Key

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Find the key: `AIzaSyDcgWtfgr4F2ZLSUAiKtyEaeJ9CDbvmxfs`
3. Click the three dots menu → **Delete**
4. Confirm deletion

### 2. Create a New Secure Key

1. In Google Cloud Console, click **Create Credentials** → **API Key**
2. **Immediately restrict the key:**
   - Click **Edit API key**
   - Under **API restrictions**, select **Restrict key**
   - Check only:
     - ✅ Cloud Vision API
     - ✅ Cloud Translation API
   - Under **Application restrictions**, choose one:
     - **HTTP referrers** (for web): Add `http://localhost:4200/*` and your production domain
     - **IP addresses** (for server): Add your server IPs
3. Click **Save**
4. Copy the new key

### 3. Configure the New Key Securely

**Option A: Environment Variable (Recommended)**

```bash
# Linux/Mac
export GOOGLE_VISION_API_KEY="your_new_key_here"
export GOOGLE_TRANSLATE_API_KEY="your_new_key_here"

# Windows PowerShell
$env:GOOGLE_VISION_API_KEY="your_new_key_here"
$env:GOOGLE_TRANSLATE_API_KEY="your_new_key_here"

# Windows CMD
set GOOGLE_VISION_API_KEY=your_new_key_here
set GOOGLE_TRANSLATE_API_KEY=your_new_key_here
```

**Option B: .env File (For Development)**

1. Create a `.env` file in the project root:
```bash
cp .env.example .env
```

2. Edit `.env` and add your keys:
```
GOOGLE_VISION_API_KEY=your_new_key_here
GOOGLE_TRANSLATE_API_KEY=your_new_key_here
```

3. **NEVER commit .env to Git!** (Already in .gitignore)

## 🛡️ Security Best Practices

### 1. Never Commit API Keys

**Bad ❌:**
```yaml
google:
  vision:
    api:
      key: AIzaSyDcgWtfgr4F2ZLSUAiKtyEaeJ9CDbvmxfs  # NEVER DO THIS!
```

**Good ✅:**
```yaml
google:
  vision:
    api:
      key: ${GOOGLE_VISION_API_KEY}  # Use environment variable
```

### 2. Use .gitignore

Ensure these files are in `.gitignore`:
```
.env
.env.local
.env.*.local
application-local.yml
**/application-local.yml
```

### 3. Restrict API Keys

Always add restrictions to your API keys:

**API Restrictions:**
- ✅ Restrict to specific APIs only
- ❌ Don't use "Don't restrict key"

**Application Restrictions:**
- For web apps: Use HTTP referrers
- For backend: Use IP addresses
- For mobile: Use Android/iOS app restrictions

### 4. Monitor Usage

1. Go to [Google Cloud Console - APIs Dashboard](https://console.cloud.google.com/apis/dashboard)
2. Check for unusual activity
3. Set up billing alerts
4. Review usage regularly

### 5. Rotate Keys Regularly

- Rotate API keys every 90 days
- Keep old keys active for 24h during rotation
- Update all services before deleting old keys

## 📊 Cost Management

### Set Up Billing Alerts

1. Go to [Billing](https://console.cloud.google.com/billing)
2. Click **Budgets & alerts**
3. Create budget:
   - Name: "API Usage Alert"
   - Amount: $10/month (or your limit)
   - Alert at: 50%, 90%, 100%

### Monitor Costs

**Cloud Vision API:**
- First 1,000 units/month: FREE
- After: $1.50 per 1,000 units

**Cloud Translation API:**
- First 500,000 characters/month: FREE
- After: $20 per 1 million characters

## 🔍 Check for Exposed Keys

### Scan Your Repository

```bash
# Check if keys are in Git history
git log -p | grep -i "AIza"

# Check current files
grep -r "AIza" . --exclude-dir=node_modules --exclude-dir=.git
```

### If You Find Exposed Keys

1. **Revoke them immediately**
2. **Remove from Git history:**
```bash
# Use BFG Repo-Cleaner or git-filter-branch
# This is complex - consider creating a new repo if needed
```

3. **Force push** (if repository is private and you're the only user)

## 🚀 Production Deployment

### Use Secret Management

**For Cloud Deployment:**
- AWS: Use AWS Secrets Manager
- Azure: Use Azure Key Vault
- GCP: Use Secret Manager
- Kubernetes: Use Secrets

**Example with Kubernetes:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
type: Opaque
data:
  google-vision-key: <base64-encoded-key>
  google-translate-key: <base64-encoded-key>
```

### Environment-Specific Configuration

```yaml
# application-prod.yml
google:
  vision:
    api:
      key: ${GOOGLE_VISION_API_KEY}  # From secret manager

# application-dev.yml
google:
  vision:
    api:
      key: ${GOOGLE_VISION_API_KEY:dev_key_here}  # From .env
```

## ✅ Security Checklist

Before deploying:

- [ ] All API keys are in environment variables
- [ ] No keys in application.yml (except as ${VAR} references)
- [ ] .env is in .gitignore
- [ ] API keys have restrictions enabled
- [ ] Billing alerts are configured
- [ ] Keys are rotated regularly (90 days)
- [ ] Git history doesn't contain keys
- [ ] Production uses secret management service
- [ ] Team members know not to commit keys
- [ ] CI/CD uses encrypted secrets

## 📞 If Keys Are Compromised

1. **Revoke immediately** in Google Cloud Console
2. **Check billing** for unauthorized usage
3. **Create new keys** with restrictions
4. **Update all services** with new keys
5. **Monitor** for 24-48 hours
6. **Report** if you see fraudulent charges

## 🔗 Useful Links

- [Google Cloud Console](https://console.cloud.google.com/)
- [API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [Securing API Keys](https://cloud.google.com/docs/authentication/api-keys#securing_an_api_key)
- [Billing Alerts](https://cloud.google.com/billing/docs/how-to/budgets)

## 📝 Remember

> **"The best time to secure your API keys was before creating them. The second best time is NOW!"**

Never share API keys in:
- ❌ Chat messages
- ❌ Emails
- ❌ Screenshots
- ❌ Code repositories
- ❌ Documentation
- ❌ Support tickets

Always use:
- ✅ Environment variables
- ✅ Secret management services
- ✅ Encrypted configuration
- ✅ Access controls
