# 🤖 AI Features Setup Guide

This guide explains how to set up the AI-powered features (OCR and Translation) for the PediaLink prescription system.

## 📋 Overview

The system includes two AI-powered features:
1. **OCR Scanner** - Extract prescription data from images
2. **Translation** - Translate prescriptions to multiple languages (French, Arabic, English)

## 🔑 API Keys Setup

### Option 1: Google Cloud APIs (Recommended)

#### Google Vision API (for OCR)

1. **Create a Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one

2. **Enable Cloud Vision API**
   - Navigate to "APIs & Services" > "Library"
   - Search for "Cloud Vision API"
   - Click "Enable"

3. **Create API Credentials**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy the generated API key

4. **Set the API Key**
   - Option A: Environment variable
     ```bash
     export GOOGLE_VISION_API_KEY=your_api_key_here
     ```
   - Option B: Update `application.yml`
     ```yaml
     google:
       vision:
         api:
           key: your_api_key_here
     ```

#### Google Translate API (for Translation)

1. **Enable Cloud Translation API**
   - In the same Google Cloud project
   - Navigate to "APIs & Services" > "Library"
   - Search for "Cloud Translation API"
   - Click "Enable"

2. **Use the same API Key or create a new one**
   - Go to "APIs & Services" > "Credentials"
   - Use existing key or create new one

3. **Set the API Key**
   - Option A: Environment variable
     ```bash
     export GOOGLE_TRANSLATE_API_KEY=your_api_key_here
     ```
   - Option B: Update `application.yml`
     ```yaml
     google:
       translate:
         api:
           key: your_api_key_here
     ```

### Option 2: DeepL API (Alternative for Translation)

DeepL provides more accurate translations than Google Translate.

1. **Sign up for DeepL API**
   - Go to [DeepL API](https://www.deepl.com/pro-api)
   - Sign up for a free or paid plan
   - Free plan includes 500,000 characters/month

2. **Get your Authentication Key**
   - After signup, go to your account settings
   - Copy your authentication key

3. **Set the API Key**
   - Option A: Environment variable
     ```bash
     export DEEPL_API_KEY=your_api_key_here
     ```
   - Option B: Update `application.yml`
     ```yaml
     deepl:
       api:
         key: your_api_key_here
     ```

## 🚀 Usage

### OCR Scanner

1. **Access the Scanner**
   - Login as a doctor
   - Navigate to Prescriptions
   - Click "Scan Prescription" button

2. **Upload Image**
   - Click the upload area or drag & drop
   - Supported formats: JPG, PNG (max 5MB)

3. **Extract Data**
   - Click "Extract Prescription"
   - Review extracted information
   - Click "Use This Data" to create prescription

### Translation

1. **Translate Prescription**
   - In the prescriptions list
   - Click "Translate" button on any prescription
   - Select target language (English or Arabic)

2. **View Translation**
   - Translated prescription will be displayed
   - Can be printed or shared with parents

## 💰 Pricing

### Google Cloud APIs

**Cloud Vision API:**
- First 1,000 units/month: FREE
- 1,001 - 5,000,000 units: $1.50 per 1,000 units
- [Full pricing](https://cloud.google.com/vision/pricing)

**Cloud Translation API:**
- First 500,000 characters/month: FREE
- After that: $20 per 1 million characters
- [Full pricing](https://cloud.google.com/translate/pricing)

### DeepL API

**Free Plan:**
- 500,000 characters/month: FREE
- No credit card required

**Pro Plan:**
- Starting at €5.49/month
- 1 million characters included
- [Full pricing](https://www.deepl.com/pro-api)

## 🔒 Security Best Practices

1. **Never commit API keys to Git**
   - Use environment variables
   - Add `.env` to `.gitignore`

2. **Restrict API Keys**
   - In Google Cloud Console, restrict keys to specific APIs
   - Set IP restrictions if possible

3. **Monitor Usage**
   - Set up billing alerts
   - Monitor API usage regularly

4. **Rotate Keys Regularly**
   - Change API keys every 90 days
   - Revoke old keys after rotation

## 🧪 Testing Without API Keys

The system includes simulated responses for testing:

1. **OCR Service**
   - Returns sample extracted prescription data
   - No actual API call is made

2. **Translation Service**
   - Returns basic word-by-word translation
   - Uses predefined dictionary

To enable real API calls, simply add your API keys to the configuration.

## 📝 Implementation Details

### Backend Services

- `OcrService.java` - Handles image processing and text extraction
- `TranslationService.java` - Handles text translation
- `AiController.java` - REST API endpoints

### Frontend Components

- `ocr-scanner.component` - Image upload and extraction UI
- `ai.service.ts` - API client for AI features

### API Endpoints

```
POST /api/prescriptions/ai/ocr/extract
POST /api/prescriptions/ai/translate
POST /api/prescriptions/ai/translate/multiple
GET  /api/prescriptions/ai/translate/languages
POST /api/prescriptions/ai/translate/prescription
```

## 🐛 Troubleshooting

### OCR Not Working

1. Check API key is set correctly
2. Verify Cloud Vision API is enabled
3. Check image format (JPG/PNG only)
4. Ensure image size < 5MB

### Translation Not Working

1. Check API key is set correctly
2. Verify Cloud Translation API is enabled
3. Check supported languages (fr, en, ar)

### API Quota Exceeded

1. Check usage in Google Cloud Console
2. Upgrade to paid plan if needed
3. Implement caching to reduce API calls

## 📞 Support

For issues or questions:
- Check logs: `backend/prescription-service/logs/`
- Review API documentation
- Contact development team

## 🔄 Future Enhancements

Planned features:
- Batch OCR processing
- More languages support
- Offline translation cache
- AI-powered dosage recommendations
- Drug interaction detection
